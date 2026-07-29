import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import {
  comparePeriods, customerPerformance, monthlyTrend, monthRanges,
  productPerformance, salesSummary, staleProducts,
} from '../dist/analytics.js';
import type { Invoice, Party, Product } from '../dist/types.js';

const BIZ = 'b';
const NOW = '2026-07-29T00:00:00.000Z';

const products = new Map<string, Product>([
  ['p1', { id: 'p1', businessId: BIZ, kind: 'goods', name: 'پیراهن',
    unitMain: 'ع', buyPrice: 100_000, sellPrice: 300_000, openingQty: 0, openingCost: 0 }],
  ['p2', { id: 'p2', businessId: BIZ, kind: 'goods', name: 'شلوار',
    unitMain: 'ع', buyPrice: 200_000, sellPrice: 250_000, openingQty: 0, openingCost: 0 }],
]);

const parties = new Map<string, Party>([
  ['c1', { id: 'c1', businessId: BIZ, kind: 'customer', name: 'مشتری الف', openingBalance: 0 }],
  ['c2', { id: 'c2', businessId: BIZ, kind: 'customer', name: 'مشتری ب', openingBalance: 0 }],
]);

let n = 0;
function inv(over: Partial<Invoice> = {}): Invoice {
  return {
    id: `i${++n}`, businessId: BIZ, type: 'sale', number: `F-${n}`,
    partyId: 'c1', date: '2026-07-10', isOfficial: false,
    lines: [], discount: 0, shipping: 0, status: 'open',
    createdAt: NOW, updatedAt: NOW, ...over,
  };
}

const line = (productId: string, qty: number, price: number, cogs: number) => ({
  id: `l${++n}`, productId, qty, unit: 'ع', unitPrice: price, discount: 0, vatRate: 0, cogs,
});

// ─────────── کالا ───────────

describe('عملکرد کالا', () => {
  test('سود و حاشیهٔ هر کالا محاسبه می‌شود', () => {
    const list = [
      inv({ lines: [line('p1', 2, 300_000, 200_000)] }),   // سود ۴۰۰٬۰۰۰
      inv({ lines: [line('p2', 1, 250_000, 200_000)] }),   // سود ۵۰٬۰۰۰
    ];
    const r = productPerformance(list, products);

    assert.equal(r.length, 2);
    assert.equal(r[0]?.name, 'پیراهن', 'پرسودترین باید اول باشد');
    assert.equal(r[0]?.revenue, 600_000);
    assert.equal(r[0]?.cogs, 200_000);
    assert.equal(r[0]?.profit, 400_000);
    assert.equal(r[0]?.margin, 66.7);
    assert.equal(r[1]?.profit, 50_000);
  });

  test('برگشت از فروش سود را کم می‌کند', () => {
    const list = [
      inv({ lines: [line('p1', 3, 300_000, 300_000)] }),
      inv({ type: 'sale_return', lines: [line('p1', 1, 300_000, 100_000)] }),
    ];
    const r = productPerformance(list, products);

    assert.equal(r[0]?.qty, 2, 'مقدار خالص پس از برگشت');
    assert.equal(r[0]?.revenue, 600_000);
    assert.equal(r[0]?.profit, 400_000);
  });

  test('پیش‌فاکتور در محاسبه نمی‌آید', () => {
    const list = [
      inv({ type: 'quote', lines: [line('p1', 10, 300_000, 100_000)] }),
      inv({ lines: [line('p1', 1, 300_000, 100_000)] }),
    ];
    assert.equal(productPerformance(list, products)[0]?.qty, 1);
  });

  test('فاکتور حذف‌شده نادیده گرفته می‌شود', () => {
    const list = [
      inv({ lines: [line('p1', 5, 300_000, 100_000)], deletedAt: NOW }),
      inv({ lines: [line('p1', 1, 300_000, 100_000)] }),
    ];
    assert.equal(productPerformance(list, products)[0]?.qty, 1);
  });

  test('فیلتر بازهٔ زمانی', () => {
    const list = [
      inv({ date: '2026-01-01', lines: [line('p1', 5, 300_000, 100_000)] }),
      inv({ date: '2026-07-10', lines: [line('p1', 2, 300_000, 100_000)] }),
    ];
    const r = productPerformance(list, products, { from: '2026-06-01', to: '2026-08-01' });
    assert.equal(r[0]?.qty, 2);
  });

  test('کالای حذف‌شده نام جایگزین می‌گیرد', () => {
    const list = [inv({ lines: [line('ghost', 1, 100_000, 50_000)] })];
    assert.equal(productPerformance(list, products)[0]?.name, 'کالای حذف‌شده');
  });

  test('تعداد فاکتورهای هر کالا شمرده می‌شود', () => {
    const list = [
      inv({ lines: [line('p1', 1, 300_000, 100_000)] }),
      inv({ lines: [line('p1', 1, 300_000, 100_000)] }),
    ];
    assert.equal(productPerformance(list, products)[0]?.invoiceCount, 2);
  });

  test('فروش بدون سود حاشیهٔ صفر می‌دهد', () => {
    const list = [inv({ lines: [line('p1', 1, 100_000, 100_000)] })];
    assert.equal(productPerformance(list, products)[0]?.margin, 0);
  });
});

