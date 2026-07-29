import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { AccountIndex, createChartOfAccounts, SYSTEM_ACCOUNTS as A } from '../dist/accounts.js';
import {
  assertBalanced, balanceOf, EntryBuilder, sumCredit, sumDebit, treasuryBalance,
  UnbalancedEntryError,
} from '../dist/ledger.js';
import { computeInvoice, invoiceProfit, nextInvoiceNumber, validateInvoice } from '../dist/invoice.js';
import { consumeStock, replayProduct } from '../dist/inventory.js';
import { defaultTreasuryAccount, postInvoice, postTransaction, postOpening } from '../dist/posting.js';
import { balanceSheet, incomeStatement, trialBalance, debtorsAndCreditors } from '../dist/reports.js';
import type { Invoice, JournalEntry, Party, StockMovement, Transaction, Treasury } from '../dist/types.js';

// ─────────── داربست آزمون ───────────
let seq = 0;
const idGen = () => `id-${String(++seq).padStart(4, '0')}`;
const BIZ = 'biz-1';
const NOW = '2026-07-29T10:00:00.000Z';

function setup() {
  seq = 0;
  const accounts = createChartOfAccounts(BIZ, idGen);
  const index = new AccountIndex(accounts);
  const ctx = { index, businessId: BIZ, idGen, now: NOW, treasuryAccount: defaultTreasuryAccount(index) };
  return { index, ctx };
}

const cashBox: Treasury = {
  id: 'tr-cash', businessId: BIZ, kind: 'cash', name: 'صندوق', openingBalance: 0,
};

function makeInvoice(over: Partial<Invoice> = {}): Invoice {
  return {
    id: 'inv-1', businessId: BIZ, type: 'sale', number: 'F-0001',
    partyId: 'party-1', date: '2026-07-29', isOfficial: false,
    lines: [{ id: 'l1', productId: 'p1', qty: 2, unit: 'عدد', unitPrice: 500_000, discount: 0, vatRate: 10 }],
    discount: 0, shipping: 0, status: 'open',
    createdAt: NOW, updatedAt: NOW, ...over,
  };
}

// ─────────── دفتر ───────────

describe('موتور سند دوطرفه', () => {
  test('سند نامتوازن رد می‌شود', () => {
    const { index } = setup();
    const b = new EntryBuilder(BIZ, '2026-07-29', 'تست', 'manual');
    b.debit(index.id(A.CASH), 1000);
    b.credit(index.id(A.SALES), 900);
    assert.throws(() => b.build('e1', NOW), UnbalancedEntryError);
  });

  test('سند متوازن پذیرفته می‌شود', () => {
    const { index } = setup();
    const b = new EntryBuilder(BIZ, '2026-07-29', 'تست', 'manual');
    b.debit(index.id(A.CASH), 1000);
    b.credit(index.id(A.SALES), 1000);
    const e = b.build('e1', NOW);
    assert.equal(sumDebit(e.lines), sumCredit(e.lines));
  });

  test('مبلغ منفی به سمت مقابل منتقل می‌شود', () => {
    const { index } = setup();
    const b = new EntryBuilder(BIZ, '2026-07-29', 'تست', 'manual');
    b.debit(index.id(A.CASH), -500);
    b.debit(index.id(A.SALES), 500);
    const e = b.build('e1', NOW);
    assert.equal(e.lines[0]!.credit, 500);
    assertBalanced(e.lines);
  });

  test('ردیف با مبلغ صفر نادیده گرفته می‌شود', () => {
    const { index } = setup();
    const b = new EntryBuilder(BIZ, '2026-07-29', 'تست', 'manual');
    b.debit(index.id(A.CASH), 0);
    assert.equal(b.isEmpty(), true);
  });
});

// ─────────── فاکتور ───────────

