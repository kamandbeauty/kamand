#!/usr/bin/env python3
"""Brace/paren/bracket balance check for Dart files (comments+strings stripped)."""
import re
import sys

for path in sys.argv[1:]:
    s = open(path, encoding="utf-8").read()
    t = re.sub(r"/\*.*?\*/", "", s, flags=re.S)
    t = re.sub(r"//[^\n]*", "", t)
    t = re.sub(r"'''.*?'''", "''", t, flags=re.S)
    t = re.sub(r"'(?:\\.|[^'\\\n])*'", "''", t)
    t = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', t)
    bal = {"{": 0, "(": 0, "[": 0}
    broke = False
    for c in t:
        if c == "{":
            bal["{"] += 1
        elif c == "}":
            bal["{"] -= 1
        elif c == "(":
            bal["("] += 1
        elif c == ")":
            bal["("] -= 1
        elif c == "[":
            bal["["] += 1
        elif c == "]":
            bal["["] -= 1
        if any(v < 0 for v in bal.values()):
            broke = True
            break
    ok = not broke and all(v == 0 for v in bal.values())
    print(f"{path}: {bal} {'OK' if ok else 'BROKEN'}")
