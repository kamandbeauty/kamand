import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import {
  dateToJalali, fiscalYearRange, formatJalali, gregorianToJalali,
  isLeapJalaliYear, jalaliMonthLength, jalaliToGregorian, parseJalali,
} from '../dist/jalali.js';

describe('تاریخ جلالی', () => {
  test('تبدیل میلادی به شمسی', () => {
    assert.deepEqual(gregorianToJalali(2024, 3, 20), { jy: 1403, jm: 1, jd: 1 });
    assert.deepEqual(gregorianToJalali(2026, 7, 29), { jy: 1405, jm: 5, jd: 7 });
    assert.deepEqual(gregorianToJalali(2000, 1, 1), { jy: 1378, jm: 10, jd: 11 });
  });

  test('تبدیل رفت و برگشت پایدار است', () => {
    for (let jy = 1395; jy <= 1410; jy++) {
      for (const jm of [1, 6, 7, 12]) {
        const jd = jalaliMonthLength(jy, jm);
        const g = jalaliToGregorian(jy, jm, jd);
        assert.deepEqual(gregorianToJalali(g.gy, g.gm, g.gd), { jy, jm, jd });
      }
    }
  });

  test('طول ماه‌ها', () => {
    assert.equal(jalaliMonthLength(1403, 1), 31);
    assert.equal(jalaliMonthLength(1403, 7), 30);
    assert.equal(jalaliMonthLength(1403, 12), 30); // کبیسه
    assert.equal(jalaliMonthLength(1404, 12), 29);
  });

  test('سال کبیسه', () => {
    assert.equal(isLeapJalaliYear(1403), true);
    assert.equal(isLeapJalaliYear(1404), false);
  });

  test('قالب‌بندی', () => {
    const d = new Date(2026, 6, 29);
    assert.equal(formatJalali(d, 'short', false), '1405/05/07');
    assert.equal(formatJalali(d, 'long', false), '7 مرداد 1405');
    assert.match(formatJalali(d, 'short', true), /^۱۴۰۵/);
  });

  test('تجزیهٔ تاریخ', () => {
    assert.deepEqual(parseJalali('1405/05/07'), { jy: 1405, jm: 5, jd: 7 });
    assert.deepEqual(parseJalali('۱۴۰۵/۰۵/۰۷'), { jy: 1405, jm: 5, jd: 7 });
    assert.deepEqual(parseJalali('1405-5-7'), { jy: 1405, jm: 5, jd: 7 });
    assert.equal(parseJalali('1405/13/01'), null);
    assert.equal(parseJalali('1404/12/30'), null); // غیرکبیسه
    assert.equal(parseJalali('نامعتبر'), null);
  });

  test('سال مالی', () => {
    const r = fiscalYearRange(new Date(2026, 6, 29), 1);
    assert.equal(dateToJalali(r.from).jy, 1405);
    assert.equal(dateToJalali(r.from).jm, 1);
    assert.equal(dateToJalali(r.to).jm, 12);
    assert.equal(r.label, 'سال مالی 1405');
  });
});
