import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { AccountIndex, createChartOfAccounts, SYSTEM_ACCOUNTS as A } from '../dist/accounts.js';
import { defaultTreasuryAccount, postInvoice, postTransaction } from '../dist/posting.js';
import { assertBalanced, accountBalances, balanceOf } from '../dist/ledger.js';
import { balanceSheet, incomeStatement, trialBalance } from '../dist/reports.js';
import {
  buildClosingEntry, buildNextYearOpeningEntry, buildProfitDistributionEntry,
  checkIntegrity, closeFiscalYear, currentFiscalYear, fiscalYearBounds,
  integritySummary, previewClosing,
} from '../dist/closing.js';
import type { Invoice, JournalEntry, Party, Treasury } from '../dist/types.js';

let seq = 0;
const idGen = () => `id-${String(++seq).padStart(5, '0')}`;
const BIZ = 'biz';
const NOW = '2027-03-20T00:00:00.000Z';

function setup() {
  seq = 0;
  const accounts = createChartOfAccounts(BIZ, idGen);
  const index = new AccountIndex(accounts);
  return { index, ctx: { index, businessId: BIZ, idGen, now: NOW } };
}

const cash: Treasury = {
  id: 'cash', businessId: BIZ, kind: 'cash', name: 'صندوق', openingBalance: 0,
};

function saleInvoice(over: Partial<Invoice> = {}): Invoice {
  return {
    id: idGen(), businessId: BIZ, type: 'sale', number: 'F-1',
    partyId: 'cust', date: '2026-06-01', isOfficial: false,
    lines: [{ id: idGen(), productId: 'p1', qty: 1, unit: 'ع', unitPrice: 1_000_000, discount: 0, vatRate: 0 }],
    discount: 0, shipping: 0, status: 'open',
    createdAt: NOW, updatedAt: NOW, ...over,
  };
}

/** یک سال کاری کامل: فروش با سود، و یک هزینه */
function yearOfTrading() {
  const { index, ctx } = setup();
  const postCtx = { ...ctx, treasuryAccount: defaultTreasuryAccount(index) };
  const entries: JournalEntry[] = [];

  // فروش ۳٬۰۰۰٬۰۰۰ با بهای ۱٬۸۰۰٬۰۰۰
  entries.push(postInvoice(saleInvoice({
    date: '2026-06-01',
    lines: [{ id: 'l1', productId: 'p1', qty: 3, unit: 'ع', unitPrice: 1_000_000, discount: 0, vatRate: 0 }],
  }), 1_800_000, postCtx)!);

  // هزینهٔ اجاره ۵۰۰٬۰۰۰
  entries.push(postTransaction({
    id: idGen(), businessId: BIZ, kind: 'expense', treasuryId: cash.id,
    accountId: index.id(A.OTHER_EXPENSE), amount: 500_000,
    date: '2026-08-01', method: 'cash', createdAt: NOW,
  }, cash, null, postCtx)!);

  return { index, ctx, entries };
}

const FY = { from: '2026-03-21', to: '2027-03-20', label: 'سال مالی ۱۴۰۵' };

// ─────────── بازهٔ سال مالی ───────────

describe('بازهٔ سال مالی', () => {
  test('سال شمسی با شروع فروردین', () => {
    const b = fiscalYearBounds(1405, 1);
    assert.match(b.label, /۱۴۰۵/);
    assert.ok(b.from < b.to);
  });

  test('سال مالی با شروع غیرفروردین به سال بعد کشیده می‌شود', () => {
    const b = fiscalYearBounds(1405, 7);
    assert.ok(b.from < b.to);
    // مهر ۱۴۰۵ تا شهریور ۱۴۰۶
    assert.ok(new Date(b.to).getFullYear() > new Date(b.from).getFullYear());
  });

  test('تشخیص سال مالی جاری', () => {
    // ۷ مرداد ۱۴۰۵ با شروع فروردین → ۱۴۰۵
    assert.equal(currentFiscalYear(new Date(2026, 6, 29), 1), 1405);
    // با شروع مهر، مرداد هنوز متعلق به سال قبل است
    assert.equal(currentFiscalYear(new Date(2026, 6, 29), 7), 1404);
  });
});

