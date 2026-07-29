import { addMoney, type Rial } from './money.js';
import { EntryBuilder } from './ledger.js';
import { SYSTEM_ACCOUNTS as A, type AccountIndex } from './accounts.js';
import { accountBalances, balanceOf } from './ledger.js';
import { incomeStatement, trialBalance } from './reports.js';
import { formatJalali, dateToJalali, jalaliToDate, jalaliMonthLength } from './jalali.js';
import type { ID, JournalEntry, Party } from './types.js';

/**
 * ═══════════════════════════════════════════════════════════════
 *  بستن سال مالی
 * ═══════════════════════════════════════════════════════════════
 *
 * عملیات پایانی هر دورهٔ حسابداری. سه گام:
 *
 *  ۱. **سند اختتامیه** — حساب‌های موقت (درآمد و هزینه) صفر می‌شوند
 *     و مانده‌شان به سود انباشته منتقل می‌گردد.
 *  ۲. **تسهیم سود بین سهامداران** — بر اساس درصد شراکت (اختیاری).
 *  ۳. **سند افتتاحیهٔ دورهٔ بعد** — مانده‌های دائمی (دارایی، بدهی،
 *     سرمایه) به سال جدید منتقل می‌شوند.
 *
 * چرا مهم است؟ بدون آن، سود سال گذشته با امسال قاطی می‌شود و
 * صورت سود و زیان معنی خود را از دست می‌دهد.
 */

export interface ClosingPreview {
  /** بازهٔ سالی که بسته می‌شود */
  from: string;
  to: string;
  label: string;

  revenue: Rial;
  expenses: Rial;
  netProfit: Rial;

  /** حساب‌های موقتی که صفر می‌شوند */
  temporaryAccounts: { code: string; name: string; balance: Rial }[];
  /** مانده‌های دائمی که منتقل می‌شوند */
  permanentAccounts: { code: string; name: string; balance: Rial }[];

  shareholderSplit: { partyId: ID; name: string; percent: number; amount: Rial }[];
  /** سودی که بین سهامداران تقسیم نشده */
  retained: Rial;

  issues: string[];
  canClose: boolean;
}

export interface ClosingContext {
  index: AccountIndex;
  businessId: ID;
  idGen: () => ID;
  now: string;
}

/** بازهٔ سال مالی بر اساس سال جلالی و ماه شروع */
export function fiscalYearBounds(
  jy: number,
  startMonth = 1,
): { from: string; to: string; label: string } {
  const from = jalaliToDate({ jy, jm: startMonth, jd: 1 });
  const endMonth = startMonth === 1 ? 12 : startMonth - 1;
  const endYear = startMonth === 1 ? jy : jy + 1;
  const to = jalaliToDate({ jy: endYear, jm: endMonth, jd: jalaliMonthLength(endYear, endMonth) });

  const faYear = String(jy).replace(/\d/g, (d) => '۰۱۲۳۴۵۶۷۸۹'[Number(d)]!);
  return {
    from: from.toISOString().slice(0, 10),
    to: to.toISOString().slice(0, 10),
    label: `سال مالی ${faYear}`,
  };
}

/**
 * پیش‌نمایش بستن سال — پیش از هر تغییری نشان می‌دهد چه اتفاقی می‌افتد.
 * هیچ سندی ثبت نمی‌کند.
 */
