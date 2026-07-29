import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { AccountIndex, createChartOfAccounts, SYSTEM_ACCOUNTS as A } from '../dist/accounts.js';
import { defaultTreasuryAccount, invoiceLineUnitCost, postInvoice, postTransaction, stockMovementsFor } from '../dist/posting.js';
import { consumeStock, replayProduct, stockByProduct } from '../dist/inventory.js';
import { computeInvoice, createReturn, quoteToSale } from '../dist/invoice.js';
import { balanceSheet, debtorsAndCreditors, incomeStatement, trialBalance } from '../dist/reports.js';
import { assertBalanced } from '../dist/ledger.js';
import type { Invoice, JournalEntry, Party, StockMovement, Treasury } from '../dist/types.js';

/**
 * سناریوی واقعی یک مغازه: خرید، فروش، برگشت، دریافت وجه.
 * هدف: اثبات اینکه پس از ده‌ها عملیات، دفتر همچنان متوازن است
 * و سود گزارش‌شده با محاسبهٔ دستی می‌خواند.
 */

let seq = 0;
const idGen = () => `id-${String(++seq).padStart(5, '0')}`;
const BIZ = 'shop';

describe('سناریوی کامل یک مغازه', () => {
  const accounts = createChartOfAccounts(BIZ, idGen);
  const index = new AccountIndex(accounts);
  const cash: Treasury = { id: 'cash', businessId: BIZ, kind: 'cash', name: 'صندوق', openingBalance: 0 };
  const ctx = {
    index, businessId: BIZ, idGen, now: '2026-07-29T00:00:00Z',
    treasuryAccount: defaultTreasuryAccount(index),
  };

  const entries: JournalEntry[] = [];
  let movements: StockMovement[] = [];

  const parties: Party[] = [
    { id: 'cust', businessId: BIZ, kind: 'customer', name: 'مشتری الف', openingBalance: 0 },
    { id: 'vend', businessId: BIZ, kind: 'vendor', name: 'تأمین‌کننده ب', openingBalance: 0 },
  ];

  function inv(over: Partial<Invoice>): Invoice {
    return {
      id: idGen(), businessId: BIZ, type: 'sale', number: 'X', partyId: 'cust',
      date: '2026-07-01', isOfficial: false, lines: [], discount: 0, shipping: 0,
      status: 'open', createdAt: '2026-07-01T00:00:00Z', updatedAt: '2026-07-01T00:00:00Z',
      ...over,
    };
  }

  function post(invoice: Invoice) {
    const outbound = invoice.type === 'sale' || invoice.type === 'waste';
    let cogs = 0;
    const costs = new Map<string, number>();

    if (outbound) {
      // خروج از انبار: بها از لایه‌های موجودی مصرف می‌شود
      for (const l of invoice.lines) {
        const state = replayProduct(movements.filter((m) => m.productId === l.productId), 'fifo', { allowNegative: true });
        const r = consumeStock(state.layers, l.qty, 'fifo', { allowNegative: true });
        costs.set(l.id, r.cogs);
        cogs += r.cogs;
      }
    } else if (invoice.type === 'sale_return') {
      // برگشت از فروش: بها از خود ردیف می‌آید (بهای اصلی خروج)
      for (const l of invoice.lines) {
        const c = l.cogs ?? 0;
        costs.set(l.id, c);
        cogs += c;
      }
    }

    const withCosts: Invoice = {
      ...invoice,
      lines: invoice.lines.map((l) => (costs.has(l.id) ? { ...l, cogs: costs.get(l.id) } : { ...l })),
    };

    const entry = postInvoice(withCosts, cogs, ctx);
    if (entry) {
      assertBalanced(entry.lines);
      entries.push(entry);
    }

    movements = [...movements, ...stockMovementsFor(withCosts, { businessId: BIZ, idGen }, (l) =>
      invoiceLineUnitCost(withCosts, l, costs.get(l.id)),
    )];

    return withCosts;
  }

  test('۱— خرید ۱۰۰ عدد به قیمت ۱۰٬۰۰۰', () => {
    post(inv({
      type: 'purchase', number: 'P-0001', partyId: 'vend',
      lines: [{ id: 'pl1', productId: 'p1', qty: 100, unit: 'عدد', unitPrice: 10_000, discount: 0, vatRate: 0 }],
    }));
    const stock = replayProduct(movements, 'fifo');
    assert.equal(stock.qty, 100);
    assert.equal(stock.value, 1_000_000);
  });

  test('۲— خرید ۵۰ عدد گران‌تر به قیمت ۱۲٬۰۰۰', () => {
    post(inv({
      type: 'purchase', number: 'P-0002', partyId: 'vend', date: '2026-07-05',
      lines: [{ id: 'pl2', productId: 'p1', qty: 50, unit: 'عدد', unitPrice: 12_000, discount: 0, vatRate: 0 }],
    }));
    const stock = replayProduct(movements, 'fifo');
    assert.equal(stock.qty, 150);
    assert.equal(stock.value, 1_600_000);
  });

  test('۳— فروش ۱۲۰ عدد به ۱۵٬۰۰۰ — فایفو بهای درست می‌دهد', () => {
    const sale = post(inv({
      type: 'sale', number: 'F-0001', date: '2026-07-10',
      lines: [{ id: 'sl1', productId: 'p1', qty: 120, unit: 'عدد', unitPrice: 15_000, discount: 0, vatRate: 0 }],
    }));

    // فایفو: ۱۰۰ عدد از ۱۰٬۰۰۰ و ۲۰ عدد از ۱۲٬۰۰۰
    assert.equal(sale.lines[0]!.cogs, 100 * 10_000 + 20 * 12_000);

    const stock = replayProduct(movements, 'fifo');
    assert.equal(stock.qty, 30);
    assert.equal(stock.value, 30 * 12_000);
  });

  test('۴— دریافت ۱٬۰۰۰٬۰۰۰ از مشتری', () => {
    const e = postTransaction({
      id: idGen(), businessId: BIZ, kind: 'receive', treasuryId: cash.id,
      partyId: 'cust', amount: 1_000_000, date: '2026-07-12', method: 'cash',
      createdAt: '2026-07-12T00:00:00Z',
    }, cash, null, ctx)!;
    assertBalanced(e.lines);
    entries.push(e);
  });

  test('۵— برگشت از فروش ۲۰ عدد — کالا با بهای اصلی برمی‌گردد', () => {
    // ۲۰ عدد از فاکتور اصلی که با بهای ۱۰٬۰۰۰ خارج شده بودند
    const returnCogs = 20 * 10_000;
    post(inv({
      type: 'sale_return', number: 'RS-0001', date: '2026-07-15',
      lines: [{
        id: 'rl1', productId: 'p1', qty: 20, unit: 'عدد',
        unitPrice: 15_000, discount: 0, vatRate: 0, cogs: returnCogs,
      }],
    }));

    const stock = replayProduct(movements, 'fifo');
    assert.equal(stock.qty, 50);
    // ۳۰ عدد باقی‌مانده به بهای ۱۲٬۰۰۰ + ۲۰ عدد برگشتی به بهای ۱۰٬۰۰۰
    assert.equal(stock.value, 30 * 12_000 + 20 * 10_000);
  });

  test('۶— دفتر پس از همهٔ عملیات متوازن است', () => {
    const tb = trialBalance(entries, index);
    assert.equal(tb.balanced, true,
      `تراز آزمایشی نامتوازن: بدهکار ${tb.totalDebit} ≠ بستانکار ${tb.totalCredit}`);
  });

  test('۷— معادلهٔ حسابداری برقرار است', () => {
    const bs = balanceSheet(entries, index);
    assert.equal(bs.balanced, true,
      `دارایی ${bs.assets.total} ≠ بدهی+سرمایه ${bs.totalLiabilitiesAndEquity}`);
  });

  test('۸— سود گزارش‌شده با محاسبهٔ دستی می‌خواند', () => {
    const pl = incomeStatement(entries, index);

    // فروش ۱۲۰×۱۵٬۰۰۰ = ۱٬۸۰۰٬۰۰۰ ، برگشت ۲۰×۱۵٬۰۰۰ = ۳۰۰٬۰۰۰
    assert.equal(pl.revenue, 1_800_000);
    assert.equal(pl.salesReturns, 300_000);
    assert.equal(pl.netRevenue, 1_500_000);

    // بهای فروش ۱٬۲۴۰٬۰۰۰ منهای بهای کالای برگشتی ۲۰۰٬۰۰۰ (به بهای تمام‌شده، نه قیمت فروش)
    assert.equal(pl.cogs, 1_240_000 - 200_000);
    assert.equal(pl.grossProfit, 1_500_000 - 1_040_000);
  });

  test('۹— مانده مشتری و تأمین‌کننده درست است', () => {
    const dc = debtorsAndCreditors(entries, index, parties);
    // مشتری: ۱٬۸۰۰٬۰۰۰ فروش − ۳۰۰٬۰۰۰ برگشت − ۱٬۰۰۰٬۰۰۰ دریافت = ۵۰۰٬۰۰۰ بدهکار
    assert.equal(dc.debtors.find((d) => d.partyId === 'cust')?.balance, 500_000);
    // تأمین‌کننده: ۱٬۰۰۰٬۰۰۰ + ۶۰۰٬۰۰۰ = ۱٬۶۰۰٬۰۰۰ بستانکار
    assert.equal(dc.creditors.find((c) => c.partyId === 'vend')?.balance, -1_600_000);
  });

  test('۱۰— موجودی نهایی انبار', () => {
    const byProduct = stockByProduct(movements, 'fifo');
    assert.equal(byProduct.get('p1')?.qty, 50);
  });
});

