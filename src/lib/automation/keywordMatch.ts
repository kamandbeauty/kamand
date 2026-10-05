/**
 * Keyword matching rules:
 *  - null / empty keywords  → any text triggers (wildcard)
 *  - ["*ANY*"]              → explicit wildcard
 *  - otherwise              → case-insensitive whole-word match
 *
 * Word boundaries use Unicode lookarounds (not JS \b): \b only knows
 * [A-Za-z0-9_], so Persian keywords like «لینک» would NEVER match with \b.
 * The lookarounds treat every Unicode letter/digit as a word character, which
 * makes Latin and Persian keywords behave identically. A ZWNJ (نیم‌فاصله)
 * counts as a boundary, so «لینک» still matches inside «لینک‌ها».
 */

export function keywordMatches(text: string, keywords: string[] | null): boolean {
  if (!keywords || keywords.length === 0 || keywords.includes('*ANY*')) {
    return true;
  }

  const normalizedText = text.toLowerCase();

  return keywords.some((keyword) => {
    const normalizedKeyword = keyword.toLowerCase().trim();
    if (!normalizedKeyword) return false;
    const wordBoundaryRegex = new RegExp(
      `(?<![\\p{L}\\p{N}_])${escapeRegex(normalizedKeyword)}(?![\\p{L}\\p{N}_])`,
      'u'
    );
    return wordBoundaryRegex.test(normalizedText);
  });
}

function escapeRegex(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
