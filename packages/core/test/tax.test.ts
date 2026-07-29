import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import {
  buildCorrection, buildElectronicInvoice, daysSinceEpoch, generateTaxId,
  INVOICE_PATTERNS, INVOICE_SUBJECTS, isValidMemoryId, MEMORY_ID_ALPHABET,
  nextSerial, parseTaxId, taxIdDate, TaxIdError, taxQuarter, TaxValidationError,
  validateForTaxSystem, validateTaxId, vatReport, verhoeffCheckDigit,
  verhoeffValidate, verifyTotals, type TaxProfile, type TaxSubmission,
} from '../dist/tax.js';
import type { Business, Invoice, Party, Product } from '../dist/types.js';

// ─────────── داربست ───────────

const BIZ = 'biz';
const NOW = '2026-07-29T00:00:00.000Z';

const profile: TaxProfile = {
  memoryId: 'A1D2E3',
  sellerTin: '411111111111',
  sellerType: 2,
  lastSerial: 0,
};

const business: Business = {
  id: BIZ, name: 'فروشگاه نمونه', fiscalYearStartMonth: 1,
  costingMethod: 'fifo', defaultVatRate: 10, currencyUnit: 'toman',
  createdAt: NOW,
};

const buyer: Party = {
  id: 'b1', businessId: BIZ, kind: 'customer', name: 'شرکت خریدار',
  economicCode: '411222333444', openingBalance: 0,
};

function makeProducts(taxCode: string | null = '2710000000001'): Map<string, Product> {
  return new Map([['p1', {
    id: 'p1', businessId: BIZ, kind: 'goods' as const, name: 'کالای الف',
    unitMain: 'عدد', buyPrice: 100_000, sellPrice: 200_000,
    openingQty: 0, openingCost: 0, taxCode: taxCode ?? undefined,
  }]]);
}

function makeInvoice(over: Partial<Invoice> = {}): Invoice {
  return {
    id: 'inv1', businessId: BIZ, type: 'sale', number: 'F-0001',
    partyId: 'b1', date: '2026-07-29', isOfficial: true,
    lines: [{ id: 'l1', productId: 'p1', qty: 3, unit: 'عدد', unitPrice: 200_000, discount: 0, vatRate: 10 }],
    discount: 0, shipping: 0, status: 'open',
    createdAt: NOW, updatedAt: NOW, ...over,
  };
}

// ─────────── الگوریتم Verhoeff ───────────

describe('الگوریتم Verhoeff', () => {
  test('بردارهای آزمون شناخته‌شده', () => {
    assert.equal(verhoeffCheckDigit('236'), 3);
    assert.equal(verhoeffCheckDigit('12345'), 1);
    assert.equal(verhoeffCheckDigit('142857'), 0);
    assert.equal(verhoeffCheckDigit('123456789012'), 0);
  });

  test('رقم کنترلی الحاق‌شده همیشه معتبر است', () => {
    for (const n of ['236', '12345', '142857', '0', '9', '99999999']) {
      assert.equal(verhoeffValidate(n + verhoeffCheckDigit(n)), true, `ناموفق برای ${n}`);
    }
  });

  test('خطای تک‌رقمی را می‌گیرد', () => {
    const valid = '236' + verhoeffCheckDigit('236');
    for (let pos = 0; pos < 3; pos++) {
      for (let d = 0; d <= 9; d++) {
        const orig = Number(valid[pos]);
        if (d === orig) continue;
        const broken = valid.slice(0, pos) + d + valid.slice(pos + 1);
        assert.equal(verhoeffValidate(broken), false, `خطای ${broken} گرفته نشد`);
      }
    }
  });

  test('جابه‌جایی ارقام مجاور را می‌گیرد', () => {
    const valid = '142857' + verhoeffCheckDigit('142857');
    for (let i = 0; i < valid.length - 1; i++) {
      if (valid[i] === valid[i + 1]) continue;
      const sw = valid.slice(0, i) + valid[i + 1] + valid[i] + valid.slice(i + 2);
      assert.equal(verhoeffValidate(sw), false, `جابه‌جایی ${sw} گرفته نشد`);
    }
  });
});

// ─────────── شناسهٔ حافظه ───────────

