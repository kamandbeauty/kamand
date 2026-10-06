#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Build script for "طالع من" content pipeline.

Single source of truth: content/signs/*.json + content/compatibility.json
Outputs:
  1. content/app_content.json            — merged content
  2. lib/data/content/app_content.dart   — generated Dart data layer (offline, typed)

Run: python3 tool/build_content.py
"""
import json
import glob
import os
import sys
import unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIGNS_DIR = os.path.join(ROOT, "content", "signs")
COMPAT_FILE = os.path.join(ROOT, "content", "compatibility.json")
OUT_JSON = os.path.join(ROOT, "content", "app_content.json")
OUT_DART = os.path.join(ROOT, "lib", "data", "content", "app_content.dart")

EXPECTED_ORDER = [
    "aries", "taurus", "gemini", "cancer", "leo", "virgo",
    "libra", "scorpio", "sagittarius", "capricorn", "aquarius", "pisces",
]

REQUIRED_FIELDS = [
    "id", "nameFa", "nameEn", "symbol", "startMonth", "startDay",
    "endMonth", "endDay", "element", "elementId", "rulingPlanet",
    "description", "personality", "strengths", "weaknesses",
    "loveStyle", "workStyle", "friendshipStyle",
    "luckyColors", "luckyNumbers", "luckyTimes",
    "daily", "weekly", "monthly",
]
DAILY_KEYS = ["general", "love", "career", "finance", "mood", "warning", "opportunity"]
MONTHLY_KEYS = ["focus", "love", "career", "finance", "energy", "opportunity", "warning"]
ASPECTS = ["conjunction", "sextile", "square", "trine", "opposition", "quincunx", "semisextile"]


def fail(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def check_stray(path, text):
    for ch in text:
        try:
            name = unicodedata.name(ch)
        except ValueError:
            fail(f"{path}: unnameable character {ch!r}")
        if name.split()[0] in ("CJK", "HIRAGANA", "KATAKANA", "HANGUL", "CYRILLIC", "GREEK"):
            idx = text.find(ch)
            fail(f"{path}: stray {name.split()[0]} char {ch!r} near ...{text[max(0, idx-30):idx+30]}...")


def validate_sign(path, data):
    for field in REQUIRED_FIELDS:
        if field not in data:
            fail(f"{path}: missing field '{field}'")
    if data["id"] not in EXPECTED_ORDER:
        fail(f"{path}: unknown id {data['id']}")
    for k in DAILY_KEYS:
        items = data["daily"].get(k, [])
        if not isinstance(items, list) or len(items) < 3:
            fail(f"{path}: daily.{k} must be a list with >= 3 items")
        for it in items:
            if not isinstance(it, str) or len(it) < 12:
                fail(f"{path}: daily.{k} has a too-short item")
    for k in MONTHLY_KEYS:
        items = data["monthly"].get(k, [])
        if not isinstance(items, list) or len(items) < 2:
            fail(f"{path}: monthly.{k} must be a list with >= 2 items")
    ws = data["weekly"].get("summaries", [])
    if len(ws) < 3:
        fail(f"{path}: weekly.summaries must have >= 3 items")
    if len(data["luckyNumbers"]) < 4 or len(data["luckyColors"]) < 4 or len(data["luckyTimes"]) < 4:
        fail(f"{path}: lucky pools must have >= 4 items")
    check_stray(path, json.dumps(data, ensure_ascii=False))


def validate_compatibility(path, data):
    for aspect in ASPECTS:
        entry = data["aspectTexts"].get(aspect)
        if not entry or "title" not in entry or len(entry.get("why", [])) < 2:
            fail(f"{path}: aspectTexts.{aspect} incomplete")
    if len(data.get("elementChemistry", {})) < 10:
        fail(f"{path}: elementChemistry must cover 10 element pairs")
    check_stray(path, json.dumps(data, ensure_ascii=False))


def dart_string(s):
    """Escape a Python/JSON string into a Dart string literal (single quotes)."""
    return "'" + s.replace("\\", "\\\\").replace("'", "\\'").replace("\n", "\\n").replace("\r", "").replace("$", "\\$") + "'"


def dart_list(items, indent="    "):
    if not items:
        return "[]"
    inner = (",\n" + indent + "  ").join(dart_string(i) for i in items)
    return "[\n" + indent + "  " + inner + ",\n" + indent + "]"


def dart_int_list(items, indent="    "):
    return "[" + ", ".join(str(i) for i in items) + "]"


def generate_dart(signs, compat):
    header = """// GENERATED FILE — DO NOT EDIT BY HAND.
// Source: content/signs/*.json + content/compatibility.json
// Regenerate with: python3 tool/build_content.py
//
// Persian content for the "طالع من" horoscope app. This file is the data
// layer (content repository) consumed by the domain engines; UI code never
// hardcodes horoscope text (see lib/domain/horoscope/horoscope_engine.dart).

// ignore_for_file: public_member_api_docs

/// All authored content for the app: 12 zodiac signs + compatibility texts.
class AppContent {
  AppContent._();

  static const List<Map<String, Object?>> zodiacSigns = [
"""
    blocks = []
    for s in signs:
        lines = []
        lines.append(f"      'id': {dart_string(s['id'])},")
        lines.append(f"      'nameFa': {dart_string(s['nameFa'])},")
        lines.append(f"      'nameEn': {dart_string(s['nameEn'])},")
        lines.append(f"      'symbol': {dart_string(s['symbol'])},")
        lines.append(f"      'startMonth': {s['startMonth']},")
        lines.append(f"      'startDay': {s['startDay']},")
        lines.append(f"      'endMonth': {s['endMonth']},")
        lines.append(f"      'endDay': {s['endDay']},")
        lines.append(f"      'element': {dart_string(s['element'])},")
        lines.append(f"      'elementId': {dart_string(s['elementId'])},")
        lines.append(f"      'rulingPlanet': {dart_string(s['rulingPlanet'])},")
        lines.append(f"      'description': {dart_string(s['description'])},")
        lines.append(f"      'personality': {dart_string(s['personality'])},")
        lines.append(f"      'strengths': {dart_list(s['strengths'], indent='        ')},")
        lines.append(f"      'weaknesses': {dart_list(s['weaknesses'], indent='        ')},")
        lines.append(f"      'loveStyle': {dart_string(s['loveStyle'])},")
        lines.append(f"      'workStyle': {dart_string(s['workStyle'])},")
        lines.append(f"      'friendshipStyle': {dart_string(s['friendshipStyle'])},")
        lines.append(f"      'luckyColors': {dart_list(s['luckyColors'], indent='        ')},")
        lines.append(f"      'luckyNumbers': {dart_int_list(s['luckyNumbers'])},")
        lines.append(f"      'luckyTimes': {dart_list(s['luckyTimes'], indent='        ')},")
        daily = s["daily"]
        lines.append("      'daily': {")
        for k in DAILY_KEYS:
            lines.append(f"        '{k}': {dart_list(daily[k], indent='          ')},")
        lines.append("      },")
        lines.append("      'weekly': {")
        lines.append(f"        'summaries': {dart_list(s['weekly']['summaries'], indent='          ')},")
        lines.append("      },")
        monthly = s["monthly"]
        lines.append("      'monthly': {")
        for k in MONTHLY_KEYS:
            lines.append(f"        '{k}': {dart_list(monthly[k], indent='          ')},")
        lines.append("      },")
        blocks.append("    {\n" + "\n".join(lines) + "\n    }")
    body = header + ",\n".join(blocks) + ",\n  ];\n"

    body += "\n  static const Map<String, Object?> compatibility = {\n"
    body += "    'aspectTexts': {\n"
    for aspect in ASPECTS:
        entry = compat["aspectTexts"][aspect]
        body += f"      '{aspect}': {{\n"
        body += f"        'title': {dart_string(entry['title'])},\n"
        body += f"        'why': {dart_list(entry['why'], indent='          ')},\n"
        body += "      },\n"
    body += "    },\n"
    body += "    'elementChemistry': {\n"
    for pair, text in sorted(compat["elementChemistry"].items()):
        body += f"      {dart_string(pair)}: {dart_string(text)},\n"
    body += "    },\n"
    body += "    'labels': {\n"
    for k, v in compat["labels"].items():
        body += f"      {dart_string(k)}: {dart_string(v)},\n"
    body += "    },\n"
    body += "  };\n}\n"
    return body


def main():
    sign_files = sorted(glob.glob(os.path.join(SIGNS_DIR, "*.json")))
    if len(sign_files) != 12:
        fail(f"expected 12 sign files, found {len(sign_files)}")

    signs_by_id = {}
    for path in sign_files:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        validate_sign(path, data)
        if data["id"] in signs_by_id:
            fail(f"duplicate sign id: {data['id']}")
        signs_by_id[data["id"]] = data

    for expected in EXPECTED_ORDER:
        if expected not in signs_by_id:
            fail(f"missing sign file for {expected}")
    signs = [signs_by_id[i] for i in EXPECTED_ORDER]

    with open(COMPAT_FILE, encoding="utf-8") as f:
        compat = json.load(f)
    validate_compatibility(COMPAT_FILE, compat)

    merged = {"zodiacSigns": signs, "compatibility": compat}

    # 1. merged json
    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(merged, f, ensure_ascii=False, indent=2)
        f.write("\n")

    # 2. generated dart
    os.makedirs(os.path.dirname(OUT_DART), exist_ok=True)
    with open(OUT_DART, "w", encoding="utf-8") as f:
        f.write(generate_dart(signs, compat))

    # 3. web copy
        f.write("\n")

    total_texts = 0
    for s in signs:
        total_texts += sum(len(v) for v in s["daily"].values())
        total_texts += sum(len(v) for v in s["monthly"].values())
        total_texts += len(s["weekly"]["summaries"])
    print(f"OK: 12 signs validated · {total_texts} horoscope texts · wrote:")
    print(f"  {os.path.relpath(OUT_JSON, ROOT)}")
    print(f"  {os.path.relpath(OUT_DART, ROOT)}")


if __name__ == "__main__":
    main()