// ─────────── پیش‌نمایش ───────────

describe('پیش‌نمایش بستن سال', () => {
  test('سود دوره درست محاسبه می‌شود', () => {
    const { index, entries } = yearOfTrading();
    const p = previewClosing(entries, index, FY);

    // ۳٬۰۰۰٬۰۰۰ فروش − ۱٬۸۰۰٬۰۰۰ بهای فروش − ۵۰۰٬۰۰۰ هزینه
    assert.equal(p.revenue, 3_000_000);
    assert.equal(p.netProfit, 700_000);
    assert.equal(p.canClose, true);
  });

  test('حساب‌های موقت و دائمی تفکیک می‌شوند', () => {
    const { index, entries } = yearOfTrading();
    const p = previewClosing(entries, index, FY);

    assert.ok(p.temporaryAccounts.some((a) => a.code === A.SALES), 'فروش باید موقت باشد');
    assert.ok(p.temporaryAccounts.some((a) => a.code === A.COGS), 'بهای فروش باید موقت باشد');
    assert.ok(p.permanentAccounts.some((a) => a.code === A.RECEIVABLE), 'دریافتنی باید دائمی باشد');
    assert.ok(
      !p.permanentAccounts.some((a) => a.code === A.SALES),
      'حساب موقت نباید در دائمی‌ها باشد',
    );
  });

  test('تسهیم سود بین سهامداران', () => {
    const { index, entries } = yearOfTrading();
    const shareholders: Party[] = [
      { id: 's1', businessId: BIZ, kind: 'shareholder', name: 'شریک الف', openingBalance: 0, sharePercent: 60 },
      { id: 's2', businessId: BIZ, kind: 'shareholder', name: 'شریک ب', openingBalance: 0, sharePercent: 40 },
    ];
    const p = previewClosing(entries, index, { ...FY, shareholders });

    assert.equal(p.shareholderSplit.length, 2);
    assert.equal(p.shareholderSplit[0]?.amount, 420_000);
    assert.equal(p.shareholderSplit[1]?.amount, 280_000);
    assert.equal(p.retained, 0, 'با ۱۰۰٪ تسهیم، چیزی باقی نمی‌ماند');
  });

  test('تسهیم جزئی، باقی‌مانده را نگه می‌دارد', () => {
    const { index, entries } = yearOfTrading();
    const shareholders: Party[] = [
      { id: 's1', businessId: BIZ, kind: 'shareholder', name: 'ش', openingBalance: 0, sharePercent: 30 },
    ];
    const p = previewClosing(entries, index, { ...FY, shareholders });
    assert.equal(p.shareholderSplit[0]?.amount, 210_000);
    assert.equal(p.retained, 490_000);
  });

  test('درصد شراکت بیش از صد رد می‌شود', () => {
    const { index, entries } = yearOfTrading();
    const shareholders: Party[] = [
      { id: 's1', businessId: BIZ, kind: 'shareholder', name: 'الف', openingBalance: 0, sharePercent: 70 },
      { id: 's2', businessId: BIZ, kind: 'shareholder', name: 'ب', openingBalance: 0, sharePercent: 50 },
    ];
    const p = previewClosing(entries, index, { ...FY, shareholders });
    assert.equal(p.canClose, false);
    assert.ok(p.issues.some((i) => i.includes('۱۰۰')));
  });

  test('سال تمام‌نشده بسته نمی‌شود', () => {
    const { index, entries } = yearOfTrading();
    const p = previewClosing(entries, index, { ...FY, today: '2026-10-01' });
    assert.equal(p.canClose, false);
    assert.ok(p.issues.some((i) => i.includes('تمام نشده')));
  });

  test('بستن دوبارهٔ همان سال رد می‌شود', () => {
    const { index, entries } = yearOfTrading();
    const p = previewClosing(entries, index, { ...FY, alreadyClosed: true });
    assert.equal(p.canClose, false);
    assert.ok(p.issues.some((i) => i.includes('قبلاً بسته')));
  });

  test('دورهٔ خالی هشدار می‌دهد', () => {
    const { index } = setup();
    const p = previewClosing([], index, FY);
    assert.equal(p.canClose, false);
  });
});

