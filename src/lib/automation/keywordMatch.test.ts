import { describe, it, expect } from 'vitest';
import { keywordMatches } from '@/lib/automation/keywordMatch';

describe('keywordMatches', () => {
  it('null keywords = wildcard: any text triggers', () => {
    expect(keywordMatches('سلام دوست من', null)).toBe(true);
  });

  it('empty keyword list = wildcard', () => {
    expect(keywordMatches('whatever', [])).toBe(true);
  });

  it('["*ANY*"] = explicit wildcard', () => {
    expect(keywordMatches('هر متنی', ['*ANY*'])).toBe(true);
  });

  it('case-insensitive whole-word match', () => {
    expect(keywordMatches('please send me the DIET plan', ['diet'])).toBe(true);
    expect(keywordMatches('Get The diet Plan', ['DIET'])).toBe(true);
  });

  it('no substring match - whole words only', () => {
    // "dietary" contains "diet" but is a different word
    expect(keywordMatches('my dietary habits', ['diet'])).toBe(false);
    expect(keywordMatches('editorial', ['diet'])).toBe(false);
  });

  it('word boundaries respect punctuation and Persian text', () => {
    expect(keywordMatches('send DIET!', ['diet'])).toBe(true);
    // Persian keywords must match (the reason \b was replaced with Unicode lookarounds)
    expect(keywordMatches('لینک', ['لینک'])).toBe(true);
    expect(keywordMatches('لطفا لینک رو بفرست', ['لینک'])).toBe(true);
    // attached Persian suffix without ZWNJ = a different word
    expect(keywordMatches('لینکها', ['لینک'])).toBe(false);
    // ZWNJ is a boundary, so the keyword still matches inside the suffixed form
    expect(keywordMatches('لینک‌ها', ['لینک'])).toBe(true);
  });

  it('any keyword in the list matching is enough', () => {
    expect(keywordMatches('I want the GUIDE', ['diet', 'guide', 'link'])).toBe(true);
    expect(keywordMatches('nothing here', ['diet', 'guide'])).toBe(false);
  });

  it('a list containing only blank keywords matches nothing', () => {
    // (null/[] is the wildcard; a list of blanks has no usable keyword)
    expect(keywordMatches('anything', ['  ', ''])).toBe(false);
    expect(keywordMatches('the diet plan', [' ', 'diet'])).toBe(true);
  });

  it('regex metacharacters in keywords are escaped', () => {
    expect(keywordMatches('get C++ now', ['c++'])).toBe(true);
    expect(keywordMatches('get c+ now', ['c++'])).toBe(false);
  });
});
