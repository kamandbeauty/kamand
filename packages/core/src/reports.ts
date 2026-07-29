import { addMoney, type Rial } from './money.js';
import { SYSTEM_ACCOUNTS as A, type AccountIndex } from './accounts.js';
import { accountBalances, activeEntries, partyBalances, type LedgerFilter } from './ledger.js';
import type { AccountType, ID, JournalEntry, Party } from './types.js';

/**
 * گزارش‌ها همگی از دفتر مشتق می‌شوند — هیچ جدول گزارشی ذخیره نمی‌شود.
 * این یعنی گزارش هرگز با واقعیت ناهماهنگ نمی‌شود.
 */

// ─────────────────── تراز آزمایشی ───────────────────

export interface TrialBalanceRow {
  code: string;
  name: string;
  type: AccountType;
  debit: Rial;
  credit: Rial;
}

export interface TrialBalance {
  rows: TrialBalanceRow[];
  totalDebit: Rial;
  totalCredit: Rial;
  balanced: boolean;
}

export function trialBalance(
  entries: JournalEntry[],
  index: AccountIndex,
  filter: LedgerFilter = {},
): TrialBalance {
  const balances = accountBalances(entries, index, filter);
  const rows = balances
    .filter((b) => b.debit !== 0 || b.credit !== 0)
    .map((b) => {
      const net = b.debit - b.credit;
      return {
        code: b.code,
        name: b.name,
        type: b.type,
        debit: net > 0 ? net : 0,
        credit: net < 0 ? -net : 0,
      };
    });

  const totalDebit = addMoney(...rows.map((r) => r.debit));
  const totalCredit = addMoney(...rows.map((r) => r.credit));
  return { rows, totalDebit, totalCredit, balanced: totalDebit === totalCredit };
}

// ─────────────────── صورت سود و زیان ───────────────────

export interface IncomeStatement {
  revenue: Rial;
  salesReturns: Rial;
  netRevenue: Rial;
  cogs: Rial;
  grossProfit: Rial;
  expenses: { code: string; name: string; amount: Rial }[];
  totalExpenses: Rial;
  otherIncome: Rial;
  netProfit: Rial;
}

/**
 * صورت سود و زیان.
 *
 * ⚠️ سند اختتامیه عمداً کنار گذاشته می‌شود. آن سند حساب‌های درآمد و
 * هزینه را صفر می‌کند، پس اگر شمرده شود سود هر سالِ بسته‌شده صفر
 * گزارش می‌گردد — یعنی کاربر پس از بستن سال دیگر نمی‌تواند ببیند
 * همان سال چقدر سود داشته است.
 */
export function incomeStatement(
  entries: JournalEntry[],
  index: AccountIndex,
  filter: LedgerFilter = {},
): IncomeStatement {
  const balances = accountBalances(entries, index, {
    ...filter,
    excludeSources: [...(filter.excludeSources ?? []), 'closing'],
  });
  const find = (code: string) => balances.find((b) => b.code === code)?.balance ?? 0;

  const revenue = find(A.SALES);
  const salesReturns = Math.abs(find(A.SALES_RETURN));
  const salesDiscount = Math.abs(find(A.SALES_DISCOUNT));
  const netRevenue = revenue - salesReturns - salesDiscount;

  const cogs = find(A.COGS) - Math.abs(find(A.PURCHASE_RETURN));
  const grossProfit = netRevenue - cogs;

  const excluded = new Set<string>([A.COGS, A.PURCHASE_RETURN]);
  const expenses = balances
    .filter((b) => b.type === 'expense' && !excluded.has(b.code) && b.balance !== 0)
    .filter((b) => index.children(b.accountId).length === 0)
    .map((b) => ({ code: b.code, name: b.name, amount: b.balance }));

  const totalExpenses = addMoney(...expenses.map((e) => e.amount));
  const otherIncome = find(A.OTHER_INCOME);

  return {
    revenue,
    salesReturns,
    netRevenue,
    cogs,
    grossProfit,
    expenses,
    totalExpenses,
    otherIncome,
    netProfit: grossProfit + otherIncome - totalExpenses,
  };
}

// ─────────────────── ترازنامه ───────────────────

export interface BalanceSheetSection {
  items: { code: string; name: string; amount: Rial }[];
  total: Rial;
}

export interface BalanceSheet {
  assets: BalanceSheetSection;
  liabilities: BalanceSheetSection;
  equity: BalanceSheetSection;
  netProfit: Rial;
  totalLiabilitiesAndEquity: Rial;
  balanced: boolean;
}

/**
 * ترازنامه — تصویر لحظه‌ای، نه گزارش دوره‌ای.
 *
 * ⚠️ `from` عمداً نادیده گرفته می‌شود. ترازنامه وضعیت دارایی و بدهی را
 * **در یک تاریخ** نشان می‌دهد، نه گردش یک بازه. اگر بازه اعمال شود،
 * طلب سال گذشته از ترازنامه حذف می‌گردد و کاربر فکر می‌کند پولش را
 * گرفته است.
 */
