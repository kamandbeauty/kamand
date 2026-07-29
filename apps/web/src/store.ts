import {
  AccountIndex, createChartOfAccounts, defaultTreasuryAccount, LamportClock,
  MemorySyncQueue, postInvoice, postTransaction, stockMovementsFor,
  replayProduct, uuid, computeInvoice, consumeStock, invoiceLineUnitCost,
  buildElectronicInvoice, nextSerial, validateForTaxSystem,
  buildCorrection, historyOf, INVOICE_SUBJECTS, SUBJECT_LABELS,
  type InvoiceSubject,
  assertNotLocked, createAuditLog, hasPermission,
  checkIntegrity, closeFiscalYear, fiscalYearBounds, previewClosing, currentFiscalYear,
  postOpening, SYSTEM_ACCOUNTS, EntryBuilder, assertBalanced,
  createReturn, quoteToSale, nextInvoiceNumber,
  type JournalLine,
  type AuditLog, type AuditedEntity, type PeriodLock, type Permission, type Role,
  type Business, type Cheque, type Invoice, type JournalEntry, type Party,
  type Product, type StockMovement, type Subscription, type Transaction,
  type Treasury, type Account, type ID, type Rial,
  type TaxProfile, type TaxSubmission, type InvoiceSubjectType,
} from '@javid/core';

import * as storage from './storage.js';

export { initStorage, storageKind, STORAGE_LABELS, storageEstimate } from './storage.js';

/**
 * لایهٔ داده — آفلاین-اول.
 * همهٔ نوشتن‌ها ابتدا محلی ذخیره می‌شوند، سپس در صف همگام‌سازی می‌روند.
 * ذخیره‌سازی روی IndexedDB با سقوط تدریجی به localStorage و حافظهٔ موقت.
 */

const KEY = 'javid:db:v1';

export interface DB {
  business: Business;
  accounts: Account[];
  parties: Party[];
  products: Product[];
  invoices: Invoice[];
  transactions: Transaction[];
  cheques: Cheque[];
  treasuries: Treasury[];
  entries: JournalEntry[];
  movements: StockMovement[];
  subscription: Subscription;
  taxProfile: TaxProfile;
  taxSubmissions: TaxSubmission[];
  auditLogs: AuditLog[];
  periodLock: PeriodLock | null;
  /** نقش کاربر جاری در این کسب‌وکار */
  role: Role;
}

const today = () => new Date().toISOString().slice(0, 10);
const nowIso = () => new Date().toISOString();

export function createEmptyDB(name = 'کسب‌وکار من'): DB {
  const businessId = uuid();
  const business: Business = {
    id: businessId,
    name,
    fiscalYearStartMonth: 1,
    costingMethod: 'fifo',
    defaultVatRate: 10,
    currencyUnit: 'toman',
    createdAt: nowIso(),
  };

  const accounts = createChartOfAccounts(businessId, uuid);
  const treasuries: Treasury[] = [
    { id: uuid(), businessId, kind: 'cash', name: 'صندوق فروشگاه', openingBalance: 0 },
    { id: uuid(), businessId, kind: 'bank', name: 'حساب بانکی', bankName: 'ملت', openingBalance: 0 },
  ];

  const expires = new Date();
  expires.setDate(expires.getDate() + 10);

  return {
    business,
    accounts,
    treasuries,
    parties: [],
    products: [],
    invoices: [],
    transactions: [],
    cheques: [],
    entries: [],
    movements: [],
    subscription: {
      businessId,
      plan: 'trial',
      startedAt: nowIso(),
      expiresAt: expires.toISOString(),
      status: 'trial',
    },
    taxProfile: { memoryId: '', sellerTin: '', sellerType: 2, lastSerial: 0 },
    taxSubmissions: [],
    auditLogs: [],
    periodLock: null,
    role: 'owner',
  };
}

export async function loadDB(): Promise<DB | null> {
  try {
    const raw = await storage.getItem(KEY);
    if (!raw) return null;
    return migrate(JSON.parse(raw) as DB);
  } catch {
    return null;
  }
}

/**
 * مهاجرت خودکار دادهٔ ذخیره‌شده به شکل جدید.
 * درس‌گرفته از رقبا: مهاجرت باید خودکار و بی‌صدا باشد، نه یک فرم درخواست
 * که کاربر منتظر بماند تا پشتیبانی انجامش دهد.
 */