describe('شناسهٔ یکتای حافظهٔ مالیاتی', () => {
  test('کاراکترهای مبهم ممنوع‌اند', () => {
    for (const bad of ['I', 'J', 'L', 'Q', 'V', '0']) {
      assert.equal(MEMORY_ID_ALPHABET.includes(bad), false, `${bad} نباید مجاز باشد`);
    }
  });

  test('اعتبارسنجی طول و کاراکتر', () => {
    assert.equal(isValidMemoryId('A1D2E3'), true);
    assert.equal(isValidMemoryId('a1d2e3'), true, 'حروف کوچک هم پذیرفته شود');
    assert.equal(isValidMemoryId('A1D2E'), false, 'طول کمتر از ۶');
    assert.equal(isValidMemoryId('A1D2E33'), false, 'طول بیشتر از ۶');
    assert.equal(isValidMemoryId('A1D2E0'), false, 'رقم صفر ممنوع');
    assert.equal(isValidMemoryId('A1D2EI'), false, 'حرف I ممنوع');
  });
});

// ─────────── شمارهٔ منحصربه‌فرد مالیاتی ───────────

describe('شمارهٔ منحصربه‌فرد مالیاتی', () => {
  const date = new Date('2026-07-29T00:00:00Z');

  test('طول دقیقاً ۲۲ کاراکتر است', () => {
    for (const serial of [0, 1, 999, 1_000_000]) {
      assert.equal(generateTaxId('A1D2E3', date, serial).length, 22);
    }
  });

  test('ساختار چهار مؤلفه‌ای درست است', () => {
    const id = generateTaxId('A1D2E3', date, 255);
    const p = parseTaxId(id);
    assert.equal(p.memoryId, 'A1D2E3');
    assert.equal(p.serial, 255);
    assert.equal(p.daysSinceEpoch, daysSinceEpoch(date));
    assert.equal(id.slice(11, 21), '00000000FF', 'سریال باید Hex ده‌رقمی باشد');
  });

  test('تاریخ از شماره بازیابی می‌شود', () => {
    const id = generateTaxId('A1D2E3', date, 1);
    assert.equal(taxIdDate(id).toISOString().slice(0, 10), '2026-07-29');
  });

  test('اعتبارسنجی رقم کنترلی', () => {
    const id = generateTaxId('A1D2E3', date, 42);
    assert.equal(validateTaxId(id), true);

    // خراب کردن رقم کنترلی
    const badCheck = id.slice(0, 21) + ((Number(id[21]) + 1) % 10);
    assert.equal(validateTaxId(badCheck), false);

    // خراب کردن سریال
    const badBody = id.slice(0, 20) + (id[20] === 'A' ? 'B' : 'A') + id[21];
    assert.equal(validateTaxId(badBody), false);
  });

  test('شمارهٔ با طول نادرست رد می‌شود', () => {
    assert.equal(validateTaxId('A1D2E3'), false);
    assert.equal(validateTaxId(''), false);
  });

  test('سریال‌های متوالی شمارهٔ متفاوت می‌دهند', () => {
    const ids = new Set(Array.from({ length: 500 }, (_, i) => generateTaxId('A1D2E3', date, i)));
    assert.equal(ids.size, 500);
  });

  test('ورودی نامعتبر خطا می‌دهد', () => {
    assert.throws(() => generateTaxId('BAD', date, 1), TaxIdError);
    assert.throws(() => generateTaxId('A1D2E3', date, -1), TaxIdError);
    assert.throws(() => generateTaxId('A1D2E3', date, 1.5), TaxIdError);
  });
});

// ─────────── اعتبارسنجی پیش از ارسال ───────────

describe('اعتبارسنجی صورتحساب الکترونیکی', () => {
  test('فاکتور کامل خطایی ندارد', () => {
    const issues = validateForTaxSystem(makeInvoice(), buyer, makeProducts(), profile, 1);
    assert.deepEqual(issues, []);
  });

  test('نبود شناسهٔ کالا گرفته می‌شود', () => {
    const issues = validateForTaxSystem(makeInvoice(), buyer, makeProducts(null), profile, 1);
    assert.ok(issues.some((i) => i.includes('شناسهٔ کالا')));
  });

  test('نوع اول بدون خریدار رد می‌شود', () => {
    const issues = validateForTaxSystem(makeInvoice(), null, makeProducts(), profile, 1);
    assert.ok(issues.some((i) => i.includes('خریدار')));
  });

  test('نوع دوم بدون خریدار مجاز است', () => {
    const issues = validateForTaxSystem(makeInvoice(), null, makeProducts(), profile, 2);
    assert.deepEqual(issues, []);
  });

  test('خریدار بدون شمارهٔ اقتصادی گرفته می‌شود', () => {
    const noCode: Party = { ...buyer, economicCode: undefined, nationalId: undefined };
    const issues = validateForTaxSystem(makeInvoice(), noCode, makeProducts(), profile, 1);
    assert.ok(issues.some((i) => i.includes('شمارهٔ اقتصادی')));
  });

  test('شناسهٔ حافظهٔ نامعتبر گرفته می‌شود', () => {
    const bad: TaxProfile = { ...profile, memoryId: 'XX' };
    const issues = validateForTaxSystem(makeInvoice(), buyer, makeProducts(), bad, 1);
    assert.ok(issues.some((i) => i.includes('حافظهٔ مالیاتی')));
  });

  test('فاکتور خالی رد می‌شود', () => {
    const issues = validateForTaxSystem(makeInvoice({ lines: [] }), buyer, makeProducts(), profile, 1);
    assert.ok(issues.length > 0);
  });
});

