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

export function incomeStatement(
  entries: JournalEntry[],
  index: AccountIndex,
  filter: LedgerFilter = {},
): IncomeStatement {
  const balances = accountBalances(entries, index, filter);
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

export function balanceSheet(
  entries: JournalEntry[],
  index: AccountIndex,
  filter: LedgerFilter = {},
): BalanceSheet {
  const balances = accountBalances(entries, index, filter);
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

  // سود دوره تا زمانی که بسته نشده، بخشی از حقوق صاحبان سرمایه است
  const pl = incomeStatement(entries, index, filter);
  const equityTotal = addMoney(...equityItems.map((i) => i.amount), pl.netProfit);
  const equity = { items: equityItems, total: equityTotal };

  const totalLiabilitiesAndEquity = addMoney(liabilities.total, equity.total);

  return {
    assets,
    liabilities,
    equity,
    netProfit: pl.netProfit,
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
  const map = partyBalances(entries, accountIds, filter);

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
  opening: Rial;
  netProfit: Rial;
  drawings: Rial;
  closing: Rial;
}

export function capitalStatement(
  entries: JournalEntry[],
  index: AccountIndex,
  filter: LedgerFilter = {},
): CapitalStatement {
  const balances = accountBalances(entries, index, filter);
  const find = (code: string) => balances.find((b) => b.code === code)?.balance ?? 0;
  const opening = find(A.CAPITAL) + find(A.RETAINED);
  const drawings = Math.abs(find(A.DRAWINGS));
  const netProfit = incomeStatement(entries, index, filter).netProfit;
  return { opening, netProfit, drawings, closing: opening + netProfit - drawings };
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
