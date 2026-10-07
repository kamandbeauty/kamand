#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Content pipeline for the "سنت‌های طالع‌بینی" (world traditions) module of «طالع بین».

Five traditions, all computed OFFLINE from the birth date:
  1. Chinese (Shengxiao) — animal + element + yin/yang, with real Chinese
     New Year boundaries computed astronomically (Meeus new moons + zhongqi).
  2. Numerology — Pythagorean life path + personal year + Persian Abjad.
  3. Iranian-Islamic (ahkam al-nujum) — 28 lunar mansions (manazil al-qamar).
  4. Vedic (Jyotisha) — sidereal Moon rashi + nakshatra (runtime ephemeris).
  5. Maya (Tzolkin) — 20 nawals x 13 tones = 260-day sacred round.

Outputs:
  1. content/traditions.json               — merged content (source of truth)
  2. lib/data/content/traditions_content.dart — generated Dart data layer

All horoscope/personality texts are ORIGINAL Persian compositions written for
this project (entertainment/interpretive framing, no scientific claims).

Run: python3 tool/content_traditions.py
"""
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

from traditions_data import (  # noqa: E402
    ABJAD_INTRO, ABJAD_MAP, CHINESE_ANIMALS, CHINESE_COMPAT_TEXT,
    CHINESE_ELEMENTS, CHINESE_INTRO, CHINESE_NEW_YEAR_TABLE,
    CHINESE_POLARITY, CHINESE_RULES, DISCLAIMER, IRANIAN_INTRO, IRANIAN_MANAZIL, MAYAN_INTRO, MAYAN_NAWALS,
    MAYAN_TONES, NUMEROLOGY_INTRO, NUMEROLOGY_NUMBERS,
    NUMEROLOGY_PERSONAL_YEAR, VEDIC_INTRO, VEDIC_NAKSHATRAS, VEDIC_RASHIS,
)

# ══════════════════════════════════════════════════════════════════════
#  Astronomy helpers (Meeus, "Astronomical Algorithms", low precision)
# ══════════════════════════════════════════════════════════════════════

def _norm360(x):
    x = math.fmod(x, 360.0)
    return x + 360.0 if x < 0 else x


def sun_longitude(jd):
    """Apparent geocentric longitude of the Sun (deg). ±0.01°."""
    t = (jd - 2451545.0) / 36525.0
    l0 = 280.46646 + 36000.76983 * t + 0.0003032 * t * t
    m = 357.52911 + 35999.05029 * t - 0.0001537 * t * t
    c = ((1.914602 - 0.004817 * t - 0.000014 * t * t) * math.sin(math.radians(m))
         + (0.019993 - 0.000101 * t) * math.sin(math.radians(2 * m))
         + 0.000289 * math.sin(math.radians(3 * m)))
    omega = 125.04 - 1934.136 * t
    return _norm360(l0 + c - 0.00569 - 0.00478 * math.sin(math.radians(omega)))


_MOON_TERMS = [
    # (D, M, M', F, coefficient in 1e-6 deg) — 20 largest terms of Meeus 47.A
    (0, 0, 1, 0, 6288774), (2, 0, -1, 0, 1274027), (2, 0, 0, 0, 658314),
    (0, 0, 2, 0, 213618), (0, 1, 0, 0, -185116), (0, 0, 0, 2, -114332),
    (2, 0, -2, 0, 58793), (2, -1, -1, 0, 57066), (2, 0, 1, 0, 53322),
    (2, -1, 0, 0, 45758), (0, 1, -1, 0, -40923), (1, 0, 0, 0, -34720),
    (0, 1, 1, 0, -30383), (2, 0, 0, -2, 15327), (0, 0, 1, 2, -12528),
    (0, 0, 1, -2, 10980), (4, 0, -1, 0, 10675), (0, 0, 3, 0, 10034),
    (4, 0, -2, 0, 8548), (2, 1, -1, 0, -7888),
]


def moon_longitude(jd):
    """Geocentric longitude of the Moon (deg). ±0.3° (20-term truncation)."""
    t = (jd - 2451545.0) / 36525.0
    lp = (218.3164477 + 481267.88123421 * t - 0.0015786 * t * t
          + t ** 3 / 538841.0 - t ** 4 / 65194000.0)
    d = (297.8501921 + 445267.1114034 * t - 0.0018819 * t * t
         + t ** 3 / 545868.0 - t ** 4 / 113065000.0)
    m = 357.5291092 + 35999.0502909 * t - 0.0001536 * t * t + t ** 3 / 24490000.0
    mp = (134.9633964 + 477198.8675055 * t + 0.0087414 * t * t
          + t ** 3 / 69699.0 - t ** 4 / 14712000.0)
    f = (93.2720950 + 483202.0175233 * t - 0.0036539 * t * t
         - t ** 3 / 3526000.0 + t ** 4 / 863310000.0)
    rad = math.radians
    total = 0.0
    for cd, cm, cmp_, cf, coef in _MOON_TERMS:
        total += (coef / 1000000.0) * math.sin(rad(cd * d + cm * m + cmp_ * mp + cf * f))
    return _norm360(lp + total)


def _elongation(jd):
    """Moon minus Sun apparent longitude difference, normalized to ±180."""
    e = (moon_longitude(jd) - sun_longitude(jd)) % 360.0
    return e - 360.0 if e > 180.0 else e


def new_moon(k):
    """New-moon instant (JD, UT~TT) for lunation index k.

    The mean lunation formula (Meeus 49.1) provides the initial guess;
    the exact conjunction is then solved with Newton iterations from the
    validated Sun/Moon longitude series (±0.01°/±0.005°), giving the
    instant to well under a minute of arc-based timing error.
    """
    t = k / 1236.85
    t2 = t * t
    jde = (2451550.09766 + 29.530588861 * k + 0.00015437 * t2
           - 0.000000150 * t ** 3 + 0.00000000073 * t ** 4)
    jd = jde
    for _ in range(12):
        e = _elongation(jd)
        if abs(e) < 1e-7:
            break
        jd -= e / 12.190749  # mean lunar-solar relative motion, deg/day
    return jd


def _sun_event_near(target, jd_guess):
    jd0 = jd_guess
    for _ in range(50):
        diff = _norm360(sun_longitude(jd0) - target)
        if diff > 180.0:
            diff -= 360.0
        if abs(diff) < 1e-8:
            break
        jd0 -= diff / 0.9856
    return jd0


def _floor_beijing(jd):
    """Floor of (JD + 8h) as (y, m, d) Gregorian (Beijing civil date)."""
    z = int(math.floor(jd + 0.5 + 8.0 / 24.0))
    alpha = z + 32044
    b = (4 * alpha + 3) // 146097
    c = alpha - (146097 * b) // 4
    d2 = (4 * c + 3) // 1461
    e = c - (1461 * d2) // 4
    m2 = (5 * e + 2) // 153
    day = e - (153 * m2 + 2) // 5 + 1
    month = m2 + 3 - 12 * (m2 // 10)
    year = 100 * b + d2 - 4800 + (m2 // 10)
    return year, month, day


def _new_moon_k_before(jd):
    k = int(math.floor((jd - 2451550.09766) / 29.530588861))
    while new_moon(k) > jd:
        k -= 1
    while new_moon(k + 1) <= jd:
        k += 1
    return k


def _day_number(jd):
    """Beijing civil-day number (integer) containing instant `jd`."""
    return int(math.floor(jd + 0.5 + 8.0 / 24.0))


def _month11_start_day(greg_year):
    """Start day (Beijing) of month 11 — the month whose DAY contains the
    December solstice of `greg_year` (solstice around Dec 21)."""
    solstice = _sun_event_near(270.0, gregorian_to_jd(greg_year, 12, 1) + 20.0)
    solstice_day = _day_number(solstice)
    k = int(math.floor((solstice - 2451550.09766) / 29.530588861)) + 2
    while _day_number(new_moon(k)) > solstice_day:
        k -= 1
    while _day_number(new_moon(k + 1)) <= solstice_day:
        k += 1
    return k, solstice


def chinese_new_year(greg_year):
    """First day of Chinese month 1, in Beijing time.

    Rule (Aslaksen, "Mathematics of the Chinese Calendar"):
      * month 11 contains the December solstice (by civil day);
      * if there are 13 lunations between month 11 of year Y-1 and month 11
        of year Y, the FIRST month after month 11 that contains no zhongqi
        (major solar term, by civil day) is the leap month and keeps the
        number of the preceding month;
      * CNY is the first day of month 1.
    In 12-lunation spans no leap month exists, even if some month happens
    to lack a zhongqi (this is what makes 1985 work).
    """
    k11, solstice = _month11_start_day(greg_year - 1)
    k11_next, _ = _month11_start_day(greg_year)

    # Month starts strictly after month 11, up to and including next m11.
    moons = [new_moon(k) for k in range(k11 + 1, k11_next + 1)]
    n_lunations = len(moons) - 1  # months between the two month-11s
    is_leap_year = (n_lunations == 13)

    # zhongqi (sun longitude 270° + 30°·m) as Beijing civil days.
    zhongqi_days = []
    for mult in range(0, 15):
        target = (270.0 + 30.0 * mult) % 360.0
        ev = _sun_event_near(target, solstice + 30.5 * mult)
        zhongqi_days.append(_day_number(ev))

    days = [_day_number(m) for m in moons]
    prev_num = 11
    leap_available = is_leap_year
    for i in range(len(moons) - 1):
        zc = sum(1 for zd in zhongqi_days if days[i] <= zd < days[i + 1])
        if leap_available and zc == 0 and prev_num >= 11:
            leap_available = False  # leap month keeps prev_num
            continue
        prev_num = prev_num + 1 if prev_num != 12 else 1
        if prev_num == 1:
            return _floor_beijing(moons[i])
    return None


def gregorian_to_jd(y, m, d):
    a = (14 - m) // 12
    yy = y + 4800 - a
    mm = m + 12 * a - 3
    jdn = d + (153 * mm + 2) // 5 + 365 * yy + yy // 4 - yy // 100 + yy // 400 - 32045
    return jdn - 0.5


# Known CNY dates (independent anchors for validating the algorithm).
KNOWN_CNY = {
    1900: (1900, 1, 31), 1901: (1901, 2, 19), 1924: (1924, 2, 5),
    1972: (1972, 2, 15), 1984: (1984, 2, 2), 1996: (1996, 2, 19),
    2000: (2000, 2, 5), 2008: (2008, 2, 7), 2015: (2015, 2, 19),
    2020: (2020, 1, 25), 2021: (2021, 2, 12), 2023: (2023, 1, 22),
    2024: (2024, 2, 10), 2025: (2025, 1, 29), 2026: (2026, 2, 17),
}

# ══════════════════════════════════════════════════════════════════════
#  Content — all texts are original Persian compositions for this project
# ══════════════════════════════════════════════════════════════════════

# ══════════════════════════════════════════════════════════════════════
#  Build + emit
# ══════════════════════════════════════════════════════════════════════

CNY_FIRST_YEAR = 1900
CNY_LAST_YEAR = 2100


def build_cny_table():
    """Chinese New Year dates for [1900 .. 2100] as 'MM-DD' strings.

    The authoritative values come from the published table embedded in
    tool/traditions_data.py (extracted from the `lunarcalendar` package,
    HKO data). Our astronomical chinese_new_year() is kept as an
    independent cross-check and must agree on >= 199 of the 201 years.
    """
    table = []
    agreed = 0
    deviations = []
    for year in range(CNY_FIRST_YEAR, CNY_LAST_YEAR + 1):
        md = CHINESE_NEW_YEAR_TABLE[str(year)]
        table.append(md)
        computed = chinese_new_year(year)
        if computed is not None and (year, int(md[:2]), int(md[3:])) == computed:
            agreed += 1
        else:
            deviations.append(year)
    if len(table) != len(CHINESE_NEW_YEAR_TABLE):
        raise SystemExit("CNY table size mismatch")
    if agreed < 199:
        raise SystemExit(f"astronomical cross-check degraded: only {agreed}/201")
    print(f"CNY table: {len(table)} years, astronomical cross-check "
          f"{agreed}/201 agree (deviations: {deviations})")
    return table


def validate_cny():
    """Validate the astronomical CNY rule against known anchors."""
    failures = []
    for year, expected in sorted(KNOWN_CNY.items()):
        got = chinese_new_year(year)
        if got != expected:
            failures.append((year, expected, got))
    return failures


def dart_string(value):
    """Escape a Python string as a Dart single-quoted literal."""
    out = value.replace('\\', '\\\\').replace("'", "\\'")
    out = out.replace('"', '\\"').replace('$', '\\$')
    out = out.replace('\n', '\\n')
    return f"'{out}'"


def dart_map_ss(pairs, indent):
    lines = [f"{dart_string(k)}: {dart_string(v)}," for k, v in pairs]
    if not lines:
        return "{}"
    inner = ("\n" + indent + "  ").join(lines)
    return "{\n" + indent + "  " + inner + "\n" + indent + "}"


def dart_map_si(pairs, indent):
    """Map<String, int> emitter."""
    lines = [f"{dart_string(k)}: {v}," for k, v in pairs]
    if not lines:
        return "{}"
    inner = ("\n" + indent + "  ").join(lines)
    return "{\n" + indent + "  " + inner + "\n" + indent + "}"


def dart_map_so(pairs, indent):
    """Map<String, Object?> with nested maps."""
    parts = []
    for k, v in pairs:
        if isinstance(v, str):
            parts.append(f"{dart_string(k)}: {dart_string(v)}")
        elif isinstance(v, dict):
            sub = dart_map_so(list(v.items()), indent + "    ")
            parts.append(f"{dart_string(k)}: {sub}")
        elif isinstance(v, list):
            sub = "[" + ", ".join(str(i) for i in v) + "]"
            parts.append(f"{dart_string(k)}: {sub}")
        else:
            parts.append(f"{dart_string(k)}: {v}")
    inner = (",\n" + indent + "  ").join(parts)
    return "{\n" + indent + "  " + inner + ",\n" + indent + "}"


def animal_block(a, indent):
    lines = [
        f"{indent}{{",
        f"{indent}  'id': {dart_string(a['id'])},",
        f"{indent}  'nameFa': {dart_string(a['nameFa'])},",
        f"{indent}  'emoji': {dart_string(a['emoji'])},",
        f"{indent}  'personality': {dart_string(a['personality'])},",
    ]
    lines.append(f"{indent}  'strengths': [" +
                 ", ".join(dart_string(x) for x in a['strengths']) + "],")
    lines.append(f"{indent}  'weaknesses': [" +
                 ", ".join(dart_string(x) for x in a['weaknesses']) + "],")
    lines.append(f"{indent}  'love': {dart_string(a['love'])},")
    lines.append(f"{indent}  'work': {dart_string(a['work'])},")
    lines.append(f"{indent}  'luckyColor': {dart_string(a['luckyColor'])},")
    lines.append(f"{indent}  'luckyNumber': {a['luckyNumber']},")
    lines.append(f"{indent}}},")
    return "\n".join(lines)


def simple_block(d, keys, indent):
    lines = [f"{indent}{{"]
    for k in keys:
        v = d[k]
        if isinstance(v, str):
            lines.append(f"{indent}  '{k}': {dart_string(v)},")
        else:
            lines.append(f"{indent}  '{k}': {v},")
    lines.append(f"{indent}}},")
    return "\n".join(lines)


def generate_dart(cny_table):
    animals = "\n".join(animal_block(a, "      ") for a in CHINESE_ANIMALS)
    elements = "\n".join(simple_block(e, ["id", "nameFa", "text"], "      ")
                         for e in CHINESE_ELEMENTS)
    manazil = "\n".join(simple_block(m, ["name", "nature", "text"], "      ")
                        for m in IRANIAN_MANAZIL)
    rashis = "\n".join(simple_block(r, ["id", "nameFa", "symbol", "text"], "      ")
                       for r in VEDIC_RASHIS)
    nakshatras = "\n".join(simple_block(n, ["name", "text"], "      ")
                           for n in VEDIC_NAKSHATRAS)
    nawals = "\n".join(simple_block(n, ["name", "nameFa", "text"], "      ")
                       for n in MAYAN_NAWALS)

    numbers = dart_map_so(
        [(k, v) for k, v in sorted(NUMEROLOGY_NUMBERS.items(), key=lambda kv: int(kv[0]))],
        "    ")
    pyear = dart_map_ss(
        [(k, v) for k, v in sorted(NUMEROLOGY_PERSONAL_YEAR.items(), key=lambda kv: int(kv[0]))],
        "    ")
    tones = dart_map_ss(
        [(k, v) for k, v in sorted(MAYAN_TONES.items(), key=lambda kv: int(kv[0]))],
        "    ")
    abjad = dart_map_si(sorted(ABJAD_MAP.items(), key=lambda kv: kv[1]),
                        "    ")
    compat = dart_map_ss(list(CHINESE_COMPAT_TEXT.items()), "    ")
    polarity = dart_map_ss(list(CHINESE_POLARITY.items()), "    ")
    rules = dart_map_so([
        ("sanHe", CHINESE_RULES["sanHe"]),
        ("liuHe", CHINESE_RULES["liuHe"]),
        ("chong", CHINESE_RULES["chong"]),
    ], "    ")
    cny_list = ",\n    ".join(dart_string(x) for x in cny_table)

    return f"""// GENERATED FILE — DO NOT EDIT BY HAND.
