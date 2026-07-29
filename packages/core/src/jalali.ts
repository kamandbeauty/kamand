/**
 * تاریخ جلالی (شمسی) — بدون وابستگی خارجی.
 * قاعدهٔ ذخیره‌سازی در جاوید: داده همیشه به صورت ISO میلادی ذخیره می‌شود،
 * فقط در لحظهٔ نمایش به شمسی تبدیل می‌گردد.
 */

export interface JalaliDate {
  jy: number;
  jm: number;
  jd: number;
}

const BREAKS = [
  -61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210, 1635, 2060, 2097, 2192, 2262, 2324, 2394,
  2456, 3178,
];

function jalCal(jy: number): { leap: number; gy: number; march: number } {
  const bl = BREAKS.length;
  const gy = jy + 621;
  let leapJ = -14;
  let jp = BREAKS[0]!;
  if (jy < jp || jy >= BREAKS[bl - 1]!) throw new Error('سال جلالی خارج از محدوده است');

  let jump = 0;
  for (let i = 1; i < bl; i++) {
    const jm = BREAKS[i]!;
    jump = jm - jp;
    if (jy < jm) break;
    leapJ = leapJ + div(jump, 33) * 8 + div(mod(jump, 33), 4);
    jp = jm;
  }
  let n = jy - jp;
  leapJ = leapJ + div(n, 33) * 8 + div(mod(n, 33) + 3, 4);
  if (mod(jump, 33) === 4 && jump - n === 4) leapJ += 1;

  const leapG = div(gy, 4) - div((div(gy, 100) + 1) * 3, 4) - 150;
  const march = 20 + leapJ - leapG;

  if (jump - n < 6) n = n - jump + div(jump + 4, 33) * 33;
  let leap = mod(mod(n + 1, 33) - 1, 4);
  if (leap === -1) leap = 4;

  return { leap, gy, march };
}

const div = (a: number, b: number) => Math.trunc(a / b);
const mod = (a: number, b: number) => a - Math.trunc(a / b) * b;

function g2d(gy: number, gm: number, gd: number): number {
  let d =
    div((gy + div(gm - 8, 6) + 100100) * 1461, 4) +
    div(153 * mod(gm + 9, 12) + 2, 5) +
    gd -
    34840408;
  d = d - div(div(gy + 100100 + div(gm - 8, 6), 100) * 3, 4) + 752;
  return d;
}

function d2g(jdn: number): { gy: number; gm: number; gd: number } {
  let j = 4 * jdn + 139361631;
  j = j + div(div(4 * jdn + 183187720, 146097) * 3, 4) * 4 - 3908;
  const i = div(mod(j, 1461), 4) * 5 + 308;
  const gd = div(mod(i, 153), 5) + 1;
  const gm = mod(div(i, 153), 12) + 1;
  const gy = div(j, 1461) - 100100 + div(8 - gm, 6);
  return { gy, gm, gd };
}

export function isLeapJalaliYear(jy: number): boolean {
  return jalCal(jy).leap === 0;
}

export function jalaliMonthLength(jy: number, jm: number): number {
  if (jm <= 6) return 31;
  if (jm <= 11) return 30;
  return isLeapJalaliYear(jy) ? 30 : 29;
}

export function gregorianToJalali(gy: number, gm: number, gd: number): JalaliDate {
  let jy = gy - 621;
  const r = jalCal(jy);
  const jdn1f = g2d(gy, 3, r.march);
  const jdn = g2d(gy, gm, gd);
  let k = jdn - jdn1f;

  if (k >= 0) {
    if (k <= 185) return { jy, jm: 1 + div(k, 31), jd: mod(k, 31) + 1 };
    k -= 186;
  } else {
    jy -= 1;
    k += 179;
    if (r.leap === 1) k += 1;
  }
  return { jy, jm: 7 + div(k, 30), jd: mod(k, 30) + 1 };
}

