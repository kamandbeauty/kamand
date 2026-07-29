import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import {
  allocate, bankersRound, formatMoney, moneyToWords, mulMoney,
  percentOf, rial, toLatinDigits, toPersianDigits, toman,
} from '../dist/money.js';

describe('پول', () => {
  test('ریال همیشه صحیح است', () => {
    assert.equal(rial(1000.4), 1000);
    assert.equal(rial(1000.6), 1001);
    assert.equal(toman(1500), 15000);
  });

  test('مبلغ نامعتبر رد می‌شود', () => {
    assert.throws(() => rial(NaN));
    assert.throws(() => rial(Infinity));
  });

  test('گرد کردن بانکی سوگیری ندارد', () => {
    assert.equal(bankersRound(0.5), 0);
    assert.equal(bankersRound(1.5), 2);
    assert.equal(bankersRound(2.5), 2);
    assert.equal(bankersRound(3.5), 4);
    assert.equal(bankersRound(-1.4), -1);
  });

  test('ضرب در مقدار اعشاری', () => {
    assert.equal(mulMoney(1000, 2.5), 2500);
    assert.equal(mulMoney(333, 3), 999);
  });

  test('درصد گرفتن', () => {
    assert.equal(percentOf(100000, 9), 9000);
    assert.equal(percentOf(0, 9), 0);
  });

  test('سرشکن کردن هیچ ریالی گم نمی‌کند', () => {
    for (const amount of [100, 1000, 999, 10_000_001, 7]) {
      for (const ratios of [[1, 1, 1], [1, 2, 3], [5, 5], [1, 1, 1, 1, 1, 1, 1]]) {
        const parts = allocate(amount, ratios);
        assert.equal(parts.reduce((a, b) => a + b, 0), amount,
          `جمع سهم‌ها باید ${amount} باشد`);
      }
    }
  });

  test('سرشکن کردن ۱۰۰ بین ۳ سهم', () => {
    assert.deepEqual(allocate(100, [1, 1, 1]), [34, 33, 33]);
  });

  test('مبلغ به حروف', () => {
    assert.equal(moneyToWords(0), 'صفر ریال');
    assert.equal(moneyToWords(1), 'یک ریال');
    assert.equal(moneyToWords(15), 'پانزده ریال');
    assert.equal(moneyToWords(21), 'بیست و یک ریال');
    assert.equal(moneyToWords(100), 'صد ریال');
    assert.equal(moneyToWords(1000), 'یک هزار ریال');
    assert.equal(moneyToWords(1_250_000), 'یک میلیون و دویست و پنجاه هزار ریال');
    assert.match(moneyToWords(-500), /^منفی/);
  });

  test('ارقام فارسی', () => {
    assert.equal(toPersianDigits('1405'), '۱۴۰۵');
    assert.equal(toLatinDigits('۱۴۰۵'), '1405');
    assert.equal(formatMoney(1234567, { persian: false }), '1,234,567');
    assert.equal(formatMoney(1000, { persian: true }), '۱,۰۰۰');
  });
});