export function migrate(db: DB): DB {
  const out = { ...db };
  if (!out.taxProfile) {
    out.taxProfile = { memoryId: '', sellerTin: '', sellerType: 2, lastSerial: 0 };
  }
  if (!Array.isArray(out.taxSubmissions)) out.taxSubmissions = [];
  if (!Array.isArray(out.auditLogs)) out.auditLogs = [];
  if (out.periodLock === undefined) out.periodLock = null;
  if (!out.role) out.role = 'owner';
  if (!Array.isArray(out.movements)) out.movements = [];
  if (!Array.isArray(out.entries)) out.entries = [];
  return out;
}

/**
 * ذخیره‌سازی با فشرده‌سازی نوشتن‌های پیاپی.
 * تایپ سریع کاربر نباید ده‌ها نوشتن پشت‌سرهم روی دیسک ایجاد کند.
 */
let saveTimer: ReturnType<typeof setTimeout> | null = null;
let pendingSave: DB | null = null;

export function saveDB(db: DB): void {
  pendingSave = db;
  if (saveTimer) clearTimeout(saveTimer);
  saveTimer = setTimeout(() => { void flushDB(); }, 250);
}

/** نوشتن فوری — پیش از بستن صفحه یا خروجی گرفتن */
export async function flushDB(): Promise<void> {
  if (saveTimer) { clearTimeout(saveTimer); saveTimer = null; }
  const db = pendingSave;
  if (!db) return;
  pendingSave = null;
  try {
    await storage.setItem(KEY, JSON.stringify(db));
  } catch (e) {
    console.error('ذخیرهٔ محلی ناموفق بود', e);
  }
}

export async function clearDB(): Promise<void> {
  if (saveTimer) { clearTimeout(saveTimer); saveTimer = null; }
  pendingSave = null;
  await storage.removeItem(KEY);
}

// ─────────── همگام‌سازی ───────────

export const clock = new LamportClock();
export const queue = new MemorySyncQueue();

function track(entity: string, entityId: ID, payload: unknown, op: 'put' | 'delete' = 'put') {
  queue.enqueue({
    entity, entityId, op, payload,
    lamport: clock.tick(),
    deviceId: deviceId(),
    at: nowIso(),
  });
}

export function deviceId(): string {
  let id = storage.getItemSync('javid:device');
  if (!id) {
    id = uuid();
    storage.setItemSync('javid:device', id);
  }
  return id;
}

// ─────────── عملیات دامنه ───────────

export function indexOf(db: DB): AccountIndex {
  return new AccountIndex(db.accounts);
}

function ctxOf(db: DB) {
  const index = indexOf(db);
  return {
    index,
    businessId: db.business.id,
    idGen: uuid,
    now: nowIso(),
    treasuryAccount: defaultTreasuryAccount(index),
  };
}

/** موجودی و بهای تمام‌شدهٔ یک کالا در لحظه */
export function stockOf(db: DB, productId: ID) {
  const ms = db.movements.filter((m) => m.productId === productId);
  return replayProduct(ms, db.business.costingMethod, { allowNegative: true });
}

/**
 * ثبت فاکتور: محاسبهٔ بهای تمام‌شده، تولید حرکات انبار و سند حسابداری.
 * این تنها نقطهٔ ورود ثبت فاکتور است تا دفتر همیشه سازگار بماند.
 */