describe('محاسبات فاکتور', () => {
  test('جمع ساده با مالیات', () => {
    const t = computeInvoice(makeInvoice());
    assert.equal(t.subtotal, 1_000_000);
    assert.equal(t.net, 1_000_000);
    assert.equal(t.vat, 100_000);
    assert.equal(t.grandTotal, 1_100_000);
  });

  test('تخفیف سطری', () => {
    const t = computeInvoice(makeInvoice({
      lines: [{ id: 'l1', productId: 'p1', qty: 2, unit: 'عدد', unitPrice: 500_000, discount: 100_000, vatRate: 10 }],
    }));
    assert.equal(t.net, 900_000);
    assert.equal(t.vat, 90_000);
  });

  test('تخفیف کلی بین سطرها سرشکن می‌شود و ریالی گم نمی‌شود', () => {
    const t = computeInvoice(makeInvoice({
      lines: [
        { id: 'l1', productId: 'p1', qty: 1, unit: 'ع', unitPrice: 100, discount: 0, vatRate: 0 },
        { id: 'l2', productId: 'p2', qty: 1, unit: 'ع', unitPrice: 100, discount: 0, vatRate: 0 },
        { id: 'l3', productId: 'p3', qty: 1, unit: 'ع', unitPrice: 100, discount: 0, vatRate: 0 },
      ],
      discount: 100,
    }));
    const allocated = t.lines.reduce((s, l) => s + l.allocatedDiscount, 0);
    assert.equal(allocated, 100, 'کل تخفیف باید سرشکن شود');
    assert.equal(t.net, 200);
  });

  test('تخفیف بیش از مبلغ فاکتور محدود می‌شود', () => {
    const t = computeInvoice(makeInvoice({ discount: 99_999_999 }));
    assert.equal(t.net, 0);
    assert.equal(t.invoiceDiscount, 1_000_000);
  });

  test('هزینهٔ حمل مشمول مالیات نیست', () => {
    const t = computeInvoice(makeInvoice({ shipping: 50_000 }));
    assert.equal(t.vat, 100_000);
    assert.equal(t.grandTotal, 1_150_000);
  });

  test('سود فاکتور', () => {
    const inv = makeInvoice({
      lines: [{ id: 'l1', productId: 'p1', qty: 2, unit: 'ع', unitPrice: 500_000, discount: 0, vatRate: 0, cogs: 600_000 }],
    });
    assert.equal(invoiceProfit(inv), 400_000);
  });

  test('اعتبارسنجی خطاها را می‌گیرد', () => {
    assert.ok(validateInvoice(makeInvoice({ lines: [] })).length > 0);
    assert.ok(validateInvoice(makeInvoice({
      lines: [{ id: 'l1', productId: 'p1', qty: -1, unit: 'ع', unitPrice: 100, discount: 0, vatRate: 0 }],
    })).some((e) => e.includes('مقدار')));
    assert.ok(validateInvoice(makeInvoice({ partyId: null })).some((e) => e.includes('طرف حساب')));
    assert.equal(validateInvoice(makeInvoice()).length, 0);
  });

  test('شمارهٔ بعدی فاکتور', () => {
    assert.equal(nextInvoiceNumber([], 'F'), 'F-0001');
    assert.equal(nextInvoiceNumber(['F-0001', 'F-0009'], 'F'), 'F-0010');
    assert.equal(nextInvoiceNumber(['X-0100'], 'F'), 'F-0001');
  });
});

// ─────────── انبار ───────────

describe('موتور موجودی و بهای تمام‌شده', () => {
  const layers = [
    { qty: 10, unitCost: 1000, date: '2026-01-01' },
    { qty: 10, unitCost: 2000, date: '2026-02-01' },
  ];

  test('فایفو از قدیمی‌ترین لایه مصرف می‌کند', () => {
    const r = consumeStock(layers, 15, 'fifo');
    assert.equal(r.cogs, 10 * 1000 + 5 * 2000);
    assert.equal(r.remaining.reduce((s, l) => s + l.qty, 0), 5);
  });

  test('لایفو از جدیدترین لایه مصرف می‌کند', () => {
    const r = consumeStock(layers, 15, 'lifo');
    assert.equal(r.cogs, 10 * 2000 + 5 * 1000);
  });

  test('میانگین موزون', () => {
    const r = consumeStock(layers, 15, 'weighted_average');
    assert.equal(r.cogs, 15 * 1500);
  });

  test('کمبود موجودی خطا می‌دهد مگر مجاز باشد', () => {
    assert.throws(() => consumeStock(layers, 25, 'fifo'), /موجودی کافی نیست/);
    const r = consumeStock(layers, 25, 'fifo', { allowNegative: true });
    assert.ok(r.cogs > 0);
  });

  test('بازپخش حرکات انبار', () => {
    const ms: StockMovement[] = [
      { id: 'm1', businessId: BIZ, productId: 'p1', qty: 10, unitCost: 1000, date: '2026-01-01', sourceType: 'opening' },
      { id: 'm2', businessId: BIZ, productId: 'p1', qty: 10, unitCost: 2000, date: '2026-02-01', sourceType: 'invoice' },
      { id: 'm3', businessId: BIZ, productId: 'p1', qty: -12, unitCost: 0, date: '2026-03-01', sourceType: 'invoice' },
    ];
    const s = replayProduct(ms, 'fifo');
    assert.equal(s.qty, 8);
    assert.equal(s.value, 8 * 2000);
  });
});