export function balanceSheet(
  entries: JournalEntry[],
  index: AccountIndex,
  filter: LedgerFilter = {},
): BalanceSheet {
  const asOf: LedgerFilter = { ...filter, from: undefined };
  const balances = accountBalances(entries, index, asOf);
  const leaf = (t: AccountType) =>
    balances
      .filter((b) => b.type === t && b.balance !== 0)
      .filter((b) => index.children(b.accountId).length === 0)
      .map((b) => ({ code: b.code, name: b.name, amount: b.balance }));

  const assetItems = leaf('asset');
  const liabilityItems = leaf('liability');
  const equityItems = leaf('equity');

  const assets = { items: assetItems, total: addMoney(...assetItems.map((i) => i.amount)) };
  const liabilities = {
    items: liabilityItems,
    total: addMoney(...liabilityItems.map((i) => i.amount)),
  };

  /**
   * سود دوره تا زمانی که بسته نشده، بخشی از حقوق صاحبان سرمایه است.
   *
   * ⚠️ اینجا برخلاف گزارش سود و زیان، سند اختتامیه **باید** شمرده شود.
   * پس از بستن سال، سود به «سود انباشته» منتقل شده و در `equityItems`
   * آمده است؛ اگر دوباره از صورت سود و زیان جمع شود، سرمایه دو برابر
   * می‌شود و ترازنامه از توازن خارج می‌گردد. مانده‌های زیر شامل سند
   * اختتامیه‌اند، پس فقط سود **بسته‌نشده** باقی می‌ماند.
   */
  const unclosedProfit = balances
    .filter((b) => b.type === 'income' || b.type === 'expense')
    .filter((b) => index.children(b.accountId).length === 0)
    .reduce((s, b) => (b.type === 'income' ? s + b.balance : s - b.balance), 0);

  const equityTotal = addMoney(...equityItems.map((i) => i.amount), unclosedProfit);
  const equity = { items: equityItems, total: equityTotal };

  const totalLiabilitiesAndEquity = addMoney(liabilities.total, equity.total);

  return {
    assets,
    liabilities,
    equity,
    netProfit: unclosedProfit,
    totalLiabilitiesAndEquity,
    balanced: assets.total === totalLiabilitiesAndEquity,
  };
}

// ─────────────────── بدهکاران و بستانکاران ───────────────────

export interface PartyBalanceRow {
  partyId: ID;
  name: string;
  kind: Party['kind'];
  phone?: string;
  /** مثبت = بدهکار (از ما طلب داریم)، منفی = بستانکار */
  balance: Rial;
}

export interface DebtorsCreditors {
  debtors: PartyBalanceRow[];
  creditors: PartyBalanceRow[];
  totalDebt: Rial;
  totalCredit: Rial;
  net: Rial;
}

/**
 * بدهکاران و بستانکاران — مانده‌ای، نه دوره‌ای.
 *
 * ⚠️ `from` عمداً نادیده گرفته می‌شود. طلب یک مانده است نه گردش؛ اگر
 * بازه اعمال شود، فاکتور نسیهٔ سال گذشته از فهرست بدهکاران غایب
 * می‌شود و کاربر پول وصول‌نشده را طلبکار نمی‌ماند.
 */
export function debtorsAndCreditors(
  entries: JournalEntry[],
  index: AccountIndex,
  parties: Party[],
  filter: LedgerFilter = {},
): DebtorsCreditors {
  const accountIds = [
    index.id(A.RECEIVABLE),
    index.id(A.PAYABLE),
    index.id(A.CHEQUE_RECEIVED),
    index.id(A.CHEQUE_ISSUED),
  ];
  // سند انتقال به سال بعد قرینه دارد و در مانده خنثی است، ولی کنار
  // گذاشتنش از دوباره‌شماری در بازه‌های نیم‌بند جلوگیری می‌کند
  const map = partyBalances(entries, accountIds, { ...filter, from: undefined });

  const rows: PartyBalanceRow[] = [];
  for (const p of parties) {
    const bal = map.get(p.id) ?? 0;
    if (bal === 0) continue;
    rows.push({ partyId: p.id, name: p.name, kind: p.kind, phone: p.phone, balance: bal });
  }

  const debtors = rows.filter((r) => r.balance > 0).sort((a, b) => b.balance - a.balance);
  const creditors = rows.filter((r) => r.balance < 0).sort((a, b) => a.balance - b.balance);
  const totalDebt = addMoney(...debtors.map((d) => d.balance));
  const totalCredit = Math.abs(addMoney(...creditors.map((c) => c.balance)));

  return { debtors, creditors, totalDebt, totalCredit, net: totalDebt - totalCredit };
}

// ─────────────────── دفتر روزنامه ───────────────────

export interface JournalRow {
  date: string;
  entryId: ID;
  number?: number;
  description: string;
  lines: { code: string; name: string; debit: Rial; credit: Rial }[];
  total: Rial;
}

