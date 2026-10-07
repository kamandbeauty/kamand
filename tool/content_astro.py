# -*- coding: utf-8 -*-
"""Generates content/astro_transits.json + lib/data/content/astro_content.dart
from tool/astro_transits_data.py.

Run: python3 tool/content_astro.py
"""
import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from astro_transits_data import (  # noqa: E402
    ASPECTS, MOON_IN_SIGNS, MOON_PHASES, MONTH_SEASONS, SKY_INTRO,
    WEEK_THEMES, WEEKDAY_RULERS,
)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def validate():
    assert len(MOON_IN_SIGNS) == 12
    assert [m['id'] for m in MOON_IN_SIGNS] == [
        'aries', 'taurus', 'gemini', 'cancer', 'leo', 'virgo',
        'libra', 'scorpio', 'sagittarius', 'capricorn', 'aquarius', 'pisces']
    assert len(MOON_PHASES) == 8
    assert len(ASPECTS) == 6
    assert [a['id'] for a in ASPECTS] == [
        'conjunction', 'sextile', 'square', 'trine', 'opposition', 'none']
    assert len(WEEKDAY_RULERS) == 7
    assert sorted(WEEK_THEMES) == ['air', 'earth', 'fire', 'water']
    assert all(len(v) == 3 for v in WEEK_THEMES.values())
    assert [m['month'] for m in MONTH_SEASONS] == list(range(1, 13))
    print("validation: astro structures OK ✓")


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


def map_ssl(pairs, indent):
    """Map<String, List<String>>."""
    parts = []
    for k, values in pairs:
        items = "\n".join(f"{indent}    {dart_string(v)}," for v in values)
        parts.append(f"{indent}  '{k}': [\n{items}\n{indent}  ],")
    return "{\n" + "\n".join(parts) + "\n" + indent + "}"


def generate_dart():
    moons = "\n".join(block(m, ["id", "signFa", "text"], "      ")
                      for m in MOON_IN_SIGNS)
    phases = "\n".join(block(p, ["id", "nameFa", "text"], "      ")
                       for p in MOON_PHASES)
    aspects = "\n".join(
        block(a, ["id", "titleFa", "text", "advice"], "      ")
        for a in ASPECTS)
    rulers = "\n".join(
        block(r, ["id", "dayFa", "rulerFa", "planetFa", "text"], "      ")
        for r in WEEKDAY_RULERS)
    months = "\n".join(
        block(m, ["month", "sunSign", "text"], "      ")
        for m in MONTH_SEASONS)
    themes = map_ssl(list(WEEK_THEMES.items()), "    ")

    return f"""// GENERATED FILE — DO NOT EDIT BY HAND.
// Source: tool/astro_transits_data.py + tool/content_astro.py
// Regenerate with: python3 tool/content_astro.py
//
// Astronomy-driven sky layer for the daily/weekly/monthly horoscopes:
// Moon sign, Moon phase, Moon-to-natal-Sun aspect (Ptolemaic), Chaldean
// weekday ruler, weekly Moon-element themes, monthly seasonal map.
// All texts are original Persian compositions (entertainment framing).

// ignore_for_file: public_member_api_docs

class AstroContent {{
  AstroContent._();

  static const String skyIntro = {dart_string(SKY_INTRO)};

  /// Moon's tropical sign, index 0..11 (aries..pisces).
  static const List<Map<String, Object?>> moonInSigns = [
{moons}
  ];

  /// 8 phase buckets by elongation (0 = new moon … 7 = waning crescent).
  static const List<Map<String, Object?>> moonPhases = [
{phases}
  ];

  /// order: conjunction, sextile, square, trine, opposition, none.
  static const List<Map<String, Object?>> aspects = [
{aspects}
  ];

  /// Chaldean weekday rulers, index 0..6 = Saturday..Friday.
  static const List<Map<String, Object?>> weekdayRulers = [
{rulers}
  ];

  /// Weekly theme variants per Moon element (fire/earth/air/water).
  static const Map<String, List<String>> weekThemes = {themes};

  /// Solar-Hijri month → seasonal sky map, index 0..11 = فروردین..اسفند.
  static const List<Map<String, Object?>> monthSeasons = [
{months}
  ];
}}
"""


def main():
    validate()
    data = {
        "intro": SKY_INTRO,
        "moonInSigns": MOON_IN_SIGNS,
        "moonPhases": MOON_PHASES,
        "aspects": ASPECTS,
        "weekdayRulers": WEEKDAY_RULERS,
        "weekThemes": WEEK_THEMES,
        "monthSeasons": MONTH_SEASONS,
    }
    json_path = os.path.join(ROOT, "content", "astro_transits.json")
    dart_path = os.path.join(ROOT, "lib", "data", "content",
                             "astro_content.dart")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1, sort_keys=True)
    with open(dart_path, "w", encoding="utf-8") as f:
        f.write(generate_dart())
    print("wrote:")
    print(f"  {os.path.relpath(json_path, ROOT)}")
    print(f"  {os.path.relpath(dart_path, ROOT)}")


if __name__ == "__main__":
    main()
