import type { Rial } from './money.js';

/** شناسه‌ها در سمت کلاینت تولید می‌شوند (UUID) تا همگام‌سازی آفلاین ممکن باشد */
export type ID = string;

// ─────────────────────────── حساب‌ها ───────────────────────────

export type AccountType = 'asset' | 'liability' | 'equity' | 'income' | 'expense';

export interface Account {
  id: ID;
  businessId: ID;
  code: string;
  name: string;
  type: AccountType;
  parentId?: ID | null;
  isSystem?: boolean;
}

/** ماهیت حساب: بدهکار یا بستانکار */
export function normalBalance(type: AccountType): 'debit' | 'credit' {
  return type === 'asset' || type === 'expense' ? 'debit' : 'credit';
}

// ─────────────────────────── اشخاص ───────────────────────────

export type PartyKind = 'customer' | 'vendor' | 'shareholder' | 'employee';

export interface Party {
  id: ID;
  businessId: ID;
  kind: PartyKind;
  name: string;
  phone?: string;
  nationalId?: string;
  economicCode?: string;
  address?: string;
  /** مانده اول دوره: مثبت = بدهکار (طلب ما از او) */
  openingBalance: Rial;
  sharePercent?: number;
  note?: string;
  archived?: boolean;
}

// ─────────────────────────── کالا ───────────────────────────

export type ProductKind = 'goods' | 'service';

export interface Product {
  id: ID;
  businessId: ID;
  kind: ProductKind;
  name: string;
  sku?: string;
  barcode?: string;
  categoryId?: ID | null;
  unitMain: string;
  unitSub?: string;
  /** چند واحد فرعی در یک واحد اصلی */
  unitRatio?: number;
  buyPrice: Rial;
  sellPrice: Rial;
  openingQty: number;
  openingCost: Rial;
  minQty?: number;
  vatRate?: number;
  /** شناسهٔ کالا/خدمت سازمان امور مالیاتی — برای سامانهٔ مؤدیان */
  taxCode?: string;
  archived?: boolean;
}

// ─────────────────────────── فاکتور ───────────────────────────

export type InvoiceType =
  | 'quote'
  | 'sale'
  | 'purchase'
  | 'sale_return'
  | 'purchase_return'
  | 'waste';

export type InvoiceStatus = 'draft' | 'open' | 'partial' | 'paid' | 'void';

export interface InvoiceLine {
  id: ID;
  productId: ID;
  description?: string;
  qty: number;
  unit: string;
  unitPrice: Rial;
  /** تخفیف سطری به ریال */
  discount: Rial;
  vatRate: number;
  /** بهای تمام‌شده — هنگام ثبت محاسبه و قفل می‌شود */
  cogs?: Rial;
}

export interface Invoice {
  id: ID;
  businessId: ID;
  type: InvoiceType;
  number: string;
  partyId?: ID | null;
  date: string;
  dueDate?: string | null;
  isOfficial: boolean;
  lines: InvoiceLine[];
  /** تخفیف کلی روی کل فاکتور */
  discount: Rial;
  shipping: Rial;
  status: InvoiceStatus;
  note?: string;
  /** فاکتور اصلی، در فاکتورهای برگشتی — برای بازگرداندن کالا با بهای اصلی */
  sourceInvoiceId?: ID | null;
  createdAt: string;
  updatedAt: string;
  deletedAt?: string | null;
}

// ─────────────────────────── خزانه ───────────────────────────

export type TreasuryKind = 'bank' | 'cash' | 'petty_cash';

export interface Treasury {
  id: ID;
  businessId: ID;
  kind: TreasuryKind;
  name: string;
  bankName?: string;
  accountNumber?: string;
  iban?: string;
  openingBalance: Rial;
  archived?: boolean;
}

export type PaymentMethod = 'cash' | 'bank' | 'cheque';
export type TransactionKind = 'receive' | 'pay' | 'transfer' | 'expense' | 'income';

export interface Transaction {
  id: ID;
  businessId: ID;
  kind: TransactionKind;
  treasuryId: ID;
  toTreasuryId?: ID | null;
  partyId?: ID | null;
  invoiceId?: ID | null;
  accountId?: ID | null;
  amount: Rial;
  date: string;
  method: PaymentMethod;
  chequeId?: ID | null;
  description?: string;
  createdAt: string;
  deletedAt?: string | null;
}