export function postInvoiceToDB(db: DB, invoice: Invoice): DB {
  // دورهٔ بسته نباید سند جدید بپذیرد
  guardPeriod(db, invoice.date);
  const method = db.business.costingMethod;

  const outbound = invoice.type === 'sale' || invoice.type === 'waste';
  let cogsTotal: Rial = 0;
  const lineCosts = new Map<ID, Rial>();

  if (outbound) {
    // خروج از انبار: بها از لایه‌های موجودی مصرف می‌شود
    for (const line of invoice.lines) {
      const state = stockOf(db, line.productId);
      const r = consumeStock(state.layers, line.qty, method, {
        allowNegative: true,
        productId: line.productId,
      });
      lineCosts.set(line.id, r.cogs);
      cogsTotal += r.cogs;
    }
  } else if (invoice.type === 'sale_return') {
    // برگشت از فروش: کالا باید با بهای تمام‌شده برگردد، نه قیمت فروش.
    // اگر بهای اصلی روی ردیف نبود، از بهای جاری انبار استفاده می‌کنیم.
    for (const line of invoice.lines) {
      let c = line.cogs;
      if (c === undefined) {
        const st = stockOf(db, line.productId);
        const unit = st.qty > 0 ? Math.round(st.value / st.qty)
          : db.products.find((p) => p.id === line.productId)?.buyPrice ?? 0;
        c = unit * line.qty;
      }
      lineCosts.set(line.id, c);
      cogsTotal += c;
    }
  }

  const withCosts: Invoice = {
    ...invoice,
    lines: invoice.lines.map((l) =>
      lineCosts.has(l.id) ? { ...l, cogs: lineCosts.get(l.id) } : { ...l },
    ),
  };

  const ctx = ctxOf(db);
  const entry = postInvoice(withCosts, cogsTotal, ctx);

  const movements = stockMovementsFor(
    withCosts,
    { businessId: db.business.id, idGen: uuid },
    (l) => invoiceLineUnitCost(withCosts, l, lineCosts.get(l.id)),
  );

  track('invoice', withCosts.id, withCosts);

  const existing = db.invoices.find((i) => i.id === withCosts.id);
  const next: DB = {
    ...db,
    invoices: [...db.invoices.filter((i) => i.id !== withCosts.id), withCosts],
    entries: entry ? [...db.entries, entry] : db.entries,
    movements: [...db.movements, ...movements],
  };

  return audit(next, existing ? 'update' : 'create', 'invoice', withCosts.id, {
    before: existing as unknown as Record<string, unknown>,
    after: withCosts as unknown as Record<string, unknown>,
  });
}

export function postTransactionToDB(db: DB, tx: Transaction): DB {
  guardPeriod(db, tx.date);
  const treasury = db.treasuries.find((t) => t.id === tx.treasuryId);
  if (!treasury) throw new Error('حساب خزانه یافت نشد');
  const to = tx.toTreasuryId ? db.treasuries.find((t) => t.id === tx.toTreasuryId) ?? null : null;

  const entry = postTransaction(tx, treasury, to, ctxOf(db));
  track('transaction', tx.id, tx);

  const next: DB = {
    ...db,
    transactions: [...db.transactions, tx],
    entries: entry ? [...db.entries, entry] : db.entries,
  };
  return audit(next, 'create', 'transaction', tx.id, {
    after: tx as unknown as Record<string, unknown>,
  });
}

export function upsertParty(db: DB, party: Party): DB {
  track('party', party.id, party);
  const before = db.parties.find((p) => p.id === party.id);
  const next: DB = {
    ...db,
    parties: before ? db.parties.map((p) => (p.id === party.id ? party : p)) : [...db.parties, party],
  };
  return audit(next, before ? 'update' : 'create', 'party', party.id, {
    before: before as unknown as Record<string, unknown>,
    after: party as unknown as Record<string, unknown>,
  });
}

export function upsertProduct(db: DB, product: Product): DB {
  track('product', product.id, product);
  const exists = db.products.some((p) => p.id === product.id);
  let movements = db.movements;

  // موجودی اولیه یک حرکت انبار است
  if (!exists && product.openingQty > 0) {
    movements = [...movements, {
      id: uuid(),
      businessId: db.business.id,
      productId: product.id,
      qty: product.openingQty,
      unitCost: product.openingCost || product.buyPrice,
      date: today(),
      sourceType: 'opening' as const,
      sourceId: null,
    }];
  }

  const before = db.products.find((p) => p.id === product.id);
  const next: DB = {
    ...db,
    products: exists ? db.products.map((p) => (p.id === product.id ? product : p)) : [...db.products, product],
    movements,
  };
  return audit(next, before ? 'update' : 'create', 'product', product.id, {
    before: before as unknown as Record<string, unknown>,
    after: product as unknown as Record<string, unknown>,
  });
}

export function upsertCheque(db: DB, cheque: Cheque): DB {
  track('cheque', cheque.id, cheque);
  const exists = db.cheques.some((c) => c.id === cheque.id);
  return {
    ...db,
    cheques: exists ? db.cheques.map((c) => (c.id === cheque.id ? cheque : c)) : [...db.cheques, cheque],
  };
}

export function upsertTreasury(db: DB, t: Treasury): DB {
  track('treasury', t.id, t);
  const exists = db.treasuries.some((x) => x.id === t.id);
  return {
    ...db,
    treasuries: exists ? db.treasuries.map((x) => (x.id === t.id ? t : x)) : [...db.treasuries, t],
  };
}

/** مبلغ تسویه‌شدهٔ یک فاکتور */
export function paidOf(db: DB, invoiceId: ID): Rial {
  return db.transactions
    .filter((t) => t.invoiceId === invoiceId && !t.deletedAt)
    .reduce((s, t) => s + t.amount, 0);
}

