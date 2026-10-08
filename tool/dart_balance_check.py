#!/usr/bin/env python3
"""Brace/paren/bracket balance check for Dart files.

Single-pass scanner: strings (with escapes), line/block comments and
raw strings are skipped correctly, so a `//` inside a URL string (or an
apostrophe inside a comment) can never produce a false positive.
"""
import sys


def check(s: str):
    bal = {"{": 0, "(": 0, "[": 0}
    closer = {"}": "{", ")": "(", "]": "["}
    i, n = 0, len(s)
    while i < n:
        c = s[i]
        # line comment
        if c == "/" and i + 1 < n and s[i + 1] == "/":
            while i < n and s[i] != "\n":
                i += 1
            continue
        # block comment
        if c == "/" and i + 1 < n and s[i + 1] == "*":
            i += 2
            while i + 1 < n and not (s[i] == "*" and s[i + 1] == "/"):
                i += 1
            i += 2
            continue
        # raw triple-quoted string
        if c == "r" and i + 1 < n and s[i + 1:i + 4] in ("'''", '"""'):
            q = s[i + 1:i + 4]
            i = s.find(q, i + 4)
            i = n if i == -1 else i + 3
            continue
        # string literal (single or double quote)
        if c in ("'", '"'):
            q = c
            i += 1
            while i < n and s[i] != q:
                i += 2 if s[i] == "\\" else 1
            i += 1
            continue
        if c in bal:
            bal[c] += 1
        elif c in closer:
            bal[closer[c]] -= 1
            if bal[closer[c]] < 0:
                return bal, True
        i += 1
    return bal, any(v != 0 for v in bal.values())


for path in sys.argv[1:]:
    with open(path, encoding="utf-8") as f:
        s = f.read()
    bal, broken = check(s)
    ok = not broken and all(v == 0 for v in bal.values())
    print(f"{path}: {bal} {'OK' if ok else 'BROKEN'}")
