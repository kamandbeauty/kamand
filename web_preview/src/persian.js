// Persian presentation helpers (mirrors lib/core/utils/persian_numbers.dart).

import { jalaliDayOfWeek } from './engine.js';

const FA_DIGITS = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

/** Convert all ASCII digits in a string/number to Persian digits. */
export function fa(value) {
  return String(value).replace(/[0-9]/g, (d) => FA_DIGITS[+d]);
}

/** 1..12 → ۰۱..۱۲ */
export function fa2(value) {
  return fa(String(value).padStart(2, '0'));
}

export const JALALI_MONTHS = [
  'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
  'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
];

export const WEEKDAYS_SHORT = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج']; // Sat..Fri

// Names indexed by JS getDay() (0=Sun … 6=Sat).
const GREGORIAN_DOW_NAMES = [
  'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه',
];

/** Jalali [y, m, d] → «سه‌شنبه ۱۵ مهر ۱۴۰۵». */
export function formatJalaliLong(triple) {
  const [y, m, d] = triple;
  const dow = GREGORIAN_DOW_NAMES[jalaliDayOfWeek(triple)];
  return `${dow} ${fa(d)} ${JALALI_MONTHS[m - 1]} ${fa(y)}`;
}

/** Jalali [y, m, d] → «۱۵ مهر». */
export function formatJalaliShort(triple) {
  return `${fa(triple[2])} ${JALALI_MONTHS[triple[1] - 1]}`;
}

/** Short label for weekly day chips: «ش ۱۵». */
export function weekdayShortLabel(triple) {
  const dowSatFirst = (jalaliDayOfWeek(triple) + 1) % 7; // 0 = Saturday
  return `${WEEKDAYS_SHORT[dowSatFirst]} ${fa(triple[2])}`;
}

/** Score → short qualitative phrase (mirrors shortScorePhrase in Dart). */
export function shortScorePhrase(score) {
  if (score >= 85) return 'فوق‌العاده';
  if (score >= 70) return 'خیلی خوب';
  if (score >= 55) return 'خوب';
  if (score >= 40) return 'متوسط';
  return 'نیازمند مراقبت';
}

/** Compatibility overall → level label (mirrors Dart levelLabelFa). */
export function compatLevel(overall) {
  if (overall >= 85) return 'بسیار هماهنگ';
  if (overall >= 72) return 'هماهنگ';
  if (overall >= 60) return 'متوسط';
  if (overall >= 48) return 'نیازمند تلاش';
  return 'چالش‌برانگیز';
}

export const SCORE_LABELS = {
  love: 'عشق',
  career: 'کار',
  finance: 'مالی',
  mood: 'حال‌وهوا',
  energy: 'انرژی',
};