export function invoiceTotal(inv: Invoice): Rial {
  return computeInvoice(inv).grandTotal;
}


// ─────────── سامانهٔ مؤدیان ───────────

/** آیا این فاکتور آمادهٔ ارسال به سامانه است؟ */
export function taxReadiness(db: DB, invoice: Invoice, subjectType: InvoiceSubjectType = 1) {
  const buyer = db.parties.find((p) => p.id === invoice.partyId) ?? null;
  const products = new Map(db.products.map((p) => [p.id, p]));
  return validateForTaxSystem(invoice, buyer, products, db.taxProfile, subjectType);
}

export function submissionFor(db: DB, invoiceId: ID): TaxSubmission | undefined {
  return db.taxSubmissions.find((s) => s.invoiceId === invoiceId && s.status !== 'cancelled');
}

/**
 * صدور صورتحساب الکترونیکی و قرار دادن آن در صف ارسال.
 * ارسال واقعی به سامانه در فاز بک‌اند انجام می‌شود؛ اینجا سند ساخته،
 * اعتبارسنجی و صف می‌شود تا آفلاین هم کار کند.
 */
export function issueElectronicInvoice(
  db: DB,
  invoice: Invoice,
  subjectType: InvoiceSubjectType = 1,
): { db: DB; submission: TaxSubmission } {
  const buyer = db.parties.find((p) => p.id === invoice.partyId) ?? null;
  const products = new Map(db.products.map((p) => [p.id, p]));
  const serial = nextSerial(db.taxProfile);

  const doc = buildElectronicInvoice({
    invoice, business: db.business, buyer, products,
    profile: db.taxProfile, serial, subjectType,
  });

  const submission: TaxSubmission = {
    id: uuid(),
    businessId: db.business.id,
    invoiceId: invoice.id,
    taxId: doc.header.taxid,
    serial,
    subject: doc.header.ins,
    pattern: doc.header.inp,
    subjectType,
    status: 'queued',
    createdAt: nowIso(),
  };

  track('tax_submission', submission.id, { submission, doc });

  return {
    db: {
      ...db,
      taxProfile: { ...db.taxProfile, lastSerial: serial },
      taxSubmissions: [...db.taxSubmissions, submission],
    },
    submission,
  };
}

export function updateTaxProfile(db: DB, profile: TaxProfile): DB {
  track('tax_profile', db.business.id, profile);
  return { ...db, taxProfile: profile };
}


// ─────────── ردّ ممیزی و قفل دوره ───────────

/** کاربر جاری — تا وقتی حساب ابری نساخته، محلی است */
export function currentUserId(): ID {
  let id = storage.getItemSync('javid:user');
  if (!id) {
    id = uuid();
    storage.setItemSync('javid:user', id);
  }
  return id;
}

/**
 * ثبت رویداد در ردّ ممیزی.
 * فهرست عمداً محدود نگه داشته می‌شود تا حافظهٔ دستگاه پر نشود؛
 * رکوردهای قدیمی‌تر در پشتیبان باقی می‌مانند.
 */
const AUDIT_LIMIT = 2000;

export function audit(
  db: DB,
  action: AuditLog['action'],
  entity: AuditedEntity,
  entityId: ID,
  data: { before?: Record<string, unknown> | null; after?: Record<string, unknown> | null } = {},
): DB {
  const log = createAuditLog(
    {
      businessId: db.business.id,
      userId: currentUserId(),
      action, entity, entityId,
      before: data.before ?? null,
      after: data.after ?? null,
    },
    uuid(),
    nowIso(),
  );

  const logs = [...db.auditLogs, log];
  return {
    ...db,
    auditLogs: logs.length > AUDIT_LIMIT ? logs.slice(-AUDIT_LIMIT) : logs,
  };
}

/** بررسی اجازه بر اساس نقش کاربر جاری */
export function can(db: DB, permission: Permission): boolean {
  return hasPermission(db.role, permission);
}

/**
 * بررسی قفل دوره پیش از هر نوشتن مالی.
 * پرتاب می‌کند تا فراموش کردنش سخت باشد.
 */
export function guardPeriod(db: DB, date: string): void {
  assertNotLocked(date, db.periodLock);
}