// ─────────── مشتری ───────────

describe('عملکرد مشتری', () => {
  test('درآمد و سود هر مشتری', () => {
    const list = [
      inv({ partyId: 'c1', lines: [line('p1', 2, 300_000, 200_000)] }),
      inv({ partyId: 'c2', lines: [line('p2', 1, 250_000, 200_000)] }),
    ];
    const r = customerPerformance(list, parties);

    assert.equal(r[0]?.name, 'مشتری الف', 'پرفروش‌ترین اول');
    assert.equal(r[0]?.revenue, 600_000);
    assert.equal(r[0]?.profit, 400_000);
    assert.equal(r[1]?.revenue, 250_000);
  });

  test('میانگین فاکتور محاسبه می‌شود', () => {
    const list = [
      inv({ partyId: 'c1', lines: [line('p1', 1, 300_000, 100_000)] }),
      inv({ partyId: 'c1', lines: [line('p1', 1, 100_000, 50_000)] }),
    ];
    const r = customerPerformance(list, parties);
    assert.equal(r[0]?.invoiceCount, 2);
    assert.equal(r[0]?.averageInvoice, 200_000);
  });

  test('آخرین خرید ثبت می‌شود', () => {
    const list = [
      inv({ partyId: 'c1', date: '2026-01-01', lines: [line('p1', 1, 100_000, 50_000)] }),
      inv({ partyId: 'c1', date: '2026-07-10', lines: [line('p1', 1, 100_000, 50_000)] }),
    ];
    assert.equal(customerPerformance(list, parties)[0]?.lastPurchase, '2026-07-10');
  });

  test('فاکتور بدون طرف حساب نادیده گرفته می‌شود', () => {
    const list = [inv({ partyId: null, lines: [line('p1', 1, 300_000, 100_000)] })];
    assert.equal(customerPerformance(list, parties).length, 0);
  });

  test('برگشت، درآمد مشتری را کم می‌کند', () => {
    const list = [
      inv({ partyId: 'c1', lines: [line('p1', 2, 300_000, 200_000)] }),
      inv({ partyId: 'c1', type: 'sale_return', lines: [line('p1', 1, 300_000, 100_000)] }),
    ];
    const r = customerPerformance(list, parties);
    assert.equal(r[0]?.revenue, 300_000);
    assert.equal(r[0]?.invoiceCount, 1, 'برگشت در شمارش فاکتور نمی‌آید');
  });
});

// ─────────── روند ───────────

describe('روند ماهانه', () => {
  test('تعداد ماه‌های خواسته‌شده برمی‌گردد', () => {
    assert.equal(monthlyTrend([], {}, 6).length, 6);
    assert.equal(monthlyTrend([], {}, 12).length, 12);
  });

  test('ماه‌ها به ترتیب صعودی‌اند', () => {
    const t = monthlyTrend([], {}, 3);
    const key = (p: { jy: number; jm: number }) => p.jy * 12 + p.jm;
    assert.ok(key(t[0]!) < key(t[1]!));
    assert.ok(key(t[1]!) < key(t[2]!));
  });

  test('برچسب ماه فارسی است', () => {
    const t = monthlyTrend([], {}, 1);
    assert.match(t[0]!.label, /[\u0600-\u06FF]/);
    assert.match(t[0]!.label, /[۰-۹]/);
  });

  test('ماه بدون فروش صفر می‌ماند', () => {
    const t = monthlyTrend([], {}, 3);
    assert.ok(t.every((p) => p.revenue === 0 && p.profit === 0));
  });
});

