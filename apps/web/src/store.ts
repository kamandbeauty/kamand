import {
  AccountIndex, createChartOfAccounts, defaultTreasuryAccount, LamportClock,
  MemorySyncQueue, postInvoice, postTransaction, stockMovementsFor,
  replayProduct, uuid, computeInvoice, consumeStock, invoiceLineUnitCost,
  buildElectronicInvoice, nextSerial, validateForTaxSystem,
  type Business, type Cheque, type Invoice, type JournalEntry, type Party,
  type Product, type StockMovement, type Subscription, type Transaction,
  type Treasury, type Account, type ID, type Rial,
  type TaxProfile, type TaxSubmission, type InvoiceSubjectType,
} from '@javid/core';

/**
 * لایهٔ داده — آفلاین-اول.
 * همهٔ نوشتن‌ها ابتدا محلی ذخیره می‌شوند، سپس در صف همگام‌سازی می‌روند.
 * localStorage فعلاً به‌جای IndexedDB/SQLite است؛ رابط یکسان می‌ماند.
 */

const KEY = 'javid:db:v1';

/**
 * دسترسی امن به حافظهٔ محلی.
 * در محیط‌هایی مثل رندر سمت سرور یا حالت خصوصی مرورگر، localStorage
 * ممکن است نباشد یا خطا بدهد؛ در آن صورت به حافظهٔ موقت برمی‌گردیم
 * تا برنامه هرگز به‌خاطر ذخیره‌سازی از کار نیفتد.
 */
const memoryStore = new Map<string, string>();

const storage = {
  get(key: string): string | null {
    try {
      if (typeof localStorage !== 'undefined') return localStorage.getItem(key);
    } catch { /* حالت خصوصی یا محدودیت دسترسی */ }
    return memoryStore.get(key) ?? null;
  },
  set(key: string, value: string): void {
    try {
      if (typeof localStorage !== 'undefined') {
        localStorage.setItem(key, value);
        return;
      }
    } catch { /* سهمیهٔ پر یا دسترسی مسدود */ }
    memoryStore.set(key, value);
  },
  remove(key: string): void {
    try {
      if (typeof localStorage !== 'undefined') localStorage.removeItem(key);
    } catch { /* نادیده */ }
    memoryStore.delete(key);
  },
};

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
  };
}

export function loadDB(): DB | null {
  try {
    const raw = storage.get(KEY);
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
  if (!Array.isArray(out.movements)) out.movements = [];
  if (!Array.isArray(out.entries)) out.entries = [];
  return out;
}

export function saveDB(db: DB): void {
  try {
    storage.set(KEY, JSON.stringify(db));
  } catch (e) {
    console.error('ذخیرهٔ محلی ناموفق بود', e);
  }
}

export function clearDB(): void {
  storage.remove(KEY);
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
  let id = storage.get('javid:device');
  if (!id) {
    id = uuid();
    storage.set('javid:device', id);
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

  return {
    ...db,
    invoices: [...db.invoices.filter((i) => i.id !== withCosts.id), withCosts],
    entries: entry ? [...db.entries, entry] : db.entries,
    movements: [...db.movements, ...movements],
  };
}

export function postTransactionToDB(db: DB, tx: Transaction): DB {
  const treasury = db.treasuries.find((t) => t.id === tx.treasuryId);
  if (!treasury) throw new Error('حساب خزانه یافت نشد');
  const to = tx.toTreasuryId ? db.treasuries.find((t) => t.id === tx.toTreasuryId) ?? null : null;

  const entry = postTransaction(tx, treasury, to, ctxOf(db));
  track('transaction', tx.id, tx);

  return {
    ...db,
    transactions: [...db.transactions, tx],
    entries: entry ? [...db.entries, entry] : db.entries,
  };
}

export function upsertParty(db: DB, party: Party): DB {
  track('party', party.id, party);
  const exists = db.parties.some((p) => p.id === party.id);
  return {
    ...db,
    parties: exists ? db.parties.map((p) => (p.id === party.id ? party : p)) : [...db.parties, party],
  };
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

  return {
    ...db,
    products: exists ? db.products.map((p) => (p.id === product.id ? product : p)) : [...db.products, product],
    movements,
  };
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
