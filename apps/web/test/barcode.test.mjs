/** آزمون منطق بارکد */
import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

const mod = new URL('../test-out/barcode.js', import.meta.url).href;

describe('بارکد', async () => {
  const b = await import(mod);

  test('رقم کنترلی EAN-13 درست محاسبه می‌شود', () => {
    // نمونه‌های شناخته‌شده
    assert.equal(b.eanCheckDigit('590123412345'), 7);
    assert.equal(b.eanCheckDigit('978030640615'), 7);
  });

  test('اعتبارسنجی بارکد', () => {
    assert.equal(b.isValidEAN('5901234123457'), true);
    assert.equal(b.isValidEAN('9780306406157'), true);
    assert.equal(b.isValidEAN('5901234123456'), false, 'رقم کنترلی غلط');
    assert.equal(b.isValidEAN('123'), false, 'طول نامعتبر');
    assert.equal(b.isValidEAN(''), false);
  });

  test('بارکد داخلی تولیدشده معتبر است', () => {
    for (const n of [1, 42, 999, 123456]) {
      const code = b.generateInternalBarcode(n);
      assert.equal(code.length, 13, `طول بارکد ${code}`);
      assert.equal(b.isValidEAN(code), true, `بارکد ${code} باید معتبر باشد`);
      assert.ok(code.startsWith('200'), 'پیشوند داخلی');
    }
  });

  test('بارکدهای داخلی یکتا هستند', () => {
    const set = new Set(Array.from({ length: 1000 }, (_, i) => b.generateInternalBarcode(i)));
    assert.equal(set.size, 1000);
  });

  test('در محیط بدون دوربین پشتیبانی گزارش نمی‌شود', () => {
    assert.equal(b.cameraScanSupported(), false);
  });
});