// ─────────────────────────── چک ───────────────────────────

export type ChequeDirection = 'received' | 'issued';
export type ChequeStatus = 'pending' | 'cashed' | 'bounced' | 'spent' | 'void';

export interface Cheque {
  id: ID;
  businessId: ID;
  direction: ChequeDirection;
  number: string;
  bankName: string;
  sayadId?: string;
  amount: Rial;
  dueDate: string;
  partyId?: ID | null;
  treasuryId?: ID | null;
  status: ChequeStatus;
  invoiceId?: ID | null;
  note?: string;
  createdAt: string;
}

// ─────────────────────────── سند حسابداری ───────────────────────────

export interface JournalLine {
  accountId: ID;
  debit: Rial;
  credit: Rial;
  partyId?: ID | null;
  productId?: ID | null;
  /**
   * حساب خزانهٔ مربوط به این ردیف.
   * لازم است چون چند صندوق یا چند حساب بانکی همگی به یک حساب کل
   * می‌نشینند؛ بدون این فیلد نمی‌توان موجودی هرکدام را جدا کرد.
   */
  treasuryId?: ID | null;
  description?: string;
}

export type JournalSource =
  | 'invoice'
  | 'transaction'
  | 'cheque'
  /** سند افتتاحیهٔ کسب‌وکار — مانده‌های اول دوره که کاربر وارد کرده */
  | 'opening'
  /** سند اختتامیهٔ سال مالی */
  | 'closing'
  /**
   * سند انتقال مانده به سال بعد.
   * از `opening` جداست چون ثبت دوبارهٔ مانده‌های اول دوره، سند
   * افتتاحیهٔ قبلی را جایگزین می‌کند و نباید انتقال سال مالی را پاک کند.
   */
  | 'carryforward'
  | 'manual';

export interface JournalEntry {
  id: ID;
  businessId: ID;
  date: string;
  number?: number;
  sourceType: JournalSource;
  sourceId?: ID | null;
  description: string;
  lines: JournalLine[];
  createdAt: string;
  deletedAt?: string | null;
}

// ─────────────────────────── انبار ───────────────────────────

export interface StockMovement {
  id: ID;
  businessId: ID;
  productId: ID;
  /** مثبت = ورود، منفی = خروج (به واحد اصلی) */
  qty: number;
  unitCost: Rial;
  date: string;
  sourceType: 'invoice' | 'opening' | 'adjustment';
  sourceId?: ID | null;
}

// ─────────────────────────── کسب‌وکار ───────────────────────────

export type CostingMethod = 'fifo' | 'lifo' | 'weighted_average';

export interface Business {
  id: ID;
  name: string;
  logo?: string | null;
  address?: string;
  phone?: string;
  economicCode?: string;
  nationalId?: string;
  /** ماه شروع سال مالی (۱ = فروردین) */
  fiscalYearStartMonth: number;
  costingMethod: CostingMethod;
  defaultVatRate: number;
  currencyUnit: 'rial' | 'toman';
  createdAt: string;
}

export type Role = 'owner' | 'accountant' | 'salesperson' | 'viewer';

export interface Membership {
  userId: ID;
  businessId: ID;
  role: Role;
  permissions?: string[];
}

// ─────────────────────────── اشتراک ───────────────────────────

/**
 * تعهد جاوید: انقضای اشتراک فقط جلوی «ثبت رکورد جدید» را می‌گیرد.
 * خواندن، جستجو، چاپ و خروجی گرفتن همیشه آزاد است.
 */
export type SubscriptionStatus = 'trial' | 'active' | 'grace' | 'read_only';

export interface Subscription {
  businessId: ID;
  plan: string;
  startedAt: string;
  expiresAt: string;
  status: SubscriptionStatus;
}

export interface AuditLog {
  id: ID;
  businessId: ID;
  userId: ID;
  action: 'create' | 'update' | 'delete' | 'restore';
  entity: string;
  entityId: ID;
  before?: unknown;
  after?: unknown;
  at: string;
}