export function lockPeriod(db: DB, through: string, note?: string): DB {
  const lock: PeriodLock = {
    businessId: db.business.id,
    lockedThrough: through,
    lockedBy: currentUserId(),
    lockedAt: nowIso(),
    note,
  };
  track('period_lock', db.business.id, lock);
  return audit({ ...db, periodLock: lock }, 'update', 'business', db.business.id, {
    before: { lockedThrough: db.periodLock?.lockedThrough ?? null },
    after: { lockedThrough: through },
  });
}

export function unlockPeriod(db: DB, reason: string): DB {
  const before = db.periodLock?.lockedThrough ?? null;
  track('period_lock', db.business.id, null);
  return audit({ ...db, periodLock: null }, 'update', 'business', db.business.id, {
    before: { lockedThrough: before },
    after: { lockedThrough: null, reason },
  });
}


// ─────────── بستن سال مالی ───────────

/** سال‌های مالی بسته‌شده */
export function closedYears(db: DB): number[] {
  return db.entries
    .filter((e) => e.sourceType === 'closing' && !e.deletedAt)
    .map((e) => currentFiscalYear(new Date(e.date), db.business.fiscalYearStartMonth));
}

export function closingPreviewFor(db: DB, jy: number) {
  const bounds = fiscalYearBounds(jy, db.business.fiscalYearStartMonth);
  return {
    bounds,
    preview: previewClosing(db.entries, indexOf(db), {
      ...bounds,
      shareholders: db.parties.filter((p) => p.kind === 'shareholder'),
      today: today(),
      alreadyClosed: closedYears(db).includes(jy),
    }),
  };
}

/**
 * اجرای بستن سال.
 * پس از موفقیت، دوره خودکار قفل می‌شود تا اسناد بسته‌شده تغییر نکنند.
 */
export function closeYear(db: DB, jy: number, distributeProfit: boolean): DB {
  const bounds = fiscalYearBounds(jy, db.business.fiscalYearStartMonth);
  const ctx = { index: indexOf(db), businessId: db.business.id, idGen: uuid, now: nowIso() };

  const result = closeFiscalYear(db.entries, ctx, {
    ...bounds,
    shareholders: db.parties.filter((p) => p.kind === 'shareholder'),
    distributeProfit,
    today: today(),
    alreadyClosed: closedYears(db).includes(jy),
  });

  const added = [result.closingEntry, result.distributionEntry, result.openingEntry]
    .filter((e): e is NonNullable<typeof e> => e !== null);

  for (const e of added) track('entry', e.id, e);

  const withEntries: DB = { ...db, entries: [...db.entries, ...added] };
  const locked = lockPeriod(withEntries, result.lockThrough, `بستن ${bounds.label}`);

  return audit(locked, 'create', 'entry', added[0]?.id ?? db.business.id, {
    after: {
      عملیات: 'بستن سال مالی',
      سال: bounds.label,
      سود: result.netProfit,
      تعداد_سند: added.length,
    },
  });
}

/** بررسی سلامت دفتر */
export function integrityOf(db: DB) {
  return checkIntegrity(db.entries, indexOf(db));
}


// ─────────── مانده‌های اول دوره ───────────

/**
 * ثبت سند افتتاحیه از روی مانده‌های اول دورهٔ اشخاص، خزانه و کالا.
 *
 * ⚠️ چرا لازم است: کاربر مانده اول دوره را در فرم شخص یا حساب وارد
 * می‌کند، ولی تا وقتی سند افتتاحیه ثبت نشود آن مبلغ در دفتر نیست و
 * در گزارش بدهکاران دیده نمی‌شود. این تابع آن شکاف را می‌بندد.
 *
 * قابل اجرای مجدد است: سند افتتاحیهٔ قبلی جایگزین می‌شود، نه اینکه
 * روی هم انباشته گردد.
 */
export function postOpeningBalances(db: DB, date?: string): DB {
  const openingDate = date ?? openingDateOf(db);
  const index = indexOf(db);

  const entry = postOpening(
    {
      date: openingDate,
      parties: db.parties
        .filter((p) => !p.archived && p.openingBalance !== 0)
        .map((p) => ({ id: p.id, balance: p.openingBalance })),
      treasuries: db.treasuries
        .filter((t) => !t.archived && t.openingBalance !== 0)
        .map((t) => ({ treasury: t, balance: t.openingBalance })),
      inventoryValue: openingInventoryValue(db),
    },
    {
      index,
      businessId: db.business.id,
      idGen: uuid,
      now: nowIso(),
      treasuryAccount: defaultTreasuryAccount(index),
    },
  );

  // سند افتتاحیهٔ قبلی حذف می‌شود تا دوباره‌کاری نشود
  const withoutOld = db.entries.filter((e) => e.sourceType !== 'opening');
  const next: DB = {
    ...db,
    entries: entry ? [...withoutOld, entry] : withoutOld,
  };

  if (entry) track('entry', entry.id, entry);

  return audit(next, 'create', 'entry', entry?.id ?? db.business.id, {
    after: { عملیات: 'ثبت مانده‌های اول دوره', تاریخ: openingDate },
  });
}