describe('مقایسهٔ دوره', () => {
  test('رشد درآمد درصدی محاسبه می‌شود', () => {
    const list = [
      inv({ date: '2026-06-15', lines: [line('p1', 1, 100_000, 50_000)] }),
      inv({ date: '2026-07-15', lines: [line('p1', 1, 150_000, 50_000)] }),
    ];
    const c = comparePeriods(
      list,
      { from: '2026-07-01', to: '2026-07-31' },
      { from: '2026-06-01', to: '2026-06-30' },
    );
    assert.equal(c.current.revenue, 150_000);
    assert.equal(c.previous.revenue, 100_000);
    assert.equal(c.revenueChange, 50);
  });

  test('افت با درصد منفی نشان داده می‌شود', () => {
    const list = [
      inv({ date: '2026-06-15', lines: [line('p1', 1, 200_000, 50_000)] }),
      inv({ date: '2026-07-15', lines: [line('p1', 1, 100_000, 50_000)] }),
    ];
    const c = comparePeriods(
      list,
      { from: '2026-07-01', to: '2026-07-31' },
      { from: '2026-06-01', to: '2026-06-30' },
    );
    assert.equal(c.revenueChange, -50);
  });

  test('دورهٔ قبل خالی، تقسیم بر صفر نمی‌دهد', () => {
    const list = [inv({ date: '2026-07-15', lines: [line('p1', 1, 100_000, 50_000)] })];
    const c = comparePeriods(
      list,
      { from: '2026-07-01', to: '2026-07-31' },
      { from: '2026-06-01', to: '2026-06-30' },
    );
    assert.equal(c.revenueChange, 100);
    assert.ok(Number.isFinite(c.profitChange));
  });

  test('هر دو دوره خالی، صفر می‌دهد', () => {
    const c = comparePeriods([], { from: '2026-07-01' }, { from: '2026-06-01' });
    assert.equal(c.revenueChange, 0);
  });

  test('بازهٔ ماه جاری و قبل ساخته می‌شود', () => {
    const r = monthRanges(new Date(2026, 6, 29));
    assert.ok(r.current.from! < r.current.to!);
    assert.ok(r.previous.to! < r.current.from!);
  });
});

// ─────────── کالای راکد ───────────

describe('کالاهای راکد', () => {
  const list = [
    { id: 'p1', businessId: BIZ, kind: 'goods' as const, name: 'پیراهن',
      unitMain: 'ع', buyPrice: 100_000, sellPrice: 300_000, openingQty: 0, openingCost: 0 },
    { id: 'p2', businessId: BIZ, kind: 'goods' as const, name: 'شلوار',
      unitMain: 'ع', buyPrice: 200_000, sellPrice: 250_000, openingQty: 0, openingCost: 0 },
  ];
  const stock = new Map([
    ['p1', { qty: 10, value: 1_000_000 }],
    ['p2', { qty: 5, value: 1_000_000 }],
  ]);
  const today = new Date('2026-07-29');

  test('کالای فروش‌نرفته راکد است', () => {
    const r = staleProducts([], list, stock, { today });
    assert.equal(r.length, 2);
    assert.equal(r[0]?.daysSinceSold, null);
  });

  test('کالای اخیراً فروش‌رفته راکد نیست', () => {
    const recent = [inv({ date: '2026-07-20', lines: [line('p1', 1, 300_000, 100_000)] })];
    const r = staleProducts(recent, list, stock, { today });
    assert.equal(r.length, 1);
    assert.equal(r[0]?.productId, 'p2');
  });

  test('کالای قدیمی‌فروش راکد شمرده می‌شود', () => {
    const old = [inv({ date: '2026-01-01', lines: [line('p1', 1, 300_000, 100_000)] })];
    const r = staleProducts(old, list, stock, { today });
    assert.equal(r.length, 2);
    const p1 = r.find((x) => x.productId === 'p1');
    assert.ok((p1?.daysSinceSold ?? 0) > 60);
  });

  test('کالای بدون موجودی راکد نیست', () => {
    const empty = new Map([['p1', { qty: 0, value: 0 }]]);
    assert.equal(staleProducts([], list, empty, { today }).length, 0);
  });

  test('مرتب‌سازی بر اساس ارزش خوابیده', () => {
    const s2 = new Map([
      ['p1', { qty: 1, value: 100_000 }],
      ['p2', { qty: 1, value: 900_000 }],
    ]);
    assert.equal(staleProducts([], list, s2, { today })[0]?.productId, 'p2');
  });

  test('آستانهٔ روز قابل تنظیم است', () => {
    const recent = [inv({ date: '2026-07-20', lines: [line('p1', 1, 300_000, 100_000)] })];
    assert.equal(staleProducts(recent, list, stock, { today, minDays: 5 }).length, 2);
  });
});

// ─────────── خلاصه ───────────

describe('خلاصهٔ فروش', () => {
  test('پرسودترین کالا و پرفروش‌ترین مشتری', () => {
    const list = [
      inv({ partyId: 'c1', lines: [line('p1', 2, 300_000, 200_000)] }),
      inv({ partyId: 'c2', lines: [line('p2', 1, 250_000, 200_000)] }),
    ];
    const s = salesSummary(list, products, parties);

    assert.equal(s.revenue, 850_000);
    assert.equal(s.profit, 450_000);
    assert.equal(s.invoiceCount, 2);
    assert.equal(s.averageInvoice, 425_000);
    assert.equal(s.topProduct?.name, 'پیراهن');
    assert.equal(s.topCustomer?.name, 'مشتری الف');
  });

  test('بدون فروش، خلاصه خالی و امن است', () => {
    const s = salesSummary([], products, parties);
    assert.equal(s.revenue, 0);
    assert.equal(s.margin, 0);
    assert.equal(s.averageInvoice, 0);
    assert.equal(s.topProduct, undefined);
  });
});
