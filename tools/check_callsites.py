#!/usr/bin/env python3
"""Cross-file call-site checker for the ROOZI Kotlin sources.

The Android SDK is unavailable in this environment, so `kotlinc` reports every
androidx symbol as unresolved and real integration errors drown in the noise.
This script type-checks the part that actually matters: calls between *our own*
declarations.

For each top-level fun declared in the project it collects the parameter names
and which ones have defaults, then verifies every named-argument call site:
  * passes no unknown parameter names
  * supplies every parameter that has no default
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "roozi", "app", "src")

FUN_RE = re.compile(r"^(?:@\w+(?:\([^)]*\))?\s*)*(?:private |internal |public )?fun\s+(?:<[^>]+>\s*)?(\w+)\s*\(", re.M)


COMMENT_RE = re.compile(r"/\*.*?\*/", re.S)


def strip_comments(text: str) -> str:
    """Remove block comments (KDoc can legally sit inside a parameter list)."""
    return COMMENT_RE.sub(" ", text)


def kt_files():
    for base, _, files in os.walk(ROOT):
        for f in files:
            if f.endswith(".kt"):
                yield os.path.join(base, f)


def split_params(sig: str):
    """Split a parameter list on top-level commas.

    Lambda arrows (`->`) must not be mistaken for a closing generic bracket,
    so they are masked out before the depth scan.
    """
    sig = sig.replace("->", "\x00\x00")
    depth = 0
    cur = ""
    out = []
    for ch in sig:
        if ch in "(<[":
            depth += 1
        elif ch in ")>]":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur.replace("\x00\x00", "->"))
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur.replace("\x00\x00", "->"))
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
                pm = re.match(r"(?:@\w+\s*)*(?:vararg\s+)?(\w+)\s*:", p)
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
