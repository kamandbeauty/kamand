#!/usr/bin/env python3
"""Cross-file call-site checker for the DIARY Kotlin sources.

The Android SDK is unavailable in this environment, so `kotlinc` reports every
androidx symbol as unresolved and real integration errors drown in the noise.
This script type-checks the part that actually matters: calls between *our own*
declarations.

For each top-level fun declared in the project it collects the parameter names
and which ones have defaults, then verifies every named-argument call site:
  * passes no unknown parameter names
  * supplies every parameter that has no default

The module directory is selectable with --module; it defaults to the
repository root, where this app lives.
"""
import argparse
import os
import re
import sys

REPO = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def module_root(module: str) -> str:
    return os.path.join(REPO, module, "app", "src")


ROOT = module_root(".")

FUN_RE = re.compile(r"^(?:@\w+(?:\([^)]*\))?\s*)*(?:private |internal |public )?fun\s+(?:<[^>]+>\s*)?(\w+)\s*\(", re.M)


COMMENT_RE = re.compile(r"/\*.*?\*/", re.S)
LINE_COMMENT_RE = re.compile(r"//[^\n]*")


def strip_comments(text: str) -> str:
    """Remove comments.

    Both block KDoc and line comments can legally sit inside a parameter list,
    and a comma inside one would otherwise be mistaken for a parameter break.
    """
    return LINE_COMMENT_RE.sub("", COMMENT_RE.sub(" ", text))


def kt_files():
    for base, _, files in os.walk(ROOT):
        for f in files:
            if f.endswith(".kt"):
                yield os.path.join(base, f)


def split_params(sig: str):
    """Split a parameter list on top-level commas.

    Angle brackets are ambiguous in Kotlin: `Map<Long, X>` is a generic, but
    `a > 0` is a comparison. Counting every `>` as a closing bracket drove the
    depth negative and split a trailing-lambda argument in the middle, so `<`
    only opens a generic when it directly follows an identifier, and `>` only
    closes one while such a generic is open.

    Braces are counted too: an argument may be a lambda containing commas.
    Lambda arrows and the comparison operators `->`, `<=`, `>=` are masked out
    first so they can never be read as brackets.
    """
    for token, mask in (("->", "\x00\x00"), ("<=", "\x01\x01"), (">=", "\x02\x02")):
        sig = sig.replace(token, mask)

    def unmask(text):
        for token, mask in (("->", "\x00\x00"), ("<=", "\x01\x01"), (">=", "\x02\x02")):
            text = text.replace(mask, token)
        return text

    depth = 0
    angle = 0
    cur = ""
    out = []
    prev = ""
    for ch in sig:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        elif ch == "<" and (prev.isalnum() or prev in "_?"):
            angle += 1
            depth += 1
        elif ch == ">" and angle > 0:
            angle -= 1
            depth -= 1
        if ch == "," and depth == 0:
            out.append(unmask(cur))
            cur = ""
        else:
            cur += ch
        if not ch.isspace():
            prev = ch
    if cur.strip():
        out.append(unmask(cur))
    return out


def balanced_slice(text, open_idx):
    """Return the substring inside the parens starting at open_idx."""
    depth = 0
    for i in range(open_idx, len(text)):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return text[open_idx + 1:i], i
    return None, None


def collect_declarations():
    decls = {}
    dupes = {}
    for path in kt_files():
        text = strip_comments(open(path, encoding="utf-8").read())
        for m in FUN_RE.finditer(text):
            name = m.group(1)
            open_idx = m.end() - 1  # regex ends exactly at the fun's "("
            body, _ = balanced_slice(text, open_idx)
            if body is None:
                continue
            params = {}
            for p in split_params(body):
                p = p.strip()
                if not p:
                    continue
                # strip any annotations (e.g. @Composable) before the name
                pm = re.match(r"(?:@\w+(?:\([^)]*\))?\s*)*(?:vararg\s+)?(\w+)\s*:", p)
                if pm:
                    params[pm.group(1)] = "=" in p
            if name in decls and decls[name] != params:
                dupes.setdefault(name, []).append(os.path.basename(path))
            decls[name] = params
    return decls, dupes


def check_calls(decls):
    errors = []
    for path in kt_files():
        text = strip_comments(open(path, encoding="utf-8").read())
        rel = os.path.relpath(path, ROOT)
        for name, params in decls.items():
            # find invocations: name( ... ) not preceded by "fun "
            for m in re.finditer(r"(?<![\w.])" + re.escape(name) + r"\s*\(", text):
                if text[:m.start()].rstrip().endswith("fun"):
                    continue
                open_idx = text.index("(", m.start())
                body, close = balanced_slice(text, open_idx)
                if body is None:
                    continue
                args = split_params(body)
                named = []
                positional = 0
                for a in args:
                    a = a.strip()
                    if not a:
                        continue
                    am = re.match(r"^(\w+)\s*=(?!=)", a)
                    if am:
                        named.append(am.group(1))
                    else:
                        positional += 1
                if not named:
                    continue  # purely positional / trailing lambda: skip
                line = text[:m.start()].count("\n") + 1

                unknown = [n for n in named if n not in params]
                if unknown:
                    errors.append(f"{rel}:{line}: {name}() unknown arg(s) {unknown}")

                keys = list(params.keys())
                # positional args fill the first N params in order
                filled = set(keys[:positional])

                # a trailing lambda fills the LAST parameter (Compose `content`)
                after = text[close + 1:close + 40].lstrip()
                if after.startswith("{") and keys:
                    filled.add(keys[-1])

                required = [p for p, has_def in params.items() if not has_def]
                missing = [r for r in required if r not in named and r not in filled]
                if missing:
                    errors.append(f"{rel}:{line}: {name}() missing required {missing}")
    return errors


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--module", default=".", help="app module directory (default: the repository root)")
    args = ap.parse_args()
    global ROOT
    ROOT = module_root(args.module)
    if not os.path.isdir(ROOT):
        print(f"ERROR: no such module: {args.module}")
        return 1

    decls, dupes = collect_declarations()
    errors = check_calls(decls)

    for name, files in dupes.items():
        print(f"NOTE: overloaded/duplicate signature '{name}' in {files}")
    for e in errors:
        print("ERROR:", e)
    print(f"\nChecked {len(decls)} declarations.")
    print("RESULT:", "FAILED" if errors else "PASSED")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