export function jalaliToGregorian(jy: number, jm: number, jd: number): { gy: number; gm: number; gd: number } {
  const r = jalCal(jy);
  return d2g(g2d(r.gy, 3, r.march) + (jm - 1) * 31 - div(jm, 7) * (jm - 7) + jd - 1);
}

export function isValidJalali(jy: number, jm: number, jd: number): boolean {
  if (jm < 1 || jm > 12 || jd < 1) return false;
  try {
    return jd <= jalaliMonthLength(jy, jm);
  } catch {
    return false;
  }
}

/** تبدیل Date به تاریخ جلالی (بر مبنای وقت محلی) */
export function dateToJalali(date: Date): JalaliDate {
  return gregorianToJalali(date.getFullYear(), date.getMonth() + 1, date.getDate());
}

export function jalaliToDate(j: JalaliDate): Date {
  const g = jalaliToGregorian(j.jy, j.jm, j.jd);
  return new Date(g.gy, g.gm - 1, g.gd);
}

export const JALALI_MONTHS = [
  'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
  'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
];

export const JALALI_WEEKDAYS = ['شنبه', 'یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه'];

const pad = (n: number) => String(n).padStart(2, '0');

/** قالب‌بندی: 'short' = ۱۴۰۵/۰۵/۰۷ ، 'long' = ۷ مرداد ۱۴۰۵ ، 'full' = سه‌شنبه ۷ مرداد ۱۴۰۵ */
export function formatJalali(
  date: Date | JalaliDate,
  style: 'short' | 'long' | 'full' = 'short',
  persianDigits = true,
): string {
  const j = date instanceof Date ? dateToJalali(date) : date;
  const fa = (s: string | number) =>
    persianDigits ? String(s).replace(/\d/g, (d) => '۰۱۲۳۴۵۶۷۸۹'[Number(d)]!) : String(s);

  if (style === 'short') return fa(`${j.jy}/${pad(j.jm)}/${pad(j.jd)}`);

  const body = `${fa(j.jd)} ${JALALI_MONTHS[j.jm - 1]} ${fa(j.jy)}`;
  if (style === 'long') return body;

  const d = date instanceof Date ? date : jalaliToDate(j);
  // شنبه ابتدای هفته است: getDay() 6=شنبه
  const weekday = JALALI_WEEKDAYS[(d.getDay() + 1) % 7];
  return `${weekday} ${body}`;
}

/** تجزیهٔ رشته‌هایی مثل ۱۴۰۵/۰۵/۰۷ یا 1405-5-7 */
export function parseJalali(input: string): JalaliDate | null {
  const latin = input
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06f0))
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660));
  const m = latin.match(/^\s*(\d{4})\s*[/\-.]\s*(\d{1,2})\s*[/\-.]\s*(\d{1,2})\s*$/);
  if (!m) return null;
  const jy = Number(m[1]), jm = Number(m[2]), jd = Number(m[3]);
  return isValidJalali(jy, jm, jd) ? { jy, jm, jd } : null;
}

/** بازهٔ سال مالی که تاریخ داده‌شده در آن قرار دارد */
export function fiscalYearRange(date: Date, startMonth = 1): { from: Date; to: Date; label: string } {
  const j = dateToJalali(date);
  const jy = j.jm >= startMonth ? j.jy : j.jy - 1;
  const from = jalaliToDate({ jy, jm: startMonth, jd: 1 });
  const endMonth = startMonth === 1 ? 12 : startMonth - 1;
  const endYear = startMonth === 1 ? jy : jy + 1;
  const to = jalaliToDate({ jy: endYear, jm: endMonth, jd: jalaliMonthLength(endYear, endMonth) });
  to.setHours(23, 59, 59, 999);
  const label = `سال مالی ${String(jy).replace(/\d/g, (d) => '۰۱۲۳۴۵۶۷۸۹'[Number(d)]!)}`;
  return { from, to, label };
}