// ─────────── ساخت صورتحساب ───────────

describe('ساخت صورتحساب الکترونیکی', () => {
  function build(over: Partial<Invoice> = {}) {
    return buildElectronicInvoice({
      invoice: makeInvoice(over), business, buyer,
      products: makeProducts(), profile, serial: 1,
    });
  }

  test('سربرگ و اقلام درست ساخته می‌شوند', () => {
    const doc = build();
    assert.equal(doc.header.taxid.length, 22);
    assert.equal(validateTaxId(doc.header.taxid), true);
    assert.equal(doc.header.ins, INVOICE_SUBJECTS.ORIGINAL);
    assert.equal(doc.header.inp, INVOICE_PATTERNS.SALE);
    assert.equal(doc.header.tins, profile.sellerTin);
    assert.equal(doc.header.bid, buyer.economicCode);
    assert.equal(doc.body.length, 1);
    assert.equal(doc.body[0]!.sstid, '2710000000001');
  });

  test('جمع‌ها با محاسبات فاکتور می‌خوانند', () => {
    const doc = build();
    // ۳ × ۲۰۰٬۰۰۰ = ۶۰۰٬۰۰۰ ، مالیات ۱۰٪ = ۶۰٬۰۰۰
    assert.equal(doc.header.tadis, 600_000);
    assert.equal(doc.header.tvam, 60_000);
    assert.equal(doc.header.tbill, 660_000);
    assert.deepEqual(verifyTotals(doc), []);
  });

  test('تخفیف در اقلام منعکس می‌شود', () => {
    const doc = build({
      lines: [{ id: 'l1', productId: 'p1', qty: 2, unit: 'عدد', unitPrice: 200_000, discount: 50_000, vatRate: 10 }],
    });
    assert.equal(doc.body[0]!.prdis, 400_000);
    assert.equal(doc.body[0]!.dis, 50_000);
    assert.equal(doc.body[0]!.adis, 350_000);
    assert.equal(doc.body[0]!.vam, 35_000);
    assert.deepEqual(verifyTotals(doc), []);
  });

  test('تخفیف کلی سرشکن‌شده هم درست منعکس می‌شود', () => {
    const products = new Map(makeProducts());
    products.set('p2', { ...products.get('p1')!, id: 'p2', name: 'کالای ب' });
    const doc = buildElectronicInvoice({
      invoice: makeInvoice({
        lines: [
          { id: 'l1', productId: 'p1', qty: 1, unit: 'عدد', unitPrice: 100, discount: 0, vatRate: 0 },
          { id: 'l2', productId: 'p2', qty: 1, unit: 'عدد', unitPrice: 100, discount: 0, vatRate: 0 },
          { id: 'l3', productId: 'p1', qty: 1, unit: 'عدد', unitPrice: 100, discount: 0, vatRate: 0 },
        ],
        discount: 100,
      }),
      business, buyer, products, profile, serial: 5,
    });
    const sumDis = doc.body.reduce((s, b) => s + b.dis, 0);
    assert.equal(sumDis, 100, 'کل تخفیف باید بین اقلام سرشکن شود');
    assert.deepEqual(verifyTotals(doc), []);
  });

  test('صورتحساب نامعتبر پرتاب می‌کند', () => {
    assert.throws(
      () => buildElectronicInvoice({
        invoice: makeInvoice(), business, buyer,
        products: makeProducts(null), profile, serial: 1,
      }),
      TaxValidationError,
    );
  });

  test('نسخهٔ دستورالعمل در خروجی درج می‌شود', () => {
    assert.ok(build().meta.specVersion);
  });
});

// ─────────── اصلاحیه و ابطالیه ───────────

