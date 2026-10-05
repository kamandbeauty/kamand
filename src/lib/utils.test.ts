import { describe, it, expect } from 'vitest';
import { faNum, faDate, faDateTime, faTime } from '@/lib/utils';

describe('faNum', () => {
  it('converts small integers to Persian digits', () => {
    expect(faNum(0)).toBe('۰');
    expect(faNum(5)).toBe('۵');
    expect(faNum(42)).toBe('۴۲');
  });

  it('groups large numbers with the fa-IR separator', () => {
    expect(faNum(12500)).toBe((12500).toLocaleString('fa-IR'));
  });

  it('converts only the digits of a string', () => {
    expect(faNum('a1b2')).toBe('a۱b۲');
    expect(faNum('DIET-2026')).toBe('DIET-۲۰۲۶');
  });

  it('returns empty string for null/undefined', () => {
    expect(faNum(null)).toBe('');
    expect(faNum(undefined)).toBe('');
  });
});

describe('faDate', () => {
  it('renders a Gregorian date as Jalali', () => {
    // 2026-08-01 UTC = 10 Mordad 1405
    const iso = '2026-08-01T12:00:00Z';
    expect(faDate(iso, { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' })).toBe(
      '۱۰ مرداد ۱۴۰۵'
    );
  });

  it('returns empty string for invalid dates', () => {
    expect(faDate('not-a-date')).toBe('');
  });

  it('accepts Date objects', () => {
    expect(faDate(new Date('2026-08-01T12:00:00Z'), { day: 'numeric', timeZone: 'UTC' })).toBe('۱۰');
  });
});

describe('faDateTime / faTime', () => {
  it('includes both date and time', () => {
    const out = faDateTime('2026-08-01T12:00:00Z');
    expect(out).toContain('۱۰');
    expect(out).toMatch(/۱۲/);
  });

  it('returns empty string for invalid input', () => {
    expect(faTime('nope')).toBe('');
  });
});