export function journal(
  entries: JournalEntry[],
  index: AccountIndex,
  filter: LedgerFilter = {},
): JournalRow[] {
  return activeEntries(entries, filter)
    .sort((a, b) =>
      a.date === b.date ? a.createdAt.localeCompare(b.createdAt) : a.date.localeCompare(b.date),
    )
    .map((e) => ({
      date: e.date,
      entryId: e.id,
      number: e.number,
      description: e.description,
      lines: e.lines.map((l) => {
        const a = index.get(l.accountId);
        return {
          code: a?.code ?? '—',
          name: a?.name ?? 'حساب نامشخص',
          debit: l.debit,
          credit: l.credit,
        };
      }),
      total: addMoney(...e.lines.map((l) => l.debit)),
    }));
}

// ─────────────────── مرور حساب‌ها ───────────────────

export interface AccountOverviewNode {
  accountId: ID;
  code: string;
  name: string;
  type: AccountType;
  debit: Rial;
  credit: Rial;
  balance: Rial;
  children: AccountOverviewNode[];
}

/** درخت حساب‌ها با مانده تجمیعی زیرمجموعه‌ها */
export function accountOverview(
  entries: JournalEntry[],
  index: AccountIndex,
  filter: LedgerFilter = {},
): AccountOverviewNode[] {
  const balances = new Map(accountBalances(entries, index, filter).map((b) => [b.accountId, b]));

  const build = (parentId: ID | null): AccountOverviewNode[] =>
    index
      .children(parentId)
      .sort((a, b) => a.code.localeCompare(b.code))
      .map((a) => {
        const children = build(a.id);
        const own = balances.get(a.id);
        const debit = addMoney(own?.debit ?? 0, ...children.map((c) => c.debit));
        const credit = addMoney(own?.credit ?? 0, ...children.map((c) => c.credit));
        const sign = a.type === 'asset' || a.type === 'expense' ? 1 : -1;
        return {
          accountId: a.id,
          code: a.code,
          name: a.name,
          type: a.type,
          debit,
          credit,
          balance: (debit - credit) * sign,
          children,
        };
      });

  return build(null);
}

// ─────────────────── صورتحساب سرمایه ───────────────────

export interface CapitalStatement {
  /** مانده سرمایه و سود انباشته پیش از آغاز بازه */
  opening: Rial;
  /** سرمایهٔ آوردهٔ همین دوره */
  contributed: Rial;
  netProfit: Rial;
  drawings: Rial;
  closing: Rial;
}

/**
 * صورتحساب سرمایه.
 *
 * ⚠️ «سرمایهٔ اول دوره» یعنی مانده **پیش از شروع** بازه، نه گردش داخل
 * آن. قبلاً با همان فیلتر بازه محاسبه می‌شد و همیشه صفر درمی‌آمد، پس
 * سرمایهٔ آوردهٔ سال‌های قبل در گزارش دیده نمی‌شد.
 */
export function capitalStatement(
  entries: JournalEntry[],
  index: AccountIndex,
  filter: LedgerFilter = {},
): CapitalStatement {
  const equityOf = (f: LedgerFilter) => {
    const b = accountBalances(entries, index, f);
    const find = (code: string) => b.find((x) => x.code === code)?.balance ?? 0;
    return { capital: find(A.CAPITAL), retained: find(A.RETAINED), drawings: find(A.DRAWINGS) };
  };

  // مانده تا یک روز پیش از آغاز بازه
  let openingTo: string | undefined;
  if (filter.from) {
    const d = new Date(filter.from);
    d.setDate(d.getDate() - 1);
    openingTo = d.toISOString().slice(0, 10);
  }

  const before = filter.from
    ? equityOf({ ...filter, from: undefined, to: openingTo })
    : { capital: 0, retained: 0, drawings: 0 };
  const during = equityOf(filter);

  const opening = before.capital + before.retained;
  // برداشت و آوردهٔ همین دوره
  const drawings = Math.abs(during.drawings);
  const netProfit = incomeStatement(entries, index, filter).netProfit;
  const contributed = during.capital;

  return {
    opening,
    contributed,
    netProfit,
    drawings,
    closing: opening + contributed + netProfit - drawings,
  };
}

// ─────────────────── داشبورد ───────────────────

export interface DashboardSummary {
  todaySales: Rial;
  monthSales: Rial;
  monthProfit: Rial;
  cashBalance: Rial;
  receivable: Rial;
  payable: Rial;
  overdueCheques: number;
}

export function dashboard(
  entries: JournalEntry[],
  index: AccountIndex,
  opts: { today: string; monthFrom: string; monthTo: string; overdueCheques?: number },
): DashboardSummary {
  const dayPl = incomeStatement(entries, index, { from: opts.today, to: opts.today });
  const monthPl = incomeStatement(entries, index, { from: opts.monthFrom, to: opts.monthTo });
  const all = accountBalances(entries, index, {});
  const find = (code: string) => all.find((b) => b.code === code)?.balance ?? 0;

  return {
    todaySales: dayPl.netRevenue,
    monthSales: monthPl.netRevenue,
    monthProfit: monthPl.netProfit,
    cashBalance: addMoney(find(A.CASH), find(A.BANK), find(A.PETTY_CASH)),
    receivable: find(A.RECEIVABLE),
    payable: find(A.PAYABLE),
    overdueCheques: opts.overdueCheques ?? 0,
  };
}