export function previewClosing(
  entries: JournalEntry[],
  index: AccountIndex,
  opts: {
    from: string;
    to: string;
    label?: string;
    shareholders?: Party[];
    today?: string;
    alreadyClosed?: boolean;
  },
): ClosingPreview {
  const filter = { from: opts.from, to: opts.to };
  const pl = incomeStatement(entries, index, filter);
  const balances = accountBalances(entries, index, filter);

  const isTemporary = (type: string) => type === 'income' || type === 'expense';

  const temporaryAccounts = balances
    .filter((b) => isTemporary(b.type) && b.balance !== 0)
    .filter((b) => index.children(b.accountId).length === 0)
    .map((b) => ({ code: b.code, name: b.name, balance: b.balance }));

  const permanentAccounts = balances
    .filter((b) => !isTemporary(b.type) && b.balance !== 0)
    .filter((b) => index.children(b.accountId).length === 0)
    .map((b) => ({ code: b.code, name: b.name, balance: b.balance }));

  // تسهیم سود بین سهامداران بر اساس درصد شراکت
  const shareholders = (opts.shareholders ?? []).filter(
    (s) => s.kind === 'shareholder' && (s.sharePercent ?? 0) > 0,
  );

  const split = shareholders.map((s) => ({
    partyId: s.id,
    name: s.name,
    percent: s.sharePercent!,
    amount: Math.trunc((pl.netProfit * s.sharePercent!) / 100),
  }));

  const distributed = addMoney(...split.map((s) => s.amount));
  const retained = pl.netProfit - distributed;

  // ─── اعتبارسنجی ───
  const issues: string[] = [];

  const tb = trialBalance(entries, index, filter);
  if (!tb.balanced) {
    issues.push('تراز آزمایشی این دوره متوازن نیست — پیش از بستن سال باید اصلاح شود');
  }

  if (opts.today && opts.to > opts.today) {
    issues.push('نمی‌توان سالی را بست که هنوز تمام نشده است');
  }

  if (opts.alreadyClosed) {
    issues.push('این سال مالی قبلاً بسته شده است');
  }

  const totalPercent = shareholders.reduce((s, x) => s + (x.sharePercent ?? 0), 0);
  if (totalPercent > 100) {
    issues.push(`جمع درصد شراکت سهامداران ${totalPercent} است و نباید از ۱۰۰ بیشتر باشد`);
  }

  if (temporaryAccounts.length === 0 && pl.netProfit === 0) {
    issues.push('در این دوره هیچ درآمد یا هزینه‌ای ثبت نشده است');
  }

  return {
    from: opts.from,
    to: opts.to,
    label: opts.label ?? '',
    revenue: pl.netRevenue,
    expenses: addMoney(pl.cogs, pl.totalExpenses),
    netProfit: pl.netProfit,
    temporaryAccounts,
    permanentAccounts,
    shareholderSplit: split,
    retained,
    issues,
    canClose: issues.length === 0,
  };
}

/**
 * سند اختتامیه.
 *
 * همهٔ حساب‌های درآمد و هزینه با قید معکوس صفر می‌شوند و اختلاف
 * (یعنی سود یا زیان دوره) به سود انباشته می‌رود.
 */
export function buildClosingEntry(
  entries: JournalEntry[],
  ctx: ClosingContext,
  opts: { from: string; to: string; label?: string },
): JournalEntry | null {
  const { index } = ctx;
  const filter = { from: opts.from, to: opts.to };
  const balances = accountBalances(entries, index, filter);

  const b = new EntryBuilder(
    ctx.businessId,
    opts.to,
    `سند اختتامیه ${opts.label ?? ''}`.trim(),
    'closing',
    null,
  );

  let net = 0;

  for (const acc of balances) {
    if (acc.type !== 'income' && acc.type !== 'expense') continue;
    if (index.children(acc.accountId).length > 0) continue;

    // گردش خالص حساب: مثبت یعنی بدهکار
    const raw = acc.debit - acc.credit;
    if (raw === 0) continue;

    // قید معکوس تا حساب صفر شود
    if (raw > 0) b.credit(acc.accountId, raw);
    else b.debit(acc.accountId, -raw);

    // درآمد بستانکار است (raw منفی) و سود را زیاد می‌کند
    net -= raw;
  }

  if (b.isEmpty()) return null;

  // اختلاف به سود انباشته
  const retained = index.id(A.RETAINED);
  if (net > 0) b.credit(retained, net);
  else if (net < 0) b.debit(retained, -net);

  return b.build(ctx.idGen(), ctx.now);
}

/**
 * سند تسهیم سود بین سهامداران.
 * سود انباشته کاهش می‌یابد و به حساب پرداختنی هر شریک منتقل می‌شود.
 */