/** ارزش موجودی اولیهٔ کالاها — از حرکات نوع opening */
export function openingInventoryValue(db: DB): Rial {
  return db.movements
    .filter((m) => m.sourceType === 'opening')
    .reduce((s, m) => s + Math.round(m.unitCost * m.qty), 0);
}

/** تاریخ پیش‌فرض سند افتتاحیه: ابتدای سال مالی جاری */
export function openingDateOf(db: DB): string {
  const jy = currentFiscalYear(new Date(), db.business.fiscalYearStartMonth);
  return fiscalYearBounds(jy, db.business.fiscalYearStartMonth).from;
}

export function hasOpeningEntry(db: DB): boolean {
  return db.entries.some((e) => e.sourceType === 'opening' && !e.deletedAt);
}

/** آیا مانده‌ای وارد شده که هنوز به دفتر نرفته؟ */
export function pendingOpeningBalances(db: DB): {
  parties: number;
  treasuries: number;
  inventory: Rial;
  total: number;
} {
  const parties = db.parties.filter((p) => !p.archived && p.openingBalance !== 0).length;
  const treasuries = db.treasuries.filter((t) => !t.archived && t.openingBalance !== 0).length;
  const inventory = openingInventoryValue(db);
  return { parties, treasuries, inventory, total: parties + treasuries + (inventory ? 1 : 0) };
}


// ─────────── سند دستی ───────────

export interface ManualLineInput {
  accountId: ID;
  debit: Rial;
  credit: Rial;
  partyId?: ID | null;
  description?: string;
}

/**
 * اعتبارسنجی سند دستی پیش از ثبت.
 * سند دستی تنها راهی است که کاربر مستقیماً به دفتر می‌نویسد،
 * پس اعتبارسنجی باید سخت‌گیرانه باشد.
 */
export function validateManualEntry(input: {
  date: string;
  description: string;
  lines: ManualLineInput[];
}): string[] {
  const errors: string[] = [];

  if (!input.description.trim()) errors.push('شرح سند الزامی است');

  const active = input.lines.filter((l) => l.debit > 0 || l.credit > 0);
  if (active.length < 2) errors.push('سند باید حداقل دو ردیف با مبلغ داشته باشد');

  input.lines.forEach((l, i) => {
    const n = i + 1;
    if (l.debit < 0 || l.credit < 0) errors.push(`ردیف ${n}: مبلغ منفی مجاز نیست`);
    if (l.debit > 0 && l.credit > 0) {
      errors.push(`ردیف ${n}: یک ردیف نمی‌تواند هم بدهکار باشد هم بستانکار`);
    }
    if ((l.debit > 0 || l.credit > 0) && !l.accountId) {
      errors.push(`ردیف ${n}: انتخاب حساب الزامی است`);
    }
  });

  const debit = active.reduce((s, l) => s + l.debit, 0);
  const credit = active.reduce((s, l) => s + l.credit, 0);
  if (debit !== credit) {
    errors.push(`سند متوازن نیست — اختلاف ${Math.abs(debit - credit).toLocaleString('en-US')}`);
  }
  if (debit === 0) errors.push('مبلغ سند نمی‌تواند صفر باشد');

  return errors;
}

/** ثبت سند دستی در دفتر */
export function postManualEntry(
  db: DB,
  input: { date: string; description: string; lines: ManualLineInput[] },
): DB {
  const errors = validateManualEntry(input);
  if (errors.length > 0) throw new Error(errors.join('؛ '));

  guardPeriod(db, input.date);

  const b = new EntryBuilder(db.business.id, input.date, input.description.trim(), 'manual', null);
  for (const l of input.lines) {
    const extra: Partial<JournalLine> = {};
    if (l.partyId) extra.partyId = l.partyId;
    if (l.description) extra.description = l.description;
    if (l.debit > 0) b.debit(l.accountId, l.debit, extra);
    else if (l.credit > 0) b.credit(l.accountId, l.credit, extra);
  }

  const entry = b.build(uuid(), nowIso());
  assertBalanced(entry.lines);
  track('entry', entry.id, entry);

  return audit({ ...db, entries: [...db.entries, entry] }, 'create', 'entry', entry.id, {
    after: {
      شرح: entry.description,
      تاریخ: entry.date,
      مبلغ: entry.lines.reduce((s, l) => s + l.debit, 0),
    },
  });
}

