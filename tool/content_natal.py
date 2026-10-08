#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generates content/natal_interpretations.json + lib/data/content/natal_content.dart
from tool/natal_data.py.

Run: python3 tool/content_natal.py
"""
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from natal_data import (  # noqa: E402
    ASCENDANT_IN_SIGN, ASPECT_TEXTS, CHART_INTRO, CITY_UNKNOWN_NOTE,
    DOMINANT_ELEMENT, HOUSE_TITLES, METHOD_NOTE, NATAL_MOON_IN_SIGN,
    NO_TIME_NOTE, PLANET_IN_SIGN, RETROGRADE_NOTE,
)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SIGNS = [
    'aries', 'taurus', 'gemini', 'cancer', 'leo', 'virgo',
    'libra', 'scorpio', 'sagittarius', 'capricorn', 'aquarius', 'pisces']
ASPECT_ORDER = ['conjunction', 'sextile', 'square', 'trine', 'opposition']


def validate():
    assert sorted(ASCENDANT_IN_SIGN) == sorted(SIGNS)
    assert sorted(NATAL_MOON_IN_SIGN) == sorted(SIGNS)
    assert sorted(PLANET_IN_SIGN) == ['jupiter', 'mars', 'mercury', 'saturn', 'venus']
    for planet, signs in PLANET_IN_SIGN.items():
        assert sorted(signs) == sorted(SIGNS), planet
    assert sorted(ASPECT_TEXTS) == sorted(ASPECT_ORDER)
    assert sorted(DOMINANT_ELEMENT) == ['air', 'earth', 'fire', 'water']
    assert len(HOUSE_TITLES) == 12

    texts = (
        [CHART_INTRO, METHOD_NOTE, NO_TIME_NOTE, CITY_UNKNOWN_NOTE,
         RETROGRADE_NOTE]
        + list(ASCENDANT_IN_SIGN.values())
        + list(NATAL_MOON_IN_SIGN.values())
        + [t for p in PLANET_IN_SIGN.values() for t in p.values()]
        + list(ASPECT_TEXTS.values())
        + list(DOMINANT_ELEMENT.values())
        + HOUSE_TITLES
    )
    for t in texts:
        assert len(t) >= 12, t[:40]
    # contamination scan (JPL is a deliberate institution name)
    for t in texts:
        if re.search(r'[\u0400-\u04FF\u3040-\u30FF\u4E00-\u9FFF\uAC00-\uD7AF]', t):
            raise SystemExit(f"stray script char: {t[:60]}")
        for m in re.finditer(r'[A-Za-z]{3,}', t):
            if m.group(0) not in ('JPL',):
                raise SystemExit(f"stray latin word {m.group(0)!r}: {t[:60]}")
    assert len(set(texts)) == len(texts) - 0  # allow reused short titles only
    print(f"validation: natal structures OK ({len(texts)} texts) ✓")


def dart_string(value):
    out = value.replace('\\', '\\\\').replace("'", "\\'")
    out = out.replace('"', '\\"').replace('$', '\\$')
    out = out.replace('\n', '\\n')
    return f"'{out}'"


def block(d, keys, indent):
    lines = [f"{indent}{{"]
    for k in keys:
        v = d[k]
        if isinstance(v, str):
            lines.append(f"{indent}  '{k}': {dart_string(v)},")
        else:
            lines.append(f"{indent}  '{k}': {v},")
    lines.append(f"{indent}}},")
    return "\n".join(lines)


def generate_dart():
    def map_block(mapping, indent):
        parts = []
        for k, v in mapping.items():
            parts.append(f"{indent}  '{k}': {dart_string(v)},")
        return "{\n" + "\n".join(parts) + f"\n{indent}}}"

    def nested_map(outer, indent):
        parts = []
        for planet, signs in outer.items():
            inner = map_block(signs, indent + '  ')
            parts.append(f"{indent}  '{planet}': {inner},")
        return "{\n" + "\n".join(parts) + f"\n{indent}}}"

    houses = "\n".join(f"      {dart_string(t)}," for t in HOUSE_TITLES)

    return f"""// GENERATED FILE — DO NOT EDIT BY HAND.
// Source: tool/natal_data.py + tool/content_natal.py
// Regenerate with: python3 tool/content_natal.py
//
// Natal-chart interpretation bank (round 16): ascendant, natal Moon,
// planets in signs, aspect templates, dominant elements, house titles.
// All texts are original Persian compositions (entertainment framing).

// ignore_for_file: public_member_api_docs

class NatalContent {{
  NatalContent._();

  static const String chartIntro = {dart_string(CHART_INTRO)};

  /// Ascendant text by sign id.
  static const Map<String, String> ascendantInSign =
{map_block(ASCENDANT_IN_SIGN, '      ')};

  /// Natal Moon text by sign id.
  static const Map<String, String> natalMoonInSign =
{map_block(NATAL_MOON_IN_SIGN, '      ')};

  /// Planet-in-sign texts: planet id → sign id → text.
  static const Map<String, Map<String, String>> planetInSign =
{nested_map(PLANET_IN_SIGN, '      ')};

  /// Aspect templates with {{a}}/{{b}} body placeholders.
  static const Map<String, String> aspectTexts =
{map_block(ASPECT_TEXTS, '      ')};

  /// Dominant-element summaries.
  static const Map<String, String> dominantElement =
{map_block(DOMINANT_ELEMENT, '      ')};

  /// Twelve house titles (index 0 = house 1).
  static const List<String> houseTitles = [
{houses}
  ];

  static const String methodNote = {dart_string(METHOD_NOTE)};

  static const String noTimeNote = {dart_string(NO_TIME_NOTE)};

  /// Shown when the time is known but the city is missing/non-Iranian.
  static const String cityUnknownNote = {dart_string(CITY_UNKNOWN_NOTE)};

  static const String retrogradeNote = {dart_string(RETROGRADE_NOTE)};
}}
"""


def main():
    validate()
    data = {
        "intro": CHART_INTRO,
        "ascendantInSign": ASCENDANT_IN_SIGN,
        "natalMoonInSign": NATAL_MOON_IN_SIGN,
        "planetInSign": PLANET_IN_SIGN,
        "aspectTexts": ASPECT_TEXTS,
        "dominantElement": DOMINANT_ELEMENT,
        "houseTitles": HOUSE_TITLES,
        "methodNote": METHOD_NOTE,
        "noTimeNote": NO_TIME_NOTE,
        "cityUnknownNote": CITY_UNKNOWN_NOTE,
        "retrogradeNote": RETROGRADE_NOTE,
    }
    json_path = os.path.join(ROOT, "content", "natal_interpretations.json")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1, sort_keys=True)
    dart_path = os.path.join(
        ROOT, "lib", "data", "content", "natal_content.dart")
    with open(dart_path, "w", encoding="utf-8") as f:
        f.write(generate_dart())
    print("wrote:")
    print(f"  {os.path.relpath(json_path, ROOT)}")
    print(f"  {os.path.relpath(dart_path, ROOT)}")


if __name__ == "__main__":
    main()
