#!/usr/bin/env python3
"""Fork the ROOZI Android module into a second, independently branded app.

A large part of ROOZI — the Jalali calendar engine, Persian digits, the RTL
theme, the Room setup, reminders, backup, the whole design system — is generic
infrastructure that a second app can reuse verbatim. This script produces that
second app as a *self-contained copy* rather than a shared library module:

  * the two apps can then diverge freely (different screens, different DB
    schema, different release cadence) without one breaking the other;
  * ROOZI itself is never modified — the source tree is only read.

Everything that carries the ROOZI identity is rewritten in one pass:
application id, Kotlin package, `Roozi*` type prefix, theme names, the
database file name, broadcast actions, the Gradle root project name, the CI
workflow (job names, artifact names, working directory, secret prefix) and the
two brand strings in both locales.

Because the fork always starts from `roozi/`, re-branding later is simply a
matter of deleting the generated directory and re-running with new values —
there is no half-renamed intermediate state to clean up.

Usage:
    python3 tools/fork_app.py \
        --dir app2 \
        --package com.javidstudio.app2 \
        --prefix App2 \
        --name-fa "اپ جدید" \
        --name-en "New App" \
        [--force]
"""
from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SOURCE_DIR = REPO / "roozi"

SOURCE_PACKAGE = "com.roozi.app"
SOURCE_PREFIX = "Roozi"          # type / theme prefix: RooziTheme, Theme.Roozi
SOURCE_SLUG = "roozi"            # db file, artifact names, workflow file name
SOURCE_UPPER = "ROOZI"           # docs, English brand strings
SOURCE_NAME_FA = "روزی"          # brand word inside Persian strings
SOURCE_SECRET_PREFIX = "ROZI"    # GitHub secret prefix for the signing key

# Text files are rewritten; anything else is copied byte for byte.
TEXT_SUFFIXES = {
    ".kt", ".kts", ".xml", ".pro", ".md", ".yml", ".yaml",
    ".properties", ".toml", ".html", ".txt", ".json",
}

# Never carried over: build output, local secrets, IDE state.
SKIP_DIR_NAMES = {"build", ".gradle", ".idea", ".kotlin"}
SKIP_FILE_NAMES = {"keystore.properties", "local.properties", "release.keystore"}

# A standalone «روزی»: not part of a longer Persian word such as «روزیه».
PERSIAN_LETTER = r"\u0600-\u06FF\u200c"
BRAND_FA_RE = re.compile(rf"(?<![{PERSIAN_LETTER}])روزی(?![{PERSIAN_LETTER}])")


def rewrite(text: str, ctx: dict) -> str:
    # Longest/most specific first so that e.g. the package is not partially
    # rewritten by the bare-slug rule.
    text = text.replace(SOURCE_PACKAGE, ctx["package"])
    text = text.replace(SOURCE_PREFIX, ctx["prefix"])
    text = text.replace(SOURCE_UPPER, ctx["upper"])
    text = text.replace(SOURCE_SLUG, ctx["slug"])
    # Brand words in the localized strings. app_name / app_name_short are
    # handled separately below because they are full sentences, not tokens.
    text = BRAND_FA_RE.sub(ctx["name_fa_short"], text)
    text = text.replace(SOURCE_SECRET_PREFIX + "_RELEASE_", ctx["secret_prefix"] + "_RELEASE_")
    return text


def rewrite_path(rel: Path, ctx: dict) -> Path:
    parts = []
    for part in rel.parts:
        part = part.replace(SOURCE_PREFIX, ctx["prefix"]).replace(SOURCE_SLUG, ctx["slug"])
        parts.append(part)
    return Path(*parts)


def package_path(pkg: str) -> Path:
    return Path(*pkg.split("."))


def copy_tree(dest: Path, ctx: dict) -> int:
    src_pkg_rel = package_path(SOURCE_PACKAGE)
    dst_pkg_rel = package_path(ctx["package"])
    count = 0

    for path in sorted(SOURCE_DIR.rglob("*")):
        rel = path.relative_to(SOURCE_DIR)
        if any(p in SKIP_DIR_NAMES for p in rel.parts):
            continue
        if path.is_dir():
            continue
        if path.name in SKIP_FILE_NAMES:
            continue

        # Kotlin sources live under java/com/roozi/app/... — move them to the
        # new package directory before the generic name rewrite runs, otherwise
        # "com/roozi/app" would become "com/<prefix>/app" instead.
        rel_parts = list(rel.parts)
        src_pkg_parts = list(src_pkg_rel.parts)
        for i in range(len(rel_parts) - len(src_pkg_parts) + 1):
            if rel_parts[i:i + len(src_pkg_parts)] == src_pkg_parts:
                rel_parts[i:i + len(src_pkg_parts)] = list(dst_pkg_rel.parts)
                break
        rel = rewrite_path(Path(*rel_parts), ctx)

        target = dest / rel
        target.parent.mkdir(parents=True, exist_ok=True)

        if path.suffix.lower() in TEXT_SUFFIXES:
            text = path.read_text(encoding="utf-8")
            target.write_text(rewrite(text, ctx), encoding="utf-8")
        else:
            shutil.copy2(path, target)
        if path.name == "gradlew":
            target.chmod(0o755)
        count += 1
    return count


