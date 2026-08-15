#!/usr/bin/env python3
"""Static checks for the ROOZI Android module.

Runs without the Android SDK so the project can be validated in any
environment: XML well-formedness, fa/en string parity, R.* reference
resolution, hardcoded-Persian-string detection and manifest sanity.
"""
import os
import re
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "roozi", "app", "src", "main")
RES = os.path.join(ROOT, "res")
JAVA = os.path.join(ROOT, "java")

errors = []
warnings = []


def xml_files():
    for base, _, files in os.walk(RES):
        for f in files:
            if f.endswith(".xml"):
                yield os.path.join(base, f)
    yield os.path.join(ROOT, "AndroidManifest.xml")


def check_xml_wellformed():
    for path in xml_files():
        try:
            ET.parse(path)
        except ET.ParseError as e:
            errors.append(f"XML parse error in {os.path.relpath(path, ROOT)}: {e}")


def load_values(folder):
    strings, arrays = {}, {}
    d = os.path.join(RES, folder)
    if not os.path.isdir(d):
        return strings, arrays
    for f in sorted(os.listdir(d)):
        if not f.endswith(".xml"):
            continue
        root = ET.parse(os.path.join(d, f)).getroot()
        for node in root:
            name = node.get("name")
            if node.tag == "string":
                strings[name] = "".join(node.itertext())
            elif node.tag == "string-array":
                arrays[name] = [("".join(i.itertext())) for i in node]
    return strings, arrays


def check_locale_parity():
    fa_s, fa_a = load_values("values")
    en_s, en_a = load_values("values-en")

    missing_en = sorted(set(fa_s) - set(en_s))
    missing_fa = sorted(set(en_s) - set(fa_s))
    if missing_en:
        errors.append(f"strings missing in values-en: {missing_en}")
    if missing_fa:
        errors.append(f"strings missing in values (fa): {missing_fa}")

    # format specifiers must match between locales
    spec = re.compile(r"%\d+\$[sd]")
    for key in sorted(set(fa_s) & set(en_s)):
        if sorted(spec.findall(fa_s[key])) != sorted(spec.findall(en_s[key])):
            errors.append(f"format specifier mismatch for '{key}': {fa_s[key]!r} vs {en_s[key]!r}")

    for key in sorted(set(fa_a) & set(en_a)):
        if len(fa_a[key]) != len(en_a[key]):
            errors.append(f"array length mismatch for '{key}'")

    for key in ("jalali_months", "gregorian_months"):
        if len(fa_a.get(key, [])) != 12:
            errors.append(f"{key} must have 12 items")
    for key in ("jalali_weekdays", "jalali_weekdays_short", "gregorian_weekdays_short"):
        if len(fa_a.get(key, [])) != 7:
            errors.append(f"{key} must have 7 items")

    return fa_s, fa_a


def kotlin_files():
    for base, _, files in os.walk(JAVA):
        for f in files:
            if f.endswith(".kt"):
                yield os.path.join(base, f)


def check_r_references(strings, arrays):
    drawables = set()
    for base, _, files in os.walk(RES):
        folder = os.path.basename(base)
        if folder.startswith("drawable") or folder.startswith("mipmap"):
            for f in files:
                drawables.add(os.path.splitext(f)[0])
    fonts = {os.path.splitext(f)[0] for f in os.listdir(os.path.join(RES, "font"))}

    known = {
        "string": set(strings),
        "array": set(arrays),
        "drawable": drawables,
        "mipmap": drawables,
        "font": fonts,
    }
    pattern = re.compile(r"\bR\.(string|array|drawable|mipmap|font)\.([A-Za-z0-9_]+)")
    for path in kotlin_files():
        text = open(path, encoding="utf-8").read()
        for kind, name in pattern.findall(text):
            if name not in known[kind]:
                errors.append(f"unresolved R.{kind}.{name} in {os.path.relpath(path, JAVA)}")

    # manifest + theme references
    manifest = open(os.path.join(ROOT, "AndroidManifest.xml"), encoding="utf-8").read()
    for kind, name in pattern.findall(manifest):
        pass
    for ref in re.findall(r'"@(drawable|mipmap|string|xml|style|color)/([A-Za-z0-9_.]+)"', manifest):
        kind, name = ref
        if kind in ("drawable", "mipmap") and name not in drawables:
            errors.append(f"manifest references missing @{kind}/{name}")
        if kind == "string" and name not in strings:
            errors.append(f"manifest references missing @string/{name}")
        if kind == "xml" and not os.path.exists(os.path.join(RES, "xml", name + ".xml")):
            errors.append(f"manifest references missing @xml/{name}")