// Source: tool/traditions_data.py + tool/content_traditions.py
// Regenerate with: python3 tool/content_traditions.py
//
// Content for the five world-tradition modules of «طالع بین»:
// Chinese (Shengxiao), Numerology (+Abjad), Iranian-Islamic (manazil),
// Vedic (rashi/nakshatra), Maya (Tzolkin). All texts are original
// Persian compositions (entertainment/interpretive framing).

// ignore_for_file: public_member_api_docs

class TraditionsContent {{
  TraditionsContent._();

  static const String disclaimer = {dart_string(DISCLAIMER)};

  // ── 1. Chinese ────────────────────────────────────────────────────
  static const String chineseIntro = {dart_string(CHINESE_INTRO)};
  static const List<Map<String, Object?>> chineseAnimals = [
{animals}
  ];
  static const List<Map<String, Object?>> chineseElements = [
{elements}
  ];
  static const Map<String, String> chinesePolarity = {polarity};
  static const Map<String, Object?> chineseRules = {rules};
  static const Map<String, String> chineseCompatText = {compat};
  static const int chineseNewYearStartYear = {CNY_FIRST_YEAR};
  static const List<String> chineseNewYearDates = [
    {cny_list}
  ];

  // ── 2. Numerology ─────────────────────────────────────────────────
  static const String numerologyIntro = {dart_string(NUMEROLOGY_INTRO)};
  static const Map<String, Object?> numerologyNumbers = {numbers};
  static const Map<String, String> numerologyPersonalYear = {pyear};
  static const String abjadIntro = {dart_string(ABJAD_INTRO)};
  static const Map<String, int> abjadValues = {abjad};

