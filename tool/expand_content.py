#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Expand the horoscope content bank.

Keeps every existing authored sentence, then fills each pool up to its
target size with frame × phrase combinations (deterministic, deduped).
Writes content/signs/*.json in place — run tool/build_content.py after
this to regenerate the Dart/web artifacts.

Run: python3 tool/expand_content.py
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from content_frames import TEMPLATES, MOVES, TAILS  # noqa: E402
from content_signs_a import ARIES, TAURUS, GEMINI, CANCER, LEO, VIRGO  # noqa: E402
from content_signs_b import (  # noqa: E402
    LIBRA, SCORPIO, SAGITTARIUS, CAPRICORN, AQUARIUS, PISCES,
)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIGNS_DIR = os.path.join(ROOT, "content", "signs")

SIGN_POOLS = {
    "aries": ARIES, "taurus": TAURUS, "gemini": GEMINI,
    "cancer": CANCER, "leo": LEO, "virgo": VIRGO,
    "libra": LIBRA, "scorpio": SCORPIO, "sagittarius": SAGITTARIUS,
    "capricorn": CAPRICORN, "aquarius": AQUARIUS, "pisces": PISCES,
}

# Pool key in the JSON → (pool key in lexicon, moves key, target size)
DAILY_MAP = [
    ("general", "gen", "general", 18),
    ("love", "love", "love", 15),
    ("career", "career", "career", 15),
    ("finance", "finance", "finance", 13),
    ("mood", "mood", "mood", 13),
    ("warning", "warn", "warning", 10),
    ("opportunity", "opp", "opportunity", 10),
]

WEEKLY_TARGET = 12

# monthly key → (frame key, lexicon pool, moves key, target)
MONTHLY_MAP = [
    ("focus", "m_focus", "gen", "m_focus", 6),
    ("love", "m_love", "love", "m_love", 6),
    ("career", "m_career", "career", "m_career", 6),
    ("finance", "m_finance", "finance", "m_finance", 6),
    ("energy", "m_energy", "mood", "m_energy", 6),
    ("opportunity", "m_opportunity", "opp", "m_opportunity", 6),
    ("warning", "m_warning", "warn", "m_warning", 6),
]


def combos(pools_a, moves):
    """All (a, m) pairs in a stable, spread-out order."""
    out = []
    n = max(len(pools_a), len(moves))
    for i in range(n):
        for j in range(n):
            if i < len(pools_a) and j < len(moves):
                out.append((pools_a[i % len(pools_a)], moves[(i + j) % len(moves)]))
    return out


def fill(existing, target, templates, pool, moves, tails):
    """Grow `existing` up to `target` with unique frame outputs."""
    result = list(existing)
    seen = set(result)
    used_a = {}

    pairs = combos(pool, moves)
    ti = 0  # template index (round-robin)
    pi = 0  # pair index
    guard = 0
    while len(result) < target and guard < 5000:
        guard += 1
        if pi >= len(pairs):
            break
        a, m = pairs[pi]
        pi += 1
        if used_a.get(a, 0) >= 3:
            continue
        tmpl = templates[ti % len(templates)]
        ti += 1
        if "{T}" in tmpl:
            t = tails[(ti * 3 + pi * 7) % len(tails)]
            s = tmpl.format(A=a, M=m, T=t)
        else:
            s = tmpl.format(A=a, M=m)
        if s in seen:
            continue
        # Basic Persian punctuation hygiene.
        s = s.replace("..", ".").replace(" ؛", "؛").replace("؛ ", "؛ ")
        s = s.replace("  ", " ").strip()
        if not s.endswith((".", "!", "؟", "…")):
            s += "."
        seen.add(s)
        used_a[a] = used_a.get(a, 0) + 1
        result.append(s)
    return result


def main():
    total_before = 0
    total_after = 0
    for sign_id, pools in SIGN_POOLS.items():
        path = os.path.join(SIGNS_DIR, f"{sign_id}.json")
        with open(path, encoding="utf-8") as f:
            data = json.load(f)

        for json_key, lex_key, moves_key, target in DAILY_MAP:
            before = data["daily"][json_key]
            total_before += len(before)
            data["daily"][json_key] = fill(
                before, target,
                TEMPLATES[json_key], pools[lex_key], MOVES[moves_key], TAILS,
            )
            total_after += len(data["daily"][json_key])

        before = data["weekly"]["summaries"]
        total_before += len(before)
        # weekly reuses the general pool with weekly frames + moves
        data["weekly"]["summaries"] = fill(
            before, WEEKLY_TARGET,
            TEMPLATES["weekly"], pools["gen"] + pools["weekly"], MOVES["weekly"], TAILS,
        )
        total_after += len(data["weekly"]["summaries"])

        for json_key, frame_key, lex_key, moves_key, target in MONTHLY_MAP:
            before = data["monthly"][json_key]
            total_before += len(before)
            data["monthly"][json_key] = fill(
                before, target,
                TEMPLATES[frame_key], pools[lex_key], MOVES[moves_key], TAILS,
            )
            total_after += len(data["monthly"][json_key])

        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")

    print(f"content bank: {total_before} → {total_after} sentences")
    if total_after < total_before * 2:
        print("WARNING: expansion below 2x — check pool sizes", file=sys.stderr)


if __name__ == "__main__":
    main()