// ─────────── سند اختتامیه ───────────

describe('سند اختتامیه', () => {
  test('سند متوازن است', () => {
    const { index, ctx, entries } = yearOfTrading();
    const e = buildClosingEntry(entries, ctx, FY)!;
    assert.ok(e);
    assertBalanced(e.lines);
    assert.equal(e.sourceType, 'closing');
  });

  test('پس از اختتامیه همهٔ حساب‌های موقت صفر می‌شوند', () => {
    const { index, ctx, entries } = yearOfTrading();
    const closing = buildClosingEntry(entries, ctx, FY)!;
    const after = [...entries, closing];

    const balances = accountBalances(after, index, { from: FY.from, to: FY.to });
    for (const b of balances) {
      if (b.type === 'income' || b.type === 'expense') {
        assert.equal(
          b.debit - b.credit, 0,
          `حساب ${b.name} پس از اختتامیه باید صفر باشد ولی ${b.debit - b.credit} است`,
        );
      }
    }
  });

  test('سود به سود انباشته منتقل می‌شود', () => {
    const { index, ctx, entries } = yearOfTrading();
    const closing = buildClosingEntry(entries, ctx, FY)!;
    const after = [...entries, closing];

    // سود انباشته بستانکار می‌شود، پس مانده منفی است
    const retained = balanceOf(after, index.id(A.RETAINED), { from: FY.from, to: FY.to });
    assert.equal(-retained, 700_000, 'سود انباشته باید برابر سود دوره باشد');
  });

  test('صورت سود و زیان پس از اختتامیه صفر می‌شود', () => {
    const { index, ctx, entries } = yearOfTrading();
    const after = [...entries, buildClosingEntry(entries, ctx, FY)!];
    const pl = incomeStatement(after, index, { from: FY.from, to: FY.to });
    assert.equal(pl.netProfit, 0, 'پس از بستن، سود دوره باید صفر شود');
  });

  test('تراز آزمایشی پس از اختتامیه همچنان متوازن است', () => {
    const { index, ctx, entries } = yearOfTrading();
    const after = [...entries, buildClosingEntry(entries, ctx, FY)!];
    assert.equal(trialBalance(after, index, { from: FY.from, to: FY.to }).balanced, true);
  });

  test('زیان هم درست منتقل می‌شود', () => {
    const { index, ctx } = setup();
    const postCtx = { ...ctx, treasuryAccount: defaultTreasuryAccount(index) };
    // فقط هزینه، بدون درآمد
    const entries = [postTransaction({
      id: 'tx', businessId: BIZ, kind: 'expense', treasuryId: cash.id,
      accountId: index.id(A.OTHER_EXPENSE), amount: 300_000,
      date: '2026-06-01', method: 'cash', createdAt: NOW,
    }, cash, null, postCtx)!];

    const closing = buildClosingEntry(entries, ctx, FY)!;
    assertBalanced(closing.lines);

    const after = [...entries, closing];
    const retained = balanceOf(after, index.id(A.RETAINED), { from: FY.from, to: FY.to });
    assert.equal(retained, 300_000, 'زیان باید سود انباشته را بدهکار کند');
  });

  test('دفتر خالی سند اختتامیه نمی‌سازد', () => {
    const { ctx } = setup();
    assert.equal(buildClosingEntry([], ctx, FY), null);
  });
});

// ─────────── تسهیم و افتتاحیه ───────────