def check_no_hardcoded_persian():
    """No Persian text may be hardcoded in Kotlin UI code."""
    persian = re.compile(r"[\u0600-\u06FF]")
    allowed = {
        os.path.join("com", "roozi", "app", "data", "repo", "DefaultCategories.kt"),  # seed fallback names
        os.path.join("com", "roozi", "app", "core", "util", "PersianNumbers.kt"),  # digit tables
    }
    for path in kotlin_files():
        rel = os.path.relpath(path, JAVA)
        if rel in allowed:
            continue
        for i, line in enumerate(open(path, encoding="utf-8"), 1):
            stripped = line.strip()
            if stripped.startswith(("//", "*", "/*")):
                continue
            # strip trailing line comments before scanning
            code = stripped.split("//", 1)[0]
            if not persian.search(code):
                continue
            if persian.search(line):
                errors.append(f"hardcoded Persian text in {rel}:{i}: {stripped[:60]}")


def check_manifest():
    manifest = open(os.path.join(ROOT, "AndroidManifest.xml"), encoding="utf-8").read()
    if "android.permission.INTERNET" in manifest:
        errors.append("app must stay offline: INTERNET permission present")
    if 'android:supportsRtl="true"' not in manifest:
        errors.append("supportsRtl must be enabled")
    for required in (".MainActivity", ".RooziApp", ".notifications.ReminderReceiver", ".notifications.BootReceiver"):
        if required not in manifest:
            errors.append(f"manifest missing component {required}")


def check_fonts():
    d = os.path.join(RES, "font")
    for weight in ("regular", "medium", "semibold", "bold"):
        f = os.path.join(d, f"vazirmatn_{weight}.ttf")
        if not os.path.exists(f):
            errors.append(f"missing font vazirmatn_{weight}.ttf")
        elif os.path.getsize(f) < 10_000:
            errors.append(f"font vazirmatn_{weight}.ttf looks truncated")
        else:
            with open(f, "rb") as fh:
                if fh.read(4) not in (b"\x00\x01\x00\x00", b"true", b"ttcf", b"OTTO"):
                    errors.append(f"font vazirmatn_{weight}.ttf is not a valid TTF")


def check_launcher_icons():
    for dens in ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"):
        for name in ("ic_launcher", "ic_launcher_round"):
            p = os.path.join(RES, f"mipmap-{dens}", f"{name}.png")
            if not os.path.exists(p):
                errors.append(f"missing launcher icon {dens}/{name}.png")
            else:
                with open(p, "rb") as fh:
                    if fh.read(8) != b"\x89PNG\r\n\x1a\n":
                        errors.append(f"invalid PNG {dens}/{name}.png")


def main():
    check_xml_wellformed()
    strings, arrays = check_locale_parity()
    check_r_references(strings, arrays)
    check_no_hardcoded_persian()
    check_manifest()
    check_fonts()
    check_launcher_icons()

    for w in warnings:
        print("WARN:", w)
    for e in errors:
        print("ERROR:", e)
    print(f"\n{len(strings)} strings, {len(arrays)} arrays checked.")
    print("RESULT:", "FAILED" if errors else "PASSED")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