/** حذف نرم سند دستی — فقط سند دستی قابل حذف است */
export function voidManualEntry(db: DB, entryId: ID): DB {
  const entry = db.entries.find((e) => e.id === entryId);
  if (!entry) throw new Error('سند یافت نشد');
  if (entry.sourceType !== 'manual') {
    throw new Error('فقط سند دستی قابل حذف است؛ سند خودکار با اصلاح منبع آن تغییر می‌کند');
  }
  guardPeriod(db, entry.date);

  const next: DB = {
    ...db,
    entries: db.entries.map((e) => (e.id === entryId ? { ...e, deletedAt: nowIso() } : e)),
  };
  track('entry', entryId, { ...entry, deletedAt: nowIso() });

  return audit(next, 'delete', 'entry', entryId, {
    before: { شرح: entry.description, تاریخ: entry.date },
  });
}


// ─────────── تبدیل و برگشت فاکتور ───────────

const NUMBER_PREFIX: Record<Invoice['type'], string> = {
  sale: 'F', purchase: 'P', quote: 'Q',
  sale_return: 'RS', purchase_return: 'RP', waste: 'W',
};

export function nextNumberFor(db: DB, type: Invoice['type']): string {
  return nextInvoiceNumber(
    db.invoices.filter((i) => i.type === type).map((i) => i.number),
    NUMBER_PREFIX[type],
  );
}

/** تبدیل پیش‌فاکتور به فاکتور فروش */
export function convertQuote(db: DB, quoteId: ID): { db: DB; invoiceId: ID } {
  const quote = db.invoices.find((i) => i.id === quoteId);
  if (!quote) throw new Error('پیش‌فاکتور یافت نشد');
  if (quote.type !== 'quote') throw new Error('فقط پیش‌فاکتور قابل تبدیل است');

  const sale = quoteToSale(quote, uuid(), nextNumberFor(db, 'sale'), nowIso());
  const next = postInvoiceToDB(db, sale);

  return { db: next, invoiceId: sale.id };
}

/**
 * ساخت فاکتور برگشتی از روی فاکتور اصلی.
 *
 * ⚠️ چرا حتماً باید از فاکتور اصلی ساخته شود:
 * فاکتور برگشتی باید **بهای تمام‌شدهٔ اصلی** را با خود ببرد. اگر کاربر
 * برگشت را دستی بسازد، بهای جاری انبار استفاده می‌شود و اگر قیمت خرید
 * بین فروش و برگشت تغییر کرده باشد، سود دوره اشتباه محاسبه می‌گردد.
 */
export function createReturnFor(
  db: DB,
  sourceId: ID,
  lineQtys?: Map<ID, number>,
): { db: DB; invoiceId: ID } {
  const source = db.invoices.find((i) => i.id === sourceId);
  if (!source) throw new Error('فاکتور اصلی یافت نشد');
  if (source.type !== 'sale' && source.type !== 'purchase') {
    throw new Error('فقط از فاکتور فروش یا خرید می‌توان برگشت ساخت');
  }

  const type: Invoice['type'] = source.type === 'sale' ? 'sale_return' : 'purchase_return';
  const ret = createReturn(source, uuid(), nextNumberFor(db, type), nowIso(), lineQtys);

  return { db: postInvoiceToDB(db, ret), invoiceId: ret.id };
}

/** مقدار قبلاً برگشت‌خوردهٔ هر ردیف از یک فاکتور */
export function returnedQtyOf(db: DB, sourceId: ID): Map<ID, number> {
  const out = new Map<ID, number>();
  for (const inv of db.invoices) {
    if (inv.sourceInvoiceId !== sourceId || inv.deletedAt) continue;
    for (const l of inv.lines) {
      out.set(l.id, (out.get(l.id) ?? 0) + l.qty);
    }
  }
  return out;
}

/** آیا این فاکتور کاملاً برگشت خورده؟ */
export function isFullyReturned(db: DB, invoiceId: ID): boolean {
  const inv = db.invoices.find((i) => i.id === invoiceId);
  if (!inv) return false;
  const returned = returnedQtyOf(db, invoiceId);
  return inv.lines.every((l) => (returned.get(l.id) ?? 0) >= l.qty);
}


