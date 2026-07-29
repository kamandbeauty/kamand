import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import {
  filterByPayment, globalSearch, groupHits, matchScore,
  normalizeSearchText, paymentSummary, SEARCH_KIND_LABELS,
  type InvoiceStatusInfo, type SearchInput,
} from '../dist/search.js';
import type { Cheque, Invoice, Party, Product } from '../dist/types.js';

const BIZ = 'b';
const NOW = '2026-07-29T00:00:00.000Z';

// ─────────── یکسان‌سازی فارسی ───────────

describe('یکسان‌سازی متن فارسی', () => {
  test('ی و ك عربی با فارسی یکی می‌شوند', () => {
    assert.equal(normalizeSearchText('علي'), normalizeSearchText('علی'));
    assert.equal(normalizeSearchText('كتاب'), normalizeSearchText('کتاب'));
  });

  test('ارقام فارسی و عربی با لاتین یکی می‌شوند', () => {
    assert.equal(normalizeSearchText('۱۲۳'), '123');
    assert.equal(normalizeSearchText('١٢٣'), '123');
  });

  test('انواع الف یکسان می‌شوند', () => {
    assert.equal(normalizeSearchText('أحمد'), normalizeSearchText('احمد'));
    assert.equal(normalizeSearchText('آبان'), normalizeSearchText('آبان'));
  });

  test('ه و ة یکی می‌شوند', () => {
    assert.equal(normalizeSearchText('فاطمة'), normalizeSearchText('فاطمه'));
  });

  test('نیم‌فاصله مثل فاصله رفتار می‌کند', () => {
    assert.equal(normalizeSearchText('می‌خواهم'), 'می خواهم');
  });

  test('اعراب حذف می‌شود', () => {
    assert.equal(normalizeSearchText('کِتاب'), 'کتاب');
  });

  test('فاصلهٔ اضافه فشرده می‌شود', () => {
    assert.equal(normalizeSearchText('  علی   رضا  '), 'علی رضا');
  });

  test('حروف بزرگ لاتین کوچک می‌شوند', () => {
    assert.equal(normalizeSearchText('ABC'), 'abc');
  });
});

describe('امتیازدهی تطابق', () => {
  test('تطابق کامل بالاترین امتیاز', () => {
    assert.equal(matchScore('علی', 'علی'), 100);
  });

  test('شروع با، امتیاز بالا', () => {
    assert.equal(matchScore('علی رضایی', 'علی'), 70);
  });

  test('ابتدای کلمه، امتیاز متوسط', () => {
    assert.equal(matchScore('آقای رضایی', 'رضایی'), 50);
  });

  test('شامل بودن، کمترین امتیاز', () => {
    assert.equal(matchScore('محمدرضا', 'مدر'), 30);
  });

  test('بی‌ربط صفر می‌دهد', () => {
    assert.equal(matchScore('علی', 'حسن'), 0);
  });

  test('مقدار خالی صفر می‌دهد', () => {
    assert.equal(matchScore(undefined, 'علی'), 0);
    assert.equal(matchScore('', 'علی'), 0);
  });

  test('تطابق با نگارش عربی هم کار می‌کند', () => {
    assert.ok(matchScore('علي رضايي', normalizeSearchText('علی')) > 0);
  });
});

// ─────────── جستجوی سراسری ───────────