describe('تسهیم سود', () => {
  test('سند تسهیم متوازن است', () => {
    const { ctx } = setup();
    const e = buildProfitDistributionEntry(
      [{ partyId: 's1', amount: 420_000 }, { partyId: 's2', amount: 280_000 }],
      ctx, '2027-03-20',
    )!;
    assertBalanced(e.lines);
    assert.equal(e.lines.filter((l) => l.credit > 0).length, 2);
  });

  test('سهم صفر نادیده گرفته می‌شود', () => {
    const { ctx } = setup();
    const e = buildProfitDistributionEntry(
      [{ partyId: 's1', amount: 100 }, { partyId: 's2', amount: 0 }],
      ctx, '2027-03-20',
    )!;
    assert.equal(e.lines.filter((l) => l.credit > 0).length, 1);
  });

  test('فهرست خالی سند نمی‌سازد', () => {
    const { ctx } = setup();
    assert.equal(buildProfitDistributionEntry([], ctx, '2027-03-20'), null);
  });
});

describe('سند افتتاحیهٔ دورهٔ بعد', () => {
  test('فقط مانده‌های دائمی منتقل می‌شوند', () => {
    const { index, ctx, entries } = yearOfTrading();
    const after = [...entries, buildClosingEntry(entries, ctx, FY)!];

    const opening = buildNextYearOpeningEntry(after, ctx, {
      through: FY.to, openingDate: '2027-03-21',
    })!;
    assertBalanced(opening.lines);

    for (const l of opening.lines) {
      const acc = index.get(l.accountId)!;
      assert.ok(
        acc.type !== 'income' && acc.type !== 'expense',
        `حساب موقت ${acc.name} نباید منتقل شود`,
      );
    }
  });

  test('مانده‌های سال جدید با پایان سال قبل یکی است', () => {
    const { index, ctx, entries } = yearOfTrading();
    const after = [...entries, buildClosingEntry(entries, ctx, FY)!];
    const opening = buildNextYearOpeningEntry(after, ctx, {
      through: FY.to, openingDate: '2027-03-21',
    })!;

    const before = balanceOf(after, index.id(A.RECEIVABLE), { to: FY.to });
    const carried = opening.lines
      .filter((l) => l.accountId === index.id(A.RECEIVABLE))
      .reduce((s, l) => s + l.debit - l.credit, 0);

    assert.equal(carried, before, 'مانده دریافتنی باید عیناً منتقل شود');
  });
});

// ─────────── چرخهٔ کامل ───────────

describe('بستن کامل سال مالی', () => {
  test('هر سه سند ساخته می‌شوند و متوازن‌اند', () => {
    const { ctx, entries } = yearOfTrading();
    const shareholders: Party[] = [
      { id: 's1', businessId: BIZ, kind: 'shareholder', name: 'الف', openingBalance: 0, sharePercent: 100 },
    ];

    const r = closeFiscalYear(entries, ctx, { ...FY, shareholders, distributeProfit: true });

    assert.ok(r.closingEntry, 'سند اختتامیه');
    assert.ok(r.distributionEntry, 'سند تسهیم');
    assert.ok(r.openingEntry, 'سند افتتاحیه');
    assert.equal(r.netProfit, 700_000);

    for (const e of [r.closingEntry, r.distributionEntry, r.openingEntry]) {
      if (e) assertBalanced(e.lines);
    }
  });

  test('معادلهٔ حسابداری پس از بستن سال برقرار می‌ماند', () => {
    const { index, ctx, entries } = yearOfTrading();
    const r = closeFiscalYear(entries, ctx, FY);

    const all = [entries, r.closingEntry, r.openingEntry]
      .flat()
      .filter((e): e is JournalEntry => e !== null);

    const bs = balanceSheet(all, index, { to: '2027-03-21' });
    assert.equal(
      bs.balanced, true,
      `دارایی ${bs.assets.total} ≠ بدهی+سرمایه ${bs.totalLiabilitiesAndEquity}`,
    );
  });

  test('بستن سال نامعتبر پرتاب می‌کند', () => {
    const { ctx, entries } = yearOfTrading();
    assert.throws(
      () => closeFiscalYear(entries, ctx, { ...FY, today: '2026-06-01' }),
      /بستن سال ممکن نیست/,
    );
  });

  test('بدون تسهیم، سود در انباشته می‌ماند', () => {
    const { index, ctx, entries } = yearOfTrading();
    const r = closeFiscalYear(entries, ctx, FY);
    assert.equal(r.distributionEntry, null);

    const after = [...entries, r.closingEntry!];
    assert.equal(-balanceOf(after, index.id(A.RETAINED), { to: FY.to }), 700_000);
  });
});

