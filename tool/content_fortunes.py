# -*- coding: utf-8 -*-
"""Generates content/fortunes.json + lib/data/content/fortunes_content.dart
from tool/fortune_data.py (authored Persian content).

Run: python3 tool/content_fortunes.py
"""
import io
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fortune_data import (  # noqa: E402
    ABJAD_FAL_INTRO, ABJAD_FORTUNES, ANIMAL_INTRO, GEM_INTRO, GEM_STONES,
    GREEK_HUMORS, GREEK_INTRO, GREEK_QUALITIES, GREEK_SIGNS,
    MARRIAGE_INTRO, MARRIAGE_SIGNS, MONTH_INTRO, MONTH_TRAITS,
    SPIRIT_ANIMALS, TAROT_CARDS, TAROT_INTRO,
)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

SIGN_IDS = ['aries', 'taurus', 'gemini', 'cancer', 'leo', 'virgo',
            'libra', 'scorpio', 'sagittarius', 'capricorn', 'aquarius',
            'pisces']


def validate():
    assert len(GEM_STONES) == 12
    assert sorted(g['month'] for g in GEM_STONES) == list(range(1, 13))
    assert len(ABJAD_FORTUNES) == 24
    assert [g['id'] for g in GREEK_SIGNS] == SIGN_IDS
    assert set(GREEK_HUMORS) == {'choleric', 'sanguine', 'melancholic',
                                 'phlegmatic'}
    assert set(GREEK_QUALITIES) == {'cardinal', 'fixed', 'mutable'}
    for g in GREEK_SIGNS:
        assert g['humor'] in GREEK_HUMORS and g['quality'] in GREEK_QUALITIES
    assert [x['id'] for x in MARRIAGE_SIGNS] == SIGN_IDS
    assert len(MONTH_TRAITS) == 12
    assert [t['month'] for t in MONTH_TRAITS] == list(range(1, 13))
    assert [t['index'] for t in TAROT_CARDS] == list(range(22))
    assert [a['id'] for a in SPIRIT_ANIMALS] == SIGN_IDS
    print("validation: all fortune structures OK ✓")


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


def map_ss(pairs, indent):
    lines = [f"{dart_string(k)}: {dart_string(v)}," for k, v in pairs]
    inner = ("\n" + indent + "  ").join(lines)
    return "{\n" + indent + "  " + inner + "\n" + indent + "}"


def generate_dart():
    stones = "\n".join(block(g, ["id", "nameFa", "month", "text"], "      ")
                       for g in GEM_STONES)
    greek = "\n".join(block(g, ["id", "greek", "humor", "quality", "myth"],
                            "      ") for g in GREEK_SIGNS)
    marriage = "\n".join(block(g, ["id", "bestFa", "text"], "      ")
                         for g in MARRIAGE_SIGNS)
    months = "\n".join(block(t, ["month", "title", "text"], "      ")
                       for t in MONTH_TRAITS)
    tarot = "\n".join(block(t, ["index", "nameFa", "nameEn", "text"], "      ")
                      for t in TAROT_CARDS)
    animals = "\n".join(block(a, ["id", "animal", "emoji", "text"], "      ")
                        for a in SPIRIT_ANIMALS)
    fortunes = "\n".join(f"      {dart_string(f)}," for f in ABJAD_FORTUNES)
    qualities = map_ss(list(GREEK_QUALITIES.items()), "    ")
    humors = map_ss(list(GREEK_HUMORS.items()), "    ")

    return f"""// GENERATED FILE — DO NOT EDIT BY HAND.
// Source: tool/fortune_data.py + tool/content_fortunes.py
// Regenerate with: python3 tool/content_fortunes.py
//
// Content for the fortune modules of «طالع بین»: gem oracle, abjad
// fortune, Greek (Hellenistic) astrology, marriage astrology,
// birth-month traits, tarot, inner animal. All texts are original
// Persian compositions (entertainment/interpretive framing).

// ignore_for_file: public_member_api_docs

class FortunesContent {{
  FortunesContent._();

  // ── Gem oracle ─────────────────────────────────────────────────────
  static const String gemIntro = {dart_string(GEM_INTRO)};
  static const List<Map<String, Object?>> gemStones = [
{stones}
  ];

  // ── Abjad fortune ──────────────────────────────────────────────────
  static const String abjadFalIntro = {dart_string(ABJAD_FAL_INTRO)};
  static const List<String> abjadFortunes = [
{fortunes}
  ];

  // ── Greek (Hellenistic) ────────────────────────────────────────────
  static const String greekIntro = {dart_string(GREEK_INTRO)};
  static const Map<String, String> greekQualities = {qualities};
  static const Map<String, String> greekHumors = {humors};
  static const List<Map<String, Object?>> greekSigns = [
{greek}
  ];

  // ── Marriage ───────────────────────────────────────────────────────
  static const String marriageIntro = {dart_string(MARRIAGE_INTRO)};
  static const List<Map<String, Object?>> marriageSigns = [
{marriage}
  ];

  // ── Birth-month traits ─────────────────────────────────────────────
  static const String monthIntro = {dart_string(MONTH_INTRO)};
  static const List<Map<String, Object?>> monthTraits = [
{months}
  ];

  // ── Tarot ──────────────────────────────────────────────────────────
  static const String tarotIntro = {dart_string(TAROT_INTRO)};
  static const List<Map<String, Object?>> tarotCards = [
{tarot}
  ];

  // ── Inner animal ───────────────────────────────────────────────────
  static const String animalIntro = {dart_string(ANIMAL_INTRO)};
  static const List<Map<String, Object?>> spiritAnimals = [
{animals}
  ];
}}
"""


def main():
    validate()

    data = {
        "gem": {"intro": GEM_INTRO, "stones": GEM_STONES},
        "abjadFal": {"intro": ABJAD_FAL_INTRO, "fortunes": ABJAD_FORTUNES},
        "greek": {
            "intro": GREEK_INTRO,
            "qualities": GREEK_QUALITIES,
            "humors": GREEK_HUMORS,
            "signs": GREEK_SIGNS,
        },
        "marriage": {"intro": MARRIAGE_INTRO, "signs": MARRIAGE_SIGNS},
        "monthTraits": {"intro": MONTH_INTRO, "months": MONTH_TRAITS},
        "tarot": {"intro": TAROT_INTRO, "cards": TAROT_CARDS},
        "animal": {"intro": ANIMAL_INTRO, "animals": SPIRIT_ANIMALS},
    }

    json_path = os.path.join(ROOT, "content", "fortunes.json")
    dart_path = os.path.join(ROOT, "lib", "data", "content",
                             "fortunes_content.dart")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1, sort_keys=True)
    with open(dart_path, "w", encoding="utf-8") as f:
        f.write(generate_dart())
    print("wrote:")
    print(f"  {os.path.relpath(json_path, ROOT)}")
    print(f"  {os.path.relpath(dart_path, ROOT)}")


if __name__ == "__main__":
    main()