function makeInput(): SearchInput {
  const parties: Party[] = [
    { id: 'p1', businessId: BIZ, kind: 'customer', name: 'آقای رضایی', phone: '09121234567', openingBalance: 0 },
    { id: 'p2', businessId: BIZ, kind: 'vendor', name: 'تأمین‌کنندهٔ پارس', openingBalance: 0 },
    { id: 'p3', businessId: BIZ, kind: 'customer', name: 'حذف‌شده', openingBalance: 0, archived: true },
  ];

  const products: Product[] = [
    { id: 'pr1', businessId: BIZ, kind: 'goods', name: 'پیراهن مردانه', barcode: '6260123456789',
      unitMain: 'عدد', buyPrice: 100_000, sellPrice: 300_000, openingQty: 0, openingCost: 0 },
    { id: 'pr2', businessId: BIZ, kind: 'goods', name: 'شلوار جین',
      unitMain: 'عدد', buyPrice: 200_000, sellPrice: 400_000, openingQty: 0, openingCost: 0 },
  ];

  const invoices: Invoice[] = [
    { id: 'i1', businessId: BIZ, type: 'sale', number: 'F-1001', partyId: 'p1',
      date: '2026-07-10', isOfficial: false, lines: [], discount: 0, shipping: 0,
      status: 'open', createdAt: NOW, updatedAt: NOW },
    { id: 'i2', businessId: BIZ, type: 'sale', number: 'F-1002', partyId: 'p2',
      date: '2026-07-15', isOfficial: false, lines: [], discount: 0, shipping: 0,
      status: 'open', createdAt: NOW, updatedAt: NOW, note: 'سفارش ویژه' },
    { id: 'i3', businessId: BIZ, type: 'sale', number: 'F-9999', partyId: 'p1',
      date: '2026-01-01', isOfficial: false, lines: [], discount: 0, shipping: 0,
      status: 'open', createdAt: NOW, updatedAt: NOW, deletedAt: NOW },
  ];

  const cheques: Cheque[] = [
    { id: 'c1', businessId: BIZ, direction: 'received', number: '412857', bankName: 'ملت',
      amount: 5_000_000, dueDate: '2026-08-01', partyId: 'p1', status: 'pending', createdAt: NOW },
  ];

  const byId = new Map(parties.map((p) => [p.id, p]));
  return {
    invoices, parties, products, cheques,
    invoiceTotal: () => 1_000_000,
    partyName: (id) => (id ? byId.get(id)?.name : undefined),
  };
}

describe('جستجوی سراسری', () => {
  const input = makeInput();

  test('جستجوی خیلی کوتاه نتیجه نمی‌دهد', () => {
    assert.equal(globalSearch(input, 'ا').length, 0);
    assert.equal(globalSearch(input, '').length, 0);
  });

  test('شماره فاکتور پیدا می‌شود', () => {
    const r = globalSearch(input, 'F-1001');
    assert.equal(r[0]?.kind, 'invoice');
    assert.equal(r[0]?.id, 'i1');
  });

  test('نام شخص پیدا می‌شود', () => {
    const r = globalSearch(input, 'رضایی');
    assert.ok(r.some((h) => h.kind === 'party' && h.id === 'p1'));
  });

  test('فاکتورهای یک شخص هم با نام او پیدا می‌شوند', () => {
    const r = globalSearch(input, 'رضایی');
    assert.ok(r.some((h) => h.kind === 'invoice' && h.id === 'i1'));
  });

  test('شمارهٔ تلفن پیدا می‌شود', () => {
    const r = globalSearch(input, '09121234567');
    assert.ok(r.some((h) => h.kind === 'party'));
  });

  test('تلفن با ارقام فارسی هم پیدا می‌شود', () => {
    const r = globalSearch(input, '۰۹۱۲۱۲۳۴۵۶۷');
    assert.ok(r.some((h) => h.kind === 'party'));
  });

  test('بارکد کالا پیدا می‌شود', () => {
    const r = globalSearch(input, '6260123456789');
    assert.equal(r[0]?.kind, 'product');
    assert.equal(r[0]?.id, 'pr1');
  });

  test('نام کالا پیدا می‌شود', () => {
    const r = globalSearch(input, 'پیراهن');
    assert.ok(r.some((h) => h.kind === 'product' && h.id === 'pr1'));
  });

  test('شمارهٔ چک پیدا می‌شود', () => {
    const r = globalSearch(input, '412857');
    assert.ok(r.some((h) => h.kind === 'cheque'));
  });

  test('نام بانک هم جستجو می‌شود', () => {
    assert.ok(globalSearch(input, 'ملت').some((h) => h.kind === 'cheque'));
  });

  test('توضیحات فاکتور جستجو می‌شود', () => {
    assert.ok(globalSearch(input, 'سفارش ویژه').some((h) => h.id === 'i2'));
  });

  test('فاکتور حذف‌شده نمی‌آید', () => {
    assert.ok(!globalSearch(input, 'F-9999').some((h) => h.id === 'i3'));
  });

  test('شخص بایگانی‌شده نمی‌آید', () => {
    assert.equal(globalSearch(input, 'حذف‌شده').filter((h) => h.kind === 'party').length, 0);
  });

  test('نتایج مرتبط‌تر اول می‌آیند', () => {
    const r = globalSearch(input, 'پیراهن مردانه');
    assert.equal(r[0]?.kind, 'product', 'تطابق کامل باید اول باشد');
  });

  test('هر نتیجه مقصد دارد', () => {
    for (const h of globalSearch(input, 'رضایی')) {
      assert.ok(h.page, `${h.kind} مقصد ندارد`);
      assert.ok(h.title);
    }
  });

  test('محدودیت تعداد رعایت می‌شود', () => {
    assert.ok(globalSearch(input, 'ا', 3).length <= 3);
    assert.ok(globalSearch(input, 'رضایی', 1).length <= 1);
  });

  test('گروه‌بندی نتایج به ترتیب ثابت', () => {
    const g = groupHits(globalSearch(input, 'رضایی'));
    const kinds = g.map((x) => x.kind);
    assert.ok(kinds.indexOf('invoice') <= Math.max(kinds.indexOf('party'), 0));
    for (const kind of kinds) assert.ok(SEARCH_KIND_LABELS[kind]);
  });

  test('جستجوی بی‌نتیجه آرایهٔ خالی می‌دهد', () => {
    assert.deepEqual(globalSearch(input, 'چیزی که وجود ندارد'), []);
  });
});