// ─────────── اصلاحیه و ابطالیهٔ سامانهٔ مؤدیان ───────────

/**
 * صدور صورتحساب اصلاحی، ابطالی یا برگشت از فروش.
 *
 * ⚠️ چرا لازم است: وقتی سامانه صورتحسابی را رد می‌کند یا کاربر
 * متوجه اشتباه می‌شود، تنها راه قانونی اصلاح، صدور صورتحساب جدید
 * با ارجاع به شمارهٔ مالیاتی اصلی است. بدون آن کاربر در بن‌بست
 * می‌ماند: خطا را می‌بیند ولی کاری نمی‌تواند بکند.
 */
export function issueCorrection(
  db: DB,
  originalSubmissionId: ID,
  subject: Extract<InvoiceSubject, 2 | 3 | 4>,
  replacementInvoiceId?: ID,
): { db: DB; submission: TaxSubmission } {
  const original = db.taxSubmissions.find((s) => s.id === originalSubmissionId);
  if (!original) throw new Error('صورتحساب اصلی یافت نشد');

  // برای اصلاحیه می‌توان فاکتور جایگزین داد؛ برای ابطالیه همان اصلی
  const invoiceId = replacementInvoiceId ?? original.invoiceId;
  const invoice = db.invoices.find((i) => i.id === invoiceId);
  if (!invoice) throw new Error('فاکتور مرتبط یافت نشد');

  const buyer = db.parties.find((p) => p.id === invoice.partyId) ?? null;
  const products = new Map(db.products.map((p) => [p.id, p]));
  const serial = nextSerial(db.taxProfile);

  const doc = buildCorrection(original, subject, {
    invoice,
    business: db.business,
    buyer,
    products,
    profile: db.taxProfile,
    serial,
    subjectType: original.subjectType,
  });

  const submission: TaxSubmission = {
    id: uuid(),
    businessId: db.business.id,
    invoiceId,
    taxId: doc.header.taxid,
    serial,
    subject,
    pattern: doc.header.inp,
    subjectType: original.subjectType,
    status: 'queued',
    referencedTaxId: original.taxId,
    createdAt: nowIso(),
  };

  track('tax_submission', submission.id, { submission, doc });

  // ابطالیه، صورتحساب اصلی را باطل می‌کند
  const updatedSubmissions = db.taxSubmissions.map((s) =>
    s.id === originalSubmissionId && subject === INVOICE_SUBJECTS.CANCELLING
      ? { ...s, status: 'cancelled' as const }
      : s,
  );

  const next: DB = {
    ...db,
    taxProfile: { ...db.taxProfile, lastSerial: serial },
    taxSubmissions: [...updatedSubmissions, submission],
  };

  const audited = audit(next, 'create', 'invoice', invoiceId, {
    after: {
      عملیات: SUBJECT_LABELS[subject],
      شماره_مالیاتی: submission.taxId,
      ارجاع_به: original.taxId,
    },
  });

  return { db: audited, submission };
}

/** آیا این صورتحساب اصلاحیه یا ابطالیه دارد؟ */
export function correctionsOf(db: DB, submissionId: ID): TaxSubmission[] {
  const original = db.taxSubmissions.find((s) => s.id === submissionId);
  if (!original) return [];
  return db.taxSubmissions.filter((s) => s.referencedTaxId === original.taxId);
}

/**
 * آیا صورتحساب قابل اصلاح است؟
 * فقط صورتحساب پذیرفته‌شده و باطل‌نشده.
 */
export function canCorrect(db: DB, submissionId: ID): { ok: boolean; reason?: string } {
  const s = db.taxSubmissions.find((x) => x.id === submissionId);
  if (!s) return { ok: false, reason: 'صورتحساب یافت نشد' };
  if (s.status === 'cancelled') return { ok: false, reason: 'این صورتحساب قبلاً باطل شده است' };
  if (s.status !== 'accepted') {
    return { ok: false, reason: 'فقط صورتحساب پذیرفته‌شده در سامانه قابل اصلاح یا ابطال است' };
  }
  return { ok: true };
}

// ─────────── تاریخچهٔ رکورد ───────────

/** تاریخچهٔ تغییرات یک رکورد مشخص — «این فاکتور چه اتفاقی برایش افتاده؟» */
export function recordHistory(db: DB, entity: AuditedEntity, entityId: ID) {
  return historyOf(db.auditLogs, entity, entityId);
}
