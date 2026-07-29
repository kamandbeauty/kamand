import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import {
  buildReceipt, CMD, preparePersian, ReceiptBuilder, reverseForRTL, shapePersian,
} from '../dist/escpos.js';
import type { Business, Invoice, Party, Product } from '../dist/types.js';

describe('شکل‌دهی حروف فارسی', () => {
  test('حرف آغازین، میانی و پایانی درست انتخاب می‌شود', () => {
    const s = shapePersian('سلام');
    assert.equal(s.length, 4 - 1, 'لام+الف باید ترکیب شود');
    assert.equal(s[0], '\uFEB3', 'س باید شکل آغازین بگیرد');
  });

  test('حروف غیرچسبان به بعدی نمی‌چسبند', () => {
    // د به ر نمی‌چسبد، پس هر دو شکل منفرد/پایانی می‌گیرند
    const s = shapePersian('در');
    assert.equal(s[0], '\uFEA9', 'د باید شکل منفرد بگیرد');
    assert.equal(s[1], '\uFEAD', 'ر پس از حرف غیرچسبان باید منفرد بماند');
  });

  test('ترکیب لام-الف به یک نویسه تبدیل می‌شود', () => {
    assert.equal(shapePersian('لا').length, 1);
    assert.equal(shapePersian('کالا').length, 3);
  });

  test('حروف ویژهٔ فارسی پشتیبانی می‌شوند', () => {
    for (const ch of ['پ', 'چ', 'ژ', 'گ', 'ک', 'ی']) {
      const s = shapePersian(ch);
      assert.notEqual(s, ch, `${ch} باید به شکل نمایشی تبدیل شود`);
      assert.equal(s.length, 1);
    }
  });

  test('متن غیرعربی دست‌نخورده می‌ماند', () => {
    assert.equal(shapePersian('abc123'), 'abc123');
    assert.equal(shapePersian('۱۲۳'), '۱۲۳');
  });

  test('معکوس‌سازی راست‌به‌چپ قطعهٔ لاتین را حفظ می‌کند', () => {
    const r = reverseForRTL('abc تست');
    assert.ok(r.includes('abc'), 'ترتیب حروف لاتین نباید معکوس شود');
  });

  test('اعداد در معکوس‌سازی حفظ می‌شوند', () => {
    assert.ok(reverseForRTL('مبلغ 1500').includes('1500'));
  });

  test('آماده‌سازی کامل بدون خطا اجرا می‌شود', () => {
    for (const s of ['فروشگاه ونک', 'مبلغ کل: 1,500,000', 'الله', '']) {
      assert.equal(typeof preparePersian(s), 'string');
    }
  });
});

describe('سازندهٔ رسید', () => {
  test('با فرمان راه‌اندازی شروع می‌شود', () => {
    const b = new ReceiptBuilder().build();
    assert.equal(b[0], CMD.INIT[0]);
    assert.equal(b[1], CMD.INIT[1]);
  });

  test('سطر دوستونی عرض کاغذ را پر می‌کند', () => {
    const r = new ReceiptBuilder({ width: 32, shapeArabic: false });
    r.row('AB', 'CD');
    const line = r.preview().split('\n').find((l) => l.includes('AB'))!;
    assert.equal(line.length, 32);
  });

  test('خط جداکننده به عرض کاغذ است', () => {
    const r = new ReceiptBuilder({ width: 48, shapeArabic: false });
    r.divider();
    assert.ok(r.preview().includes('-'.repeat(48)));
  });

  test('برش و کشوی پول فرمان درست می‌فرستند', () => {
    const cut = new ReceiptBuilder().cut().build();
    assert.ok([...cut].join(',').includes(CMD.CUT.join(',')));

    const drawer = new ReceiptBuilder().openDrawer().build();
    assert.ok([...drawer].join(',').includes(CMD.DRAWER.join(',')));
  });

  test('خروجی بایت است', () => {
    assert.ok(new ReceiptBuilder().text('تست').build() instanceof Uint8Array);
  });
});

describe('رسید فروش', () => {
  const BIZ = 'b';
  const business: Business = {
    id: BIZ, name: 'فروشگاه ونک', address: 'تهران', phone: '02100000000',
    fiscalYearStartMonth: 1, costingMethod: 'fifo', defaultVatRate: 10,
    currencyUnit: 'toman', createdAt: '2026-01-01T00:00:00Z',
  };

  const party: Party = {
    id: 'p', businessId: BIZ, kind: 'customer', name: 'آقای رضایی', openingBalance: 0,
  };

  const products = new Map<string, Product>([['pr1', {
    id: 'pr1', businessId: BIZ, kind: 'goods', name: 'پیراهن',
    unitMain: 'عدد', buyPrice: 500_000, sellPrice: 900_000,
    openingQty: 0, openingCost: 0,
  }]]);

  const invoice: Invoice = {
    id: 'i', businessId: BIZ, type: 'sale', number: 'F-1001',
    partyId: 'p', date: '2026-07-29', isOfficial: false,
    lines: [{ id: 'l', productId: 'pr1', qty: 2, unit: 'عدد', unitPrice: 900_000, discount: 0, vatRate: 0 }],
    discount: 0, shipping: 0, status: 'open',
    createdAt: '2026-07-29T00:00:00Z', updatedAt: '2026-07-29T00:00:00Z',
  };

  test('رسید کامل ساخته می‌شود', () => {
    const bytes = buildReceipt({ invoice, business, party, products }).build();
    assert.ok(bytes.length > 100, 'رسید باید محتوا داشته باشد');
    assert.ok([...bytes].join(',').includes(CMD.CUT.join(',')), 'باید فرمان برش داشته باشد');
  });

  test('مبلغ و شماره در رسید می‌آید', () => {
    const preview = buildReceipt({
      invoice, business, party, products, options: { shapeArabic: false },
    }).preview();
    assert.ok(preview.includes('۱,۸۰۰,۰۰۰'), 'مبلغ کل باید درج شود');
    assert.ok(preview.includes('F-۱۰۰۱'), 'شمارهٔ فاکتور با ارقام فارسی درج می‌شود');
  });

  test('شمارهٔ مالیاتی در صورت وجود چاپ می‌شود', () => {
    const preview = buildReceipt({
      invoice, business, party, products,
      taxId: 'A1D2E3050B700000000014',
      options: { shapeArabic: false },
    }).preview();
    assert.ok(preview.includes('A1D2E3050B700000000014'));
  });

  test('مانده هنگام پرداخت جزئی نشان داده می‌شود', () => {
    const preview = buildReceipt({
      invoice, business, party, products, paid: 1_000_000,
      options: { shapeArabic: false },
    }).preview();
    assert.ok(preview.includes('۱,۰۰۰,۰۰۰'), 'مبلغ پرداختی');
    assert.ok(preview.includes('۸۰۰,۰۰۰'), 'مانده');
  });

  test('عرض ۵۸ و ۸۰ میلی‌متر هر دو کار می‌کنند', () => {
    for (const width of [32, 48] as const) {
      const bytes = buildReceipt({
        invoice, business, party, products, options: { width },
      }).build();
      assert.ok(bytes.length > 50);
    }
  });

  test('بدون خریدار هم رسید ساخته می‌شود', () => {
    const bytes = buildReceipt({ invoice, business, party: null, products }).build();
    assert.ok(bytes.length > 50);
  });
});