// ─────────── فیلتر پرداخت ───────────

describe('فیلتر وضعیت پرداخت', () => {
  const mk = (id: string, type: Invoice['type'] = 'sale'): Invoice => ({
    id, businessId: BIZ, type, number: id, partyId: 'p1', date: '2026-07-01',
    isOfficial: false, lines: [], discount: 0, shipping: 0, status: 'open',
    createdAt: NOW, updatedAt: NOW,
  });

  const invoices = [mk('unpaid'), mk('partial'), mk('paid'), mk('overdue'), mk('q', 'quote')];

  const info = (inv: Invoice): InvoiceStatusInfo => {
    switch (inv.id) {
      case 'unpaid': return { total: 100, paid: 0, remaining: 100, isOverdue: false };
      case 'partial': return { total: 100, paid: 40, remaining: 60, isOverdue: false };
      case 'paid': return { total: 100, paid: 100, remaining: 0, isOverdue: false };
      case 'overdue': return { total: 100, paid: 0, remaining: 100, isOverdue: true };
      default: return { total: 0, paid: 0, remaining: 0, isOverdue: false };
    }
  };

  test('همه، همه را برمی‌گرداند', () => {
    assert.equal(filterByPayment(invoices, 'all', info).length, 5);
  });

  test('تسویه‌نشده شامل جزئی هم هست', () => {
    const r = filterByPayment(invoices, 'unpaid', info).map((i) => i.id);
    assert.deepEqual(r.sort(), ['overdue', 'partial', 'unpaid']);
  });

  test('پرداخت جزئی فقط آن‌ها', () => {
    assert.deepEqual(filterByPayment(invoices, 'partial', info).map((i) => i.id), ['partial']);
  });

  test('تسویه‌شده فقط آن‌ها', () => {
    assert.deepEqual(filterByPayment(invoices, 'paid', info).map((i) => i.id), ['paid']);
  });

  test('سررسید گذشته فقط آن‌ها', () => {
    assert.deepEqual(filterByPayment(invoices, 'overdue', info).map((i) => i.id), ['overdue']);
  });

  test('پیش‌فاکتور در هیچ فیلتری نمی‌آید', () => {
    for (const f of ['unpaid', 'partial', 'paid', 'overdue'] as const) {
      assert.ok(!filterByPayment(invoices, f, info).some((i) => i.type === 'quote'));
    }
  });

  test('خلاصهٔ وضعیت پرداخت', () => {
    const s = paymentSummary(invoices, info);
    assert.equal(s.unpaidCount, 3);
    assert.equal(s.unpaidAmount, 260);
    assert.equal(s.overdueCount, 1);
    assert.equal(s.overdueAmount, 100);
  });

  test('فاکتور حذف‌شده در خلاصه نمی‌آید', () => {
    const withDeleted = [...invoices, { ...mk('gone'), deletedAt: NOW }];
    assert.equal(paymentSummary(withDeleted, info).unpaidCount, 3);
  });
});