describe('صورتحساب اصلاحی و ابطالی', () => {
  const accepted: TaxSubmission = {
    id: 's1', businessId: BIZ, invoiceId: 'inv1',
    taxId: generateTaxId('A1D2E3', new Date('2026-07-29T00:00:00Z'), 1),
    serial: 1, subject: INVOICE_SUBJECTS.ORIGINAL, pattern: INVOICE_PATTERNS.SALE,
    subjectType: 1, status: 'accepted', createdAt: NOW,
  };

  const args = {
    invoice: makeInvoice(), business, buyer,
    products: makeProducts(), profile, serial: 2,
  };

  test('اصلاحیه به صورتحساب اصلی ارجاع می‌دهد', () => {
    const doc = buildCorrection(accepted, INVOICE_SUBJECTS.CORRECTIVE, args);
    assert.equal(doc.header.ins, INVOICE_SUBJECTS.CORRECTIVE);
    assert.equal(doc.header.irtaxid, accepted.taxId);
    assert.notEqual(doc.header.taxid, accepted.taxId, 'شمارهٔ جدید باید متفاوت باشد');
  });

  test('ابطالیه ساخته می‌شود', () => {
    const doc = buildCorrection(accepted, INVOICE_SUBJECTS.CANCELLING, args);
    assert.equal(doc.header.ins, INVOICE_SUBJECTS.CANCELLING);
    assert.equal(doc.header.irtaxid, accepted.taxId);
  });

  test('صورتحساب پذیرفته‌نشده قابل اصلاح نیست', () => {
    const pending: TaxSubmission = { ...accepted, status: 'queued' };
    assert.throws(
      () => buildCorrection(pending, INVOICE_SUBJECTS.CORRECTIVE, args),
      TaxValidationError,
    );
  });
});

// ─────────── گزارش دوره ───────────

describe('گزارش مالیات بر ارزش افزوده', () => {
  const invoices: Invoice[] = [
    makeInvoice({ id: 'i1', type: 'sale', date: '2026-07-10' }),
    makeInvoice({
      id: 'i2', type: 'purchase', date: '2026-07-12',
      lines: [{ id: 'x', productId: 'p1', qty: 5, unit: 'عدد', unitPrice: 100_000, discount: 0, vatRate: 10 }],
    }),
    makeInvoice({ id: 'i3', type: 'sale', date: '2026-05-01' }),
    makeInvoice({ id: 'i4', type: 'sale', date: '2026-07-15', isOfficial: false }),
  ];

  test('فقط فاکتورهای رسمی داخل بازه لحاظ می‌شوند', () => {
    const r = vatReport(invoices, [], { from: '2026-07-01', to: '2026-07-31' });
    assert.equal(r.salesNet, 600_000);
    assert.equal(r.salesVat, 60_000);
    assert.equal(r.purchaseNet, 500_000);
    assert.equal(r.purchaseVat, 50_000);
  });

  test('مالیات قابل پرداخت = فروش منهای اعتبار خرید', () => {
    const r = vatReport(invoices, [], { from: '2026-07-01', to: '2026-07-31' });
    assert.equal(r.payable, 10_000);
  });

  test('برگشت از فروش مالیات را کم می‌کند', () => {
    const withReturn = [...invoices, makeInvoice({ id: 'i5', type: 'sale_return', date: '2026-07-20' })];
    const r = vatReport(withReturn, [], { from: '2026-07-01', to: '2026-07-31' });
    assert.equal(r.salesVat, 0);
  });

  test('شمارش ارسال‌نشده‌ها', () => {
    const subs: TaxSubmission[] = [{
      id: 's', businessId: BIZ, invoiceId: 'i1', taxId: 'x', serial: 1,
      subject: 1, pattern: 1, subjectType: 1, status: 'accepted', createdAt: NOW,
    }];
    const r = vatReport(invoices, subs, { from: '2026-07-01', to: '2026-07-31' });
    assert.equal(r.invoiceCount, 1);
    assert.equal(r.submittedCount, 1);
    assert.equal(r.pendingCount, 0);
  });
});

describe('فصل مالیاتی', () => {
  test('تشخیص فصل درست', () => {
    // ۷ مرداد ۱۴۰۵ → تابستان (فصل دوم)
    const q = taxQuarter(new Date(2026, 6, 29));
    assert.equal(q.quarter, 2);
    assert.match(q.label, /تابستان/);
  });

  test('بازهٔ فصل درست محاسبه می‌شود', () => {
    const q = taxQuarter(new Date(2026, 6, 29));
    assert.ok(q.from < q.to);
    assert.ok(q.from <= new Date(2026, 6, 29));
  });
});

describe('سریال', () => {
  test('سریال بعدی افزایشی است', () => {
    assert.equal(nextSerial({ ...profile, lastSerial: 41 }), 42);
  });
});