  // ── 3. Iranian-Islamic ────────────────────────────────────────────
  static const String iranianIntro = {dart_string(IRANIAN_INTRO)};
  static const List<Map<String, Object?>> iranianManazil = [
{manazil}
  ];

  // ── 4. Vedic ──────────────────────────────────────────────────────
  static const String vedicIntro = {dart_string(VEDIC_INTRO)};
  static const List<Map<String, Object?>> vedicRashis = [
{rashis}
  ];
  static const List<Map<String, Object?>> vedicNakshatras = [
{nakshatras}
  ];

  // ── 5. Maya ───────────────────────────────────────────────────────
  static const String mayanIntro = {dart_string(MAYAN_INTRO)};
  static const List<Map<String, Object?>> mayanNawals = [
{nawals}
  ];
  static const Map<String, String> mayanTones = {tones};
}}
"""


def main():
    failures = validate_cny()
    if failures:
        for year, expected, got in failures:
            print(f"  CNY MISMATCH {year}: expected {expected}, got {got}")
        raise SystemExit("CNY validation FAILED — do not trust the table!")
    print(f"CNY validation: all {len(KNOWN_CNY)} known anchors match ✓")

    # sanity: new-moon & sun/moon longitudes at a documented event
    # (new moon 2000-01-06 18:14 UT => JD 2451550.268)
    jd_nm = 2451550.268
    diff = abs((moon_longitude(jd_nm) - sun_longitude(jd_nm) + 180) % 360 - 180)
    print(f"elongation at documented new moon: {diff:.3f}° (expect < 0.5)")

    cny_table = build_cny_table()
    print(f"CNY table: {len(cny_table)} years "
          f"({CNY_FIRST_YEAR}–{CNY_LAST_YEAR})")

    data = {
        "disclaimer": DISCLAIMER,
        "chinese": {
            "intro": CHINESE_INTRO,
            "animals": CHINESE_ANIMALS,
            "elements": CHINESE_ELEMENTS,
            "polarity": CHINESE_POLARITY,
            "rules": CHINESE_RULES,
            "compatText": CHINESE_COMPAT_TEXT,
            "newYearStartYear": CNY_FIRST_YEAR,
            "newYearDates": cny_table,
        },
        "numerology": {
            "intro": NUMEROLOGY_INTRO,
            "numbers": NUMEROLOGY_NUMBERS,
            "personalYear": NUMEROLOGY_PERSONAL_YEAR,
            "abjadIntro": ABJAD_INTRO,
            "abjad": ABJAD_MAP,
        },
        "iranian": {
            "intro": IRANIAN_INTRO,
            "manazil": IRANIAN_MANAZIL,
        },
        "vedic": {
            "intro": VEDIC_INTRO,
            "rashis": VEDIC_RASHIS,
            "nakshatras": VEDIC_NAKSHATRAS,
        },
        "mayan": {
            "intro": MAYAN_INTRO,
            "nawals": MAYAN_NAWALS,
            "tones": MAYAN_TONES,
        },
    }

    json_path = os.path.join(ROOT, "content", "traditions.json")
    dart_path = os.path.join(ROOT, "lib", "data", "content",
                             "traditions_content.dart")
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1, sort_keys=True)
    with open(dart_path, "w", encoding="utf-8") as f:
        f.write(generate_dart(cny_table))
    print("wrote:")
    print(f"  {os.path.relpath(json_path, ROOT)}")
    print(f"  {os.path.relpath(dart_path, ROOT)}")

    # Reference values for the Dart unit tests (same formulas in Dart).
    print("\n— reference values for Dart tests —")
    for label, (y, m, d) in [
        ("1984-02-02", (1984, 2, 2)), ("1984-02-01", (1984, 2, 1)),
        ("2000-02-05", (2000, 2, 5)), ("2000-02-04", (2000, 2, 4)),
        ("2026-02-17", (2026, 2, 17)), ("2026-02-16", (2026, 2, 16)),
        ("1992-11-29", (1992, 11, 29)),
    ]:
        jd = gregorian_to_jd(y, m, d) + 0.5  # noon
        jdn = int(round(gregorian_to_jd(y, m, d)))
        sid = (moon_longitude(jd) - 23.853 - (jd - 2451545.0) / 365.25
               * (50.29 / 3600)) % 360
        tone = ((jdn - 2456280) % 13) + 1
        nawal = (jdn - 2456264) % 20
        rashi = int(sid // 30)
        naks = int(sid // (360 / 27))
        pada = int(sid % (360 / 27) // (360 / 108)) + 1
        manzil = int(sid // (360 / 28))
        print(f"{label}: tzolkin tone={tone} nawal={nawal} | siderealMoon="
              f"{sid:7.3f} rashi={rashi} naks={naks}/{pada} manzil={manzil}")


if __name__ == "__main__":
    main()