export function buildProfitDistributionEntry(
  split: { partyId: ID; amount: Rial }[],
  ctx: ClosingContext,
  date: string,
): JournalEntry | null {
  const { index } = ctx;
  const effective = split.filter((s) => s.amount !== 0);
  if (effective.length === 0) return null;

  const b = new EntryBuilder(ctx.businessId, date, 'تسهیم سود بین سهامداران', 'closing', null);
  const total = addMoney(...effective.map((s) => s.amount));

  b.debit(index.id(A.RETAINED), total);
  for (const s of effective) {
    b.credit(index.id(A.PAYABLE), s.amount, { partyId: s.partyId });
  }

  return b.build(ctx.idGen(), ctx.now);
}

/**
 * سند افتتاحیهٔ دورهٔ بعد.
 *
 * مانده‌های دائمی به سال جدید منتقل می‌شوند. حساب‌های موقت منتقل
 * نمی‌شوند چون در سند اختتامیه صفر شده‌اند.
 */
export function buildNextYearOpeningEntry(
  entries: JournalEntry[],
  ctx: ClosingContext,
  opts: { through: string; openingDate: string; label?: string },
): JournalEntry | null {
  const { index } = ctx;
  const b = new EntryBuilder(
    ctx.businessId,
    opts.openingDate,
    `سند افتتاحیه ${opts.label ?? ''}`.trim(),
    'opening',
    null,
  );

  // مانده‌ها تا پایان دورهٔ قبل، شامل سند اختتامیه
  const balances = accountBalances(entries, index, { to: opts.through });

  for (const acc of balances) {
    if (acc.type === 'income' || acc.type === 'expense') continue;
    if (index.children(acc.accountId).length > 0) continue;

    const raw = acc.debit - acc.credit;
    if (raw === 0) continue;

    if (raw > 0) b.debit(acc.accountId, raw);
    else b.credit(acc.accountId, -raw);
  }

  if (b.isEmpty()) return null;
  return b.build(ctx.idGen(), ctx.now);
}

export interface ClosingResult {
  closingEntry: JournalEntry | null;
  distributionEntry: JournalEntry | null;
  openingEntry: JournalEntry | null;
  netProfit: Rial;
  lockThrough: string;
}

/**
 * اجرای کامل بستن سال.
 * ترتیب مهم است: اختتامیه → تسهیم → افتتاحیه.
 */
export function closeFiscalYear(
  entries: JournalEntry[],
  ctx: ClosingContext,
  opts: {
    from: string;
    to: string;
    label?: string;
    shareholders?: Party[];
    distributeProfit?: boolean;
    /** برای اعتبارسنجی — سالی که تمام نشده بسته نمی‌شود */
    today?: string;
    alreadyClosed?: boolean;
  },
): ClosingResult {
  const preview = previewClosing(entries, ctx.index, opts);
  if (!preview.canClose) {
    throw new Error(`بستن سال ممکن نیست: ${preview.issues.join('؛ ')}`);
  }

  const closingEntry = buildClosingEntry(entries, ctx, opts);
  const withClosing = closingEntry ? [...entries, closingEntry] : entries;

  const distributionEntry =
    opts.distributeProfit && preview.shareholderSplit.length > 0
      ? buildProfitDistributionEntry(preview.shareholderSplit, ctx, opts.to)
      : null;

  const withDistribution = distributionEntry
    ? [...withClosing, distributionEntry]
    : withClosing;

  // افتتاحیه روز بعد از پایان سال
  const next = new Date(opts.to);
  next.setDate(next.getDate() + 1);
  const openingDate = next.toISOString().slice(0, 10);

  const nextLabel = `سال مالی ${formatJalali(next, 'short').slice(0, 4)}`;
  const openingEntry = buildNextYearOpeningEntry(withDistribution, ctx, {
    through: opts.to,
    openingDate,
    label: nextLabel,
  });

  return {
    closingEntry,
    distributionEntry,
    openingEntry,
    netProfit: preview.netProfit,
    lockThrough: opts.to,
  };
}

// ─────────────────── بررسی سلامت داده ───────────────────

export interface IntegrityIssue {
  severity: 'error' | 'warning';
  code: string;
  message: string;
  entityId?: ID;
}