// ─────────── ثبت و گزارش ───────────

describe('ثبت فاکتور در دفتر', () => {
  test('فاکتور فروش سند متوازن تولید می‌کند', () => {
    const { ctx } = setup();
    const e = postInvoice(makeInvoice(), 600_000, ctx)!;
    assert.ok(e);
    assertBalanced(e.lines);
    assert.equal(sumDebit(e.lines), 1_100_000 + 600_000);
  });

  test('پیش‌فاکتور سند تولید نمی‌کند', () => {
    const { ctx } = setup();
    assert.equal(postInvoice(makeInvoice({ type: 'quote' }), 0, ctx), null);
  });

  test('همهٔ انواع فاکتور سند متوازن می‌دهند', () => {
    for (const type of ['sale', 'purchase', 'sale_return', 'purchase_return', 'waste'] as const) {
      const { ctx } = setup();
      const e = postInvoice(makeInvoice({ type }), 600_000, ctx);
      if (e) assertBalanced(e.lines);
    }
  });

  test('تراکنش‌ها سند متوازن می‌دهند', () => {
    const kinds: Transaction['kind'][] = ['receive', 'pay', 'expense', 'income'];
    for (const kind of kinds) {
      const { ctx } = setup();
      const tx: Transaction = {
        id: 'tx1', businessId: BIZ, kind, treasuryId: cashBox.id, partyId: 'party-1',
        amount: 250_000, date: '2026-07-29', method: 'cash', createdAt: NOW,
      };
      const e = postTransaction(tx, cashBox, null, ctx)!;
      assertBalanced(e.lines);
      assert.equal(sumDebit(e.lines), 250_000);
    }
  });

  test('سند افتتاحیه با سرمایه متوازن می‌شود', () => {
    const { ctx } = setup();
    const e = postOpening({
      date: '2026-03-21',
      parties: [{ id: 'party-1', balance: 500_000 }, { id: 'party-2', balance: -200_000 }],
      treasuries: [{ treasury: cashBox, balance: 1_000_000 }],
      inventoryValue: 3_000_000,
    }, ctx)!;
    assertBalanced(e.lines);
  });
});

describe('گزارش‌ها', () => {
  function scenario() {
    const { index, ctx } = setup();
    const entries: JournalEntry[] = [];

    // فروش ۱٬۰۰۰٬۰۰۰ با بهای تمام‌شدهٔ ۶۰۰٬۰۰۰
    entries.push(postInvoice(makeInvoice(), 600_000, ctx)!);

    // دریافت ۵۰۰٬۰۰۰ از مشتری
    entries.push(postTransaction({
      id: 'tx1', businessId: BIZ, kind: 'receive', treasuryId: cashBox.id,
      partyId: 'party-1', amount: 500_000, date: '2026-07-29', method: 'cash', createdAt: NOW,
    }, cashBox, null, ctx)!);

    return { index, entries };
  }

  test('تراز آزمایشی همیشه متوازن است', () => {
    const { index, entries } = scenario();
    const tb = trialBalance(entries, index);
    assert.equal(tb.balanced, true, 'تراز آزمایشی باید متوازن باشد');
    assert.equal(tb.totalDebit, tb.totalCredit);
  });

  test('صورت سود و زیان', () => {
    const { index, entries } = scenario();
    const pl = incomeStatement(entries, index);
    assert.equal(pl.revenue, 1_000_000);
    assert.equal(pl.cogs, 600_000);
    assert.equal(pl.grossProfit, 400_000);
    assert.equal(pl.netProfit, 400_000);
  });

  test('معادلهٔ حسابداری برقرار است: دارایی = بدهی + سرمایه', () => {
    const { index, entries } = scenario();
    const bs = balanceSheet(entries, index);
    assert.equal(bs.balanced, true,
      `دارایی ${bs.assets.total} ≠ بدهی+سرمایه ${bs.totalLiabilitiesAndEquity}`);
  });

  test('بدهکاران و بستانکاران', () => {
    const { index, entries } = scenario();
    const parties: Party[] = [
      { id: 'party-1', businessId: BIZ, kind: 'customer', name: 'مشتری الف', openingBalance: 0 },
    ];
    const dc = debtorsAndCreditors(entries, index, parties);
    // ۱٬۱۰۰٬۰۰۰ فاکتور منهای ۵۰۰٬۰۰۰ دریافتی
    assert.equal(dc.totalDebt, 600_000);
    assert.equal(dc.debtors[0]?.name, 'مشتری الف');
  });
});