def set_string(xml_path: Path, name: str, value: str) -> None:
    text = xml_path.read_text(encoding="utf-8")
    pattern = re.compile(rf'(<string name="{name}">).*?(</string>)', re.S)
    if not pattern.search(text):
        raise SystemExit(f"string '{name}' not found in {xml_path}")
    xml_path.write_text(pattern.sub(lambda m: m.group(1) + value + m.group(2), text, count=1),
                        encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dir", required=True, help="new module directory, e.g. app2")
    ap.add_argument("--package", required=True, help="application id / namespace")
    ap.add_argument("--prefix", required=True, help="type prefix replacing 'Roozi'")
    ap.add_argument("--name-fa", required=True, help="Persian launcher name")
    ap.add_argument("--name-en", required=True, help="English/short brand name")
    ap.add_argument("--name-fa-short", default=None,
                    help="short Persian brand word used inside sentences "
                         "(defaults to the first word of --name-fa)")
    ap.add_argument("--secret-prefix", default=SOURCE_SECRET_PREFIX,
                    help="prefix of the four GitHub signing secrets used by the forked "
                         "workflow. Keep the default to sign both apps with the same "
                         "publisher key; change it to give the fork its own keystore.")
    ap.add_argument("--force", action="store_true", help="overwrite an existing directory")
    args = ap.parse_args()

    if not re.fullmatch(r"[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+", args.package):
        raise SystemExit("--package must be a valid lowercase Java package")
    if not re.fullmatch(r"[A-Z][A-Za-z0-9]*", args.prefix):
        raise SystemExit("--prefix must be UpperCamelCase")

    slug = args.dir.strip("/").lower()
    if not re.fullmatch(r"[a-z][a-z0-9_-]*", slug):
        raise SystemExit("--dir must be a simple lowercase directory name")

    dest = REPO / slug
    if dest.exists():
        if not args.force:
            raise SystemExit(f"{dest} already exists; pass --force to replace it")
        shutil.rmtree(dest)

    ctx = {
        "package": args.package,
        "prefix": args.prefix,
        "slug": slug,
        "upper": args.name_en.upper().replace(" ", ""),
        "name_fa_short": (args.name_fa_short or args.name_fa.split()[0]).strip(),
        "secret_prefix": args.secret_prefix.upper(),
    }

    n = copy_tree(dest, ctx)

    # The two brand strings are whole phrases, so they are set explicitly
    # instead of being token-replaced.
    fa = dest / "app/src/main/res/values/strings.xml"
    en = dest / "app/src/main/res/values-en/strings.xml"
    set_string(fa, "app_name", args.name_fa)
    set_string(fa, "app_name_short", ctx["name_fa_short"])
    set_string(en, "app_name", args.name_fa)      # launcher label stays Persian
    set_string(en, "app_name_short", args.name_en)

    # versionCode/versionName restart for the new listing.
    gradle = dest / "app/build.gradle.kts"
    text = gradle.read_text(encoding="utf-8")
    text = re.sub(r"versionCode = \d+", "versionCode = 1", text, count=1)
    text = re.sub(r'versionName = "[^"]*"', 'versionName = "1.0.0"', text, count=1)
    # The -PappName default is a full phrase, so the token pass leaves it half
    # translated; set it to the real launcher name.
    text = re.sub(r'(AppName: String = \(project\.findProperty\("appName"\) as String\?\) \?: )"[^"]*"',
                  lambda m: m.group(1) + '"' + args.name_fa + '"', text, count=1)
    gradle.write_text(text, encoding="utf-8")

    print(f"Forked {n} files into {slug}/")
    print(f"  applicationId : {args.package}")
    print(f"  type prefix   : {args.prefix}")
    print(f"  launcher name : {args.name_fa}")
    print(f"  workflow      : {slug}/ci/{slug}-android.yml "
          f"(copy to .github/workflows/ manually)")
    print(f"Verify with: python3 tools/verify_resources.py --module {slug} "
          f"&& python3 tools/check_callsites.py --module {slug}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
