import { addMoney, type Rial } from './money.js';
import type { AccountType, ID, JournalEntry, JournalLine, JournalSource } from './types.js';
import { normalBalance } from './types.js';
import type { AccountIndex } from './accounts.js';

/**
 * موتور سند دوطرفه — قلب جاوید.
 * قاعدهٔ تخطی‌ناپذیر: جمع بدهکار = جمع بستانکار.
 * هیچ سندی که این شرط را نقض کند نباید وارد دفتر شود.
 */

export class UnbalancedEntryError extends Error {
  readonly debit: Rial;
  readonly credit: Rial;

  constructor(debit: Rial, credit: Rial) {
    super(`سند متوازن نیست: بدهکار ${debit} ≠ بستانکار ${credit}`);
    this.name = 'UnbalancedEntryError';
    this.debit = debit;
    this.credit = credit;
  }
}

export function sumDebit(lines: JournalLine[]): Rial {
  return addMoney(...lines.map((l) => l.debit));
}

export function sumCredit(lines: JournalLine[]): Rial {
  return addMoney(...lines.map((l) => l.credit));
}

export function assertBalanced(lines: JournalLine[]): void {
  const d = sumDebit(lines);
  const c = sumCredit(lines);
  if (d !== c) throw new UnbalancedEntryError(d, c);
  for (const l of lines) {
    if (l.debit < 0 || l.credit < 0) throw new Error('مبلغ منفی در ردیف سند مجاز نیست');
    if (l.debit > 0 && l.credit > 0) throw new Error('یک ردیف نمی‌تواند هم‌زمان بدهکار و بستانکار باشد');
  }
}

/** سازندهٔ سند با اعتبارسنجی خودکار */
export class EntryBuilder {
  private lines: JournalLine[] = [];
  private readonly businessId: ID;
  private readonly date: string;
  private readonly description: string;
  private readonly sourceType: JournalSource;
  private readonly sourceId: ID | null;

  constructor(
    businessId: ID,
    date: string,
    description: string,
    sourceType: JournalSource,
    sourceId?: ID | null,
  ) {
    this.businessId = businessId;
    this.date = date;
    this.description = description;
    this.sourceType = sourceType;
    this.sourceId = sourceId ?? null;
  }

  debit(accountId: ID, amount: Rial, extra: Partial<JournalLine> = {}): this {
    if (amount === 0) return this;
    if (amount < 0) return this.credit(accountId, -amount, extra);
    this.lines.push({ accountId, debit: amount, credit: 0, ...extra });
    return this;
  }

  credit(accountId: ID, amount: Rial, extra: Partial<JournalLine> = {}): this {
    if (amount === 0) return this;
    if (amount < 0) return this.debit(accountId, -amount, extra);
    this.lines.push({ accountId, debit: 0, credit: amount, ...extra });
    return this;
  }

  isEmpty(): boolean {
    return this.lines.length === 0;
  }

  build(id: ID, now: string): JournalEntry {
    assertBalanced(this.lines);
    if (this.lines.length < 2) throw new Error('سند باید حداقل دو ردیف داشته باشد');
    return {
      id,
      businessId: this.businessId,
      date: this.date,
      sourceType: this.sourceType,
      sourceId: this.sourceId ?? null,
      description: this.description,
      lines: this.lines,
      createdAt: now,
      deletedAt: null,
    };
  }
}

// ─────────────────────────── دفتر کل ───────────────────────────

export interface AccountBalance {
  accountId: ID;
  code: string;
  name: string;
  type: AccountType;
  debit: Rial;
  credit: Rial;
  /** مانده با علامت مثبت در جهت ماهیت حساب */
  balance: Rial;
}

export interface LedgerFilter {
  from?: string;
  to?: string;
  accountIds?: ID[];
  partyId?: ID;
}

function inRange(date: string, f?: string, t?: string): boolean {
  if (f && date < f) return false;
  if (t && date > t) return false;
  return true;
}

export function activeEntries(entries: JournalEntry[], filter: LedgerFilter = {}): JournalEntry[] {
  return entries.filter(
    (e) => !e.deletedAt && inRange(e.date, filter.from, filter.to),
  );
}

/** مانده تک‌تک حساب‌ها — پایهٔ تراز آزمایشی، ترازنامه و سود و زیان */
export function accountBalances(
  entries: JournalEntry[],
  index: AccountIndex,
  filter: LedgerFilter = {},
): AccountBalance[] {
  const acc = new Map<ID, { debit: Rial; credit: Rial }>();

  for (const e of activeEntries(entries, filter)) {
    for (const l of e.lines) {
      if (filter.accountIds && !filter.accountIds.includes(l.accountId)) continue;
      if (filter.partyId && l.partyId !== filter.partyId) continue;
      const cur = acc.get(l.accountId) ?? { debit: 0, credit: 0 };
      cur.debit = addMoney(cur.debit, l.debit);
      cur.credit = addMoney(cur.credit, l.credit);
      acc.set(l.accountId, cur);
    }
  }

  const out: AccountBalance[] = [];
  for (const [accountId, v] of acc) {
    const a = index.get(accountId);
    if (!a) continue;
    const sign = normalBalance(a.type) === 'debit' ? 1 : -1;
    out.push({
      accountId,
      code: a.code,
      name: a.name,
      type: a.type,
      debit: v.debit,
      credit: v.credit,
      balance: (v.debit - v.credit) * sign,
    });
  }
  return out.sort((x, y) => x.code.localeCompare(y.code));
}

export function balanceOf(
  entries: JournalEntry[],
  accountId: ID,
  filter: LedgerFilter = {},
): Rial {
  let debit = 0;
  let credit = 0;
  for (const e of activeEntries(entries, filter)) {
    for (const l of e.lines) {
      if (l.accountId !== accountId) continue;
      if (filter.partyId && l.partyId !== filter.partyId) continue;
      debit = addMoney(debit, l.debit);
      credit = addMoney(credit, l.credit);
    }
  }
  return debit - credit;
}

/** مانده به تفکیک شخص — پایهٔ گزارش بدهکاران و بستانکاران */
export function partyBalances(
  entries: JournalEntry[],
  accountIds: ID[],
  filter: LedgerFilter = {},
): Map<ID, Rial> {
  const out = new Map<ID, Rial>();
  for (const e of activeEntries(entries, filter)) {
    for (const l of e.lines) {
      if (!l.partyId) continue;
      if (!accountIds.includes(l.accountId)) continue;
      out.set(l.partyId, (out.get(l.partyId) ?? 0) + l.debit - l.credit);
    }
  }
  return out;
}

export interface LedgerRow {
  date: string;
  entryId: ID;
  description: string;
  debit: Rial;
  credit: Rial;
  running: Rial;
}

/** دفتر یک حساب با مانده تجمعی — «دفتر حساب‌ها» */
export function accountLedger(
  entries: JournalEntry[],
  accountId: ID,
  opening: Rial = 0,
  filter: LedgerFilter = {},
): LedgerRow[] {
  const rows: LedgerRow[] = [];
  let running = opening;
  const sorted = activeEntries(entries, filter).sort((a, b) =>
    a.date === b.date ? a.createdAt.localeCompare(b.createdAt) : a.date.localeCompare(b.date),
  );
  for (const e of sorted) {
    for (const l of e.lines) {
      if (l.accountId !== accountId) continue;
      if (filter.partyId && l.partyId !== filter.partyId) continue;
      running = running + l.debit - l.credit;
      rows.push({
        date: e.date,
        entryId: e.id,
        description: l.description ?? e.description,
        debit: l.debit,
        credit: l.credit,
        running,
      });
    }
  }
  return rows;
}
