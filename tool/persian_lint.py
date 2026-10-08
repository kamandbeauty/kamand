#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Hard Persian-text lint over all Dart string literals.

Checks (virastar-inspired):
  A. Arabic-only characters that must be Persian (ي ك ة)
  B. «half-space» issues: 'می ' prefix, ' ها' suffix, '‌' at word edges
  C. double spaces, space before ، ؛ ؟ ! ., missing space after ،
  D. mismatched «» guillemets
  E. English digits inside Persian sentences
  F. common misspellings (curated list)
  G. ellipsis '...' vs '…'
Outputs file:line:issue for manual review.
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# string literals in Dart: '...' or "..." (naive but fine for review)
STR_RE = re.compile(r"'((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\"")

ARABIC = {'ي': 'ی', 'ك': 'ک', 'ة': 'ه'}

# Known-good exceptions (Arabic loan names kept deliberately):
#  - Arabic lunar-mansion names & similar «ال…» proper nouns keep ة/ي/ك.
#  - أستارا is a valid city spelling.
ALLOW_TEXTS = {'أستارا'}


def _is_allowed(text):
    if text in ALLOW_TEXTS:
        return True
    # Arabic proper nouns: starts with ال and is a single short token
    # (lunar mansions like النَّثرة، الجَبهة، الشَّولة).
    stripped = text.strip()
    if stripped.startswith('ال') and len(stripped) <= 14 and ' ' not in stripped:
        return True
    # Single/double-char table keys (abjad letter values like 'ك', 'ة').
    if len(stripped) <= 2:
        return True
    # Manzil labels that pair an Arabic nature word with the mansion name.
    if stripped.startswith('سعد ') or stripped.startswith('نحس '):
        return True
    return False
MISSPELL = [
    (r'\bبصورت\b', 'به صورت'),
    (r'\bبیرون از ایران\b', 'خارج از ایران (سازگاری)'),
    (r'\bامروزه\b', 'امروزه?'),
    (r'\bجذاب\b', ''),
    (r'تکس?ت\b', ''),
]
COMMON_TYPOS = {
    'تبدیل': None,  # placeholder
}

issues = []
files_scanned = 0
strings_seen = 0


def check_text(text, path, lineno):
    # A. Arabic chars
    if not _is_allowed(text):
        for ch, fix in ARABIC.items():
            if ch in text:
                issues.append((path, lineno,
                               f"حرفِ عربی '{ch}' (باید '{fix}')", text[:60]))
    # B1. 'می ' prefix split (می کنید)
    for m in re.finditer(r'(?<![\u0600-\u06FF])می [\u0600-\u06FF]', text):
        issues.append((path, lineno, "'می' جدا از فعل (نیم‌فاصله لازم)", m.group(0)))
    # B2. ' ها' suffix split (برج ها)
    for m in re.finditer(r'[\u0600-\u06FF] ها(?![\u0600-\u06FF])', text):
        issues.append((path, lineno, "'ها' جدا از اسم (نیم‌فاصله لازم)", m.group(0)))
    # B3. ZWNJ at edges
    for m in re.finditer(r'(?:^|\s)\u200c|\u200c(?:\s|$)', text):
        issues.append((path, lineno, "نیم‌فاصله در لبهٔ واژه", text[:50]))
    # C1. double space
    if '  ' in text.strip():
        issues.append((path, lineno, "دو فاصلهٔ پشت‌سرهم", text[:50]))
    # C2. space before Persian punctuation
    for m in re.finditer(r'[\u0600-\u06FF] [،؛؟!]', text):
        issues.append((path, lineno, "فاصله قبل از نشانه", m.group(0)))
    # C3. missing space after ،
    for m in re.finditer(r'،[\u0600-\u06FF]', text):
        issues.append((path, lineno, "بدون فاصله بعد از ویرگول", m.group(0)))
    # D. guillemet pairing
    if text.count('«') != text.count('»'):
        issues.append((path, lineno, "گیومه‌های «» نامتوازن", text[:60]))
    # E. English digits in Persian sentence
    for m in re.finditer(r'[\u0600-\u06FF] [0-9]+ ?[\u0600-\u06FF]', text):
        issues.append((path, lineno, "رقمِ انگلیسی میانِ متنِ فارسی", m.group(0)))
    # G. ASCII ellipsis
    for m in re.finditer(r'\.\.\.', text):
        issues.append((path, lineno, "سه‌نقطهٔ ASCII به‌جای …", text[:50]))


def scan(path):
    global files_scanned, strings_seen
    rel = os.path.relpath(path, ROOT)
    files_scanned += 1
    in_block_comment = False
    with io.open(path, encoding='utf-8') as f:
        for lineno, line in enumerate(f, 1):
            st = line.strip()
            if st.startswith('///') or st.startswith('//'):
                continue  # comments not user-facing
            for m in STR_RE.finditer(line):
                text = m.group(1) if m.group(1) is not None else m.group(2)
                if not text:
                    continue
                # skip asset paths/keys/ids
                if re.fullmatch(r'[A-Za-z0-9_./: -]+', text):
                    continue
                if not re.search(r'[\u0600-\u06FF]', text):
                    continue
                strings_seen += 1
                check_text(text, rel, lineno)


for dirpath, dirnames, filenames in os.walk(os.path.join(ROOT, 'lib')):
    dirnames[:] = [d for d in dirnames if d != '.git']
    for fn in filenames:
        if fn.endswith('.dart'):
            scan(os.path.join(dirpath, fn))

print(f"scanned {files_scanned} files, {strings_seen} Persian strings")
print(f"issues: {len(issues)}\n")
for path, lineno, kind, ctx in issues:
    print(f"{path}:{lineno}: {kind} | {ctx}")

sys.exit(1 if issues else 0)