/**
 * بررسی سلامت دفتر.
 *
 * در نرم‌افزار مالی، خطای داده باید **پیش از** اینکه کاربر متوجه شود
 * پیدا گردد. این تابع مواردی را می‌گیرد که نباید هرگز رخ دهند.
 */
export function checkIntegrity(
  entries: JournalEntry[],
  index: AccountIndex,
): IntegrityIssue[] {
  const issues: IntegrityIssue[] = [];
  const seen = new Set<ID>();

  for (const e of entries) {
    if (e.deletedAt) continue;

    // شناسهٔ تکراری
    if (seen.has(e.id)) {
      issues.push({
        severity: 'error',
        code: 'duplicate_entry',
        message: `سند تکراری با شناسهٔ ${e.id}`,
        entityId: e.id,
      });
    }
    seen.add(e.id);

    // توازن
    const debit = addMoney(...e.lines.map((l) => l.debit));
    const credit = addMoney(...e.lines.map((l) => l.credit));
    if (debit !== credit) {
      issues.push({
        severity: 'error',
        code: 'unbalanced_entry',
        message: `سند «${e.description}» نامتوازن است (بدهکار ${debit} ≠ بستانکار ${credit})`,
        entityId: e.id,
      });
    }

    // حداقل دو ردیف
    if (e.lines.length < 2) {
      issues.push({
        severity: 'error',
        code: 'incomplete_entry',
        message: `سند «${e.description}» کمتر از دو ردیف دارد`,
        entityId: e.id,
      });
    }

    for (const l of e.lines) {
      // حساب ناموجود
      if (!index.get(l.accountId)) {
        issues.push({
          severity: 'error',
          code: 'unknown_account',
          message: `سند «${e.description}» به حسابی ارجاع می‌دهد که وجود ندارد`,
          entityId: e.id,
        });
      }
      // مبلغ منفی
      if (l.debit < 0 || l.credit < 0) {
        issues.push({
          severity: 'error',
          code: 'negative_amount',
          message: `سند «${e.description}» مبلغ منفی دارد`,
          entityId: e.id,
        });
      }
      // هر دو طرف پر
      if (l.debit > 0 && l.credit > 0) {
        issues.push({
          severity: 'warning',
          code: 'both_sides',
          message: `ردیفی در سند «${e.description}» هم بدهکار است هم بستانکار`,
          entityId: e.id,
        });
      }
    }

    // تاریخ نامعتبر
    if (Number.isNaN(new Date(e.date).getTime())) {
      issues.push({
        severity: 'error',
        code: 'invalid_date',
        message: `سند «${e.description}» تاریخ نامعتبر دارد`,
        entityId: e.id,
      });
    }
  }

  // موجودی کالا نباید بستانکار باشد
  const inventory = index.byCodeOrNull(A.INVENTORY);
  if (inventory) {
    const bal = balanceOf(entries, inventory.id);
    if (bal < 0) {
      issues.push({
        severity: 'warning',
        code: 'negative_inventory',
        message: 'ارزش موجودی کالا منفی است — احتمالاً فروش بیش از موجودی ثبت شده',
      });
    }
  }

  return issues;
}

export function integritySummary(issues: IntegrityIssue[]): {
  ok: boolean;
  errors: number;
  warnings: number;
  message: string;
} {
  const errors = issues.filter((i) => i.severity === 'error').length;
  const warnings = issues.filter((i) => i.severity === 'warning').length;

  const fa = (n: number) => String(n).replace(/\d/g, (d) => '۰۱۲۳۴۵۶۷۸۹'[Number(d)]!);

  if (errors === 0 && warnings === 0) {
    return { ok: true, errors, warnings, message: 'دفتر سالم است' };
  }
  if (errors === 0) {
    return { ok: true, errors, warnings, message: `${fa(warnings)} هشدار — دفتر قابل استفاده است` };
  }
  return {
    ok: false,
    errors,
    warnings,
    message: `${fa(errors)} خطای جدی در دفتر یافت شد`,
  };
}

/** سال مالی جاری بر اساس تاریخ */
export function currentFiscalYear(date: Date, startMonth = 1): number {
  const j = dateToJalali(date);
  return j.jm >= startMonth ? j.jy : j.jy - 1;
}