// ─────────── سلامت داده ───────────

describe('بررسی سلامت دفتر', () => {
  test('دفتر سالم خطایی ندارد', () => {
    const { index, entries } = yearOfTrading();
    const issues = checkIntegrity(entries, index);
    assert.equal(issues.filter((i) => i.severity === 'error').length, 0);
    assert.equal(integritySummary(issues).ok, true);
  });

  test('سند نامتوازن گرفته می‌شود', () => {
    const { index, entries } = yearOfTrading();
    const broken: JournalEntry = {
      id: 'bad', businessId: BIZ, date: '2026-06-01',
      sourceType: 'manual', description: 'خراب',
      lines: [
        { accountId: index.id(A.CASH), debit: 1000, credit: 0 },
        { accountId: index.id(A.SALES), debit: 0, credit: 900 },
      ],
      createdAt: NOW,
    };
    const issues = checkIntegrity([...entries, broken], index);
    assert.ok(issues.some((i) => i.code === 'unbalanced_entry'));
    assert.equal(integritySummary(issues).ok, false);
  });

  test('سند تکراری گرفته می‌شود', () => {
    const { index, entries } = yearOfTrading();
    const dup = entries[0]!;
    const issues = checkIntegrity([...entries, dup], index);
    assert.ok(issues.some((i) => i.code === 'duplicate_entry'));
  });

  test('حساب ناموجود گرفته می‌شود', () => {
    const { index } = setup();
    const bad: JournalEntry = {
      id: 'x', businessId: BIZ, date: '2026-06-01',
      sourceType: 'manual', description: 'ارجاع خراب',
      lines: [
        { accountId: 'ghost', debit: 100, credit: 0 },
        { accountId: index.id(A.CASH), debit: 0, credit: 100 },
      ],
      createdAt: NOW,
    };
    assert.ok(checkIntegrity([bad], index).some((i) => i.code === 'unknown_account'));
  });

  test('سند تک‌ردیفی گرفته می‌شود', () => {
    const { index } = setup();
    const bad: JournalEntry = {
      id: 'x', businessId: BIZ, date: '2026-06-01',
      sourceType: 'manual', description: 'ناقص',
      lines: [{ accountId: index.id(A.CASH), debit: 0, credit: 0 }],
      createdAt: NOW,
    };
    assert.ok(checkIntegrity([bad], index).some((i) => i.code === 'incomplete_entry'));
  });

  test('سند حذف‌شده بررسی نمی‌شود', () => {
    const { index } = setup();
    const deleted: JournalEntry = {
      id: 'x', businessId: BIZ, date: '2026-06-01',
      sourceType: 'manual', description: 'حذف‌شده',
      lines: [{ accountId: index.id(A.CASH), debit: 100, credit: 0 }],
      createdAt: NOW, deletedAt: NOW,
    };
    assert.equal(checkIntegrity([deleted], index).length, 0);
  });

  test('خلاصهٔ سلامت فارسی است', () => {
    const { index, entries } = yearOfTrading();
    const s = integritySummary(checkIntegrity(entries, index));
    assert.match(s.message, /[\u0600-\u06FF]/);
  });
});
