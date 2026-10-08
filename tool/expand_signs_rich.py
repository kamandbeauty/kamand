#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Append the round-14 "rich" authored items to content/signs/*.json.

Idempotent: items already present are skipped, so re-running is safe
(CI regen stays deterministic). Afterwards, run tool/build_content.py
to regenerate the Dart data layer.

Run: python3 tool/expand_signs_rich.py
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from content_signs_rich_a import RICH_A
from content_signs_rich_b import RICH_B

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIGNS_DIR = os.path.join(ROOT, "content", "signs")

RICH = {**RICH_A, **RICH_B}
DAILY_KEYS = ["general", "love", "career", "finance", "mood", "warning", "opportunity"]
MONTHLY_KEYS = ["focus", "love", "career", "finance", "energy", "opportunity", "warning"]

EXPECTED_ORDER = [
    "aries", "taurus", "gemini", "cancer", "leo", "virgo",
    "libra", "scorpio", "sagittarius", "capricorn", "aquarius", "pisces",
]


def fail(msg):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def main():
    if set(RICH.keys()) != set(EXPECTED_ORDER):
        fail(f"rich bank covers {sorted(RICH.keys())}")

    added_total = 0
    for sign in EXPECTED_ORDER:
        path = os.path.join(SIGNS_DIR, f"{sign}.json")
        with open(path, encoding="utf-8") as f:
            data = json.load(f)

        added = 0
        for key in DAILY_KEYS:
            for item in RICH[sign][key]:
                if item not in data["daily"][key]:
                    data["daily"][key].append(item)
                    added += 1
        for item in RICH[sign]["weekly"]:
            if item not in data["weekly"]["summaries"]:
                data["weekly"]["summaries"].append(item)
                added += 1
        for key in MONTHLY_KEYS:
            for item in RICH[sign]["monthly"][key]:
                if item not in data["monthly"][key]:
                    data["monthly"][key].append(item)
                    added += 1

        # sanity: no cross-category duplicates within this sign
        seen = set()
        for key in DAILY_KEYS:
            for item in data["daily"][key]:
                if item in seen:
                    fail(f"{sign}: duplicate across categories: {item[:40]}")
                seen.add(item)

        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write("\n")

        added_total += added
        counts = {k: len(data["daily"][k]) for k in DAILY_KEYS}
        print(f"  {sign}: +{added}  daily={counts} "
              f"weekly={len(data['weekly']['summaries'])} "
              f"monthly={ {k: len(v) for k, v in data['monthly'].items()} }")

    print(f"DONE: {added_total} new items appended")


if __name__ == "__main__":
    main()