// ─────────── فروش نقدی سرِ پیشخوان ───────────

/**
 * رایج‌ترین کار یک مغازه: مشتری عابر می‌آید، پول نقد می‌دهد، می‌رود.
 * نه اسمی، نه شماره‌ای، نه طلبی.
 *
 * ⚠️ پیش از این، طرف حساب برای هر فروشی اجباری بود و مغازه‌دار
 * مجبور می‌شد برای هر مشتری عابر یک «شخص» بسازد — یا بدتر، فروش را
 * به نام یک مشتری بی‌ربط ثبت کند. ضمناً فروش نقدی هم به حساب
 * دریافتنی می‌نشست و فهرست بدهکاران را پر از طلب خیالی می‌کرد.
 */
describe('فروش نقدی مغازه', () => {
  const BOX: Treasury = {
    id: 'box', businessId: BIZ, kind: 'cash', name: 'صندوق مغازه', openingBalance: 0,
  };

  function cashSale(over: Partial<Invoice> = {}): Invoice {
    return {
      id: 'inv-cash', businessId: BIZ, type: 'sale', number: 'F-1',
      partyId: null, date: '2026-06-01', isOfficial: false, isCash: true,
      lines: [{ id: 'l1', productId: 'p1', qty: 1, unit: 'عدد', unitPrice: 250_000, discount: 0, vatRate: 0 }],
      discount: 0, shipping: 0, status: 'open',
      createdAt: '2026-06-01T00:00:00.000Z', updatedAt: '2026-06-01T00:00:00.000Z',
      ...over,
    };
  }

  test('فروش نقدی بدون طرف حساب معتبر است', () => {
    assert.deepEqual(validateInvoice(cashSale()), []);
  });

  test('فروش نسیه هنوز طرف حساب می‌خواهد', () => {
    const errs = validateInvoice(cashSale({ isCash: false }));
    assert.ok(errs.some((e) => e.includes('نسیه')), `خطای نسیه نیامد: ${errs.join('،')}`);
  });

  test('پول فروش نقدی به صندوق می‌رود نه حساب دریافتنی', () => {
    const { index, ctx } = setup();
    const entry = postInvoice(cashSale(), 150_000, ctx, BOX)!;

    assert.equal(treasuryBalance([entry], BOX.id), 250_000, 'پول باید در صندوق باشد');
    assert.equal(balanceOf([entry], index.id(A.RECEIVABLE)), 0, 'نباید طلبی ساخته شود');
    assert.equal(-balanceOf([entry], index.id(A.SALES)), 250_000);
    assertBalanced(entry.lines);
  });

  test('فروش نسیه همچنان به حساب دریافتنی می‌نشیند', () => {
    const { index, ctx } = setup();
    const entry = postInvoice(
      cashSale({ isCash: false, partyId: 'cust' }), 150_000, ctx, null,
    )!;
    assert.equal(balanceOf([entry], index.id(A.RECEIVABLE)), 250_000);
    assert.equal(treasuryBalance([entry], BOX.id), 0);
  });

  test('خرید نقدی از صندوق کم می‌کند', () => {
    const { index, ctx } = setup();
    const entry = postInvoice(cashSale({
      id: 'inv-buy', type: 'purchase', number: 'P-1',
      lines: [{ id: 'l1', productId: 'p1', qty: 2, unit: 'عدد', unitPrice: 100_000, discount: 0, vatRate: 0 }],
    }), 0, ctx, BOX)!;

    assert.equal(treasuryBalance([entry], BOX.id), -200_000, 'پول باید از صندوق خارج شود');
    assert.equal(balanceOf([entry], index.id(A.PAYABLE)), 0, 'نباید بدهی ساخته شود');
    assert.equal(balanceOf([entry], index.id(A.INVENTORY)), 200_000);
  });

  test('برگشت از فروش نقدی پول را از صندوق برمی‌گرداند', () => {
    const { index, ctx } = setup();
    const entry = postInvoice(cashSale({
      id: 'inv-ret', type: 'sale_return', number: 'RS-1',
      lines: [{ id: 'l1', productId: 'p1', qty: 1, unit: 'عدد', unitPrice: 250_000, discount: 0, vatRate: 0, cogs: 150_000 }],
    }), 150_000, ctx, BOX)!;

    assert.equal(treasuryBalance([entry], BOX.id), -250_000);
    assert.equal(balanceOf([entry], index.id(A.RECEIVABLE)), 0);
    assertBalanced(entry.lines);
  });
});