describe('تبدیل‌ها', () => {
  const base: Invoice = {
    id: 'q1', businessId: BIZ, type: 'quote', number: 'Q-0001', partyId: 'cust',
    date: '2026-07-01', isOfficial: false,
    lines: [{ id: 'l1', productId: 'p1', qty: 5, unit: 'عدد', unitPrice: 20_000, discount: 0, vatRate: 0 }],
    discount: 0, shipping: 0, status: 'draft',
    createdAt: '2026-07-01T00:00:00Z', updatedAt: '2026-07-01T00:00:00Z',
  };

  test('پیش‌فاکتور به فاکتور فروش تبدیل می‌شود', () => {
    const sale = quoteToSale(base, 'new', 'F-0100', '2026-07-02T00:00:00Z');
    assert.equal(sale.type, 'sale');
    assert.equal(sale.number, 'F-0100');
    assert.equal(computeInvoice(sale).grandTotal, 100_000);
  });

  test('فاکتور غیرپیش‌فاکتور تبدیل نمی‌شود', () => {
    assert.throws(() => quoteToSale({ ...base, type: 'sale' }, 'x', 'y', 'z'));
  });

  test('برگشت جزئی فقط اقلام انتخابی را می‌گیرد', () => {
    const sale = { ...base, type: 'sale' as const };
    const ret = createReturn(sale, 'r1', 'RS-0001', '2026-07-03T00:00:00Z', new Map([['l1', 2]]));
    assert.equal(ret.type, 'sale_return');
    assert.equal(ret.lines[0]!.qty, 2);
    assert.equal(computeInvoice(ret).grandTotal, 40_000);
    assert.equal(ret.sourceInvoiceId, sale.id);
  });

  test('برگشت، بهای تمام‌شده را به نسبت مقدار منتقل می‌کند', () => {
    const sale: Invoice = {
      ...base,
      type: 'sale',
      lines: [{ ...base.lines[0]!, qty: 10, cogs: 100_000 }],
    };
    const ret = createReturn(sale, 'r2', 'RS-0002', 'now', new Map([['l1', 3]]));
    // ۳ از ۱۰ عدد → ۳۰٬۰۰۰ از ۱۰۰٬۰۰۰
    assert.equal(ret.lines[0]!.cogs, 30_000);
  });

  test('برگشت بدون قلم انتخابی خطا می‌دهد', () => {
    const sale = { ...base, type: 'sale' as const };
    assert.throws(() => createReturn(sale, 'r', 'n', 'd', new Map()), /هیچ ردیفی/);
  });
});
