import type { Change } from './sync.js';
import type { ID } from './types.js';

/**
 * ═══════════════════════════════════════════════════════════════
 *  قرارداد همگام‌سازی — مشترک بین کلاینت و سرور
 * ═══════════════════════════════════════════════════════════════
 *
 * این فایل تنها منبع حقیقت برای شکل پیام‌هاست. چون هر دو طرف از آن
 * استفاده می‌کنند، ناسازگاری بین کلاینت و سرور در زمان کامپایل گرفته
 * می‌شود، نه در زمان اجرا روی گوشی مغازه‌دار.
 *
 * اصول:
 *  ۱. همگام‌سازی افزایشی است — فقط تغییرات پس از آخرین نشانک منتقل می‌شود
 *  ۲. ارسال مجدد بی‌خطر است (idempotent) — قطعی وسط کار داده را خراب نمی‌کند
 *  ۳. سرور هرگز داده را حذف فیزیکی نمی‌کند — فقط پرچم حذف می‌زند
 */

export const PROTOCOL_VERSION = 1;

/** موجودیت‌هایی که همگام می‌شوند */
export const SYNCED_ENTITIES = [
  'party', 'product', 'invoice', 'transaction', 'cheque',
  'treasury', 'entry', 'movement', 'account', 'tax_submission',
] as const;

export type SyncedEntity = (typeof SYNCED_ENTITIES)[number];

export function isSyncedEntity(v: string): v is SyncedEntity {
  return (SYNCED_ENTITIES as readonly string[]).includes(v);
}

// ─────────────────── احراز هویت ───────────────────

export interface RequestOtpBody {
  phone: string;
}

export interface RequestOtpResult {
  sent: boolean;
  /** ثانیه تا امکان درخواست مجدد */
  retryAfter: number;
  /** فقط در محیط توسعه پر می‌شود */
  devCode?: string;
}

export interface VerifyOtpBody {
  phone: string;
  code: string;
  deviceId: string;
  deviceName?: string;
}

export interface AuthUser {
  id: ID;
  phone: string;
  name?: string;
}

export interface BusinessRef {
  id: ID;
  name: string;
  role: 'owner' | 'accountant' | 'salesperson' | 'viewer';
}

export interface VerifyOtpResult {
  token: string;
  user: AuthUser;
  businesses: BusinessRef[];
}

// ─────────────────── همگام‌سازی ───────────────────

/** یک تغییر آمادهٔ ارسال به سرور */
export interface PushChange {
  id: ID;
  entity: SyncedEntity;
  entityId: ID;
  op: 'put' | 'delete';
  payload: unknown;
  lamport: number;
  deviceId: string;
  at: string;
}

export interface PushBody {
  businessId: ID;
  deviceId: string;
  changes: PushChange[];
}

export type ChangeOutcome = 'applied' | 'duplicate' | 'superseded' | 'rejected';

export interface ChangeResult {
  id: ID;
  outcome: ChangeOutcome;
  reason?: string;
}

export interface PushResult {
  accepted: ChangeResult[];
  /** بالاترین ساعت منطقی که سرور دیده — کلاینت باید ساعتش را همگام کند */
  serverLamport: number;
  /** نشانک جدید برای درخواست بعدی */
  cursor: number;
}

export interface PullQuery {
  businessId: ID;
  /** فقط تغییرات پس از این نشانک */
  since: number;
  deviceId: string;
  limit?: number;
}

export interface ServerChange extends PushChange {
  /** شمارهٔ ترتیبی سرور — نشانک همگام‌سازی */
  seq: number;
}

export interface PullResult {
  changes: ServerChange[];
  cursor: number;
  /** آیا تغییرات بیشتری باقی مانده؟ */
  hasMore: boolean;
  serverLamport: number;
}

export const DEFAULT_PULL_LIMIT = 500;
export const MAX_PULL_LIMIT = 2000;
export const MAX_PUSH_CHANGES = 500;

// ─────────────────── خطاها ───────────────────

export const ERROR_CODES = {
  UNAUTHORIZED: 'unauthorized',
  FORBIDDEN: 'forbidden',
  NOT_FOUND: 'not_found',
  INVALID: 'invalid',
  RATE_LIMITED: 'rate_limited',
  CONFLICT: 'conflict',
  SERVER: 'server_error',
  PROTOCOL_MISMATCH: 'protocol_mismatch',
} as const;

export type ErrorCode = (typeof ERROR_CODES)[keyof typeof ERROR_CODES];

export interface ApiError {
  error: ErrorCode;
  message: string;
  details?: unknown;
}

/** پیام فارسی برای هر کد خطا — تا کاربر پیام انگلیسی نبیند */
export const ERROR_MESSAGES: Record<ErrorCode, string> = {
  unauthorized: 'برای ادامه باید وارد حساب کاربری شوید',
  forbidden: 'شما به این کسب‌وکار دسترسی ندارید',
  not_found: 'مورد درخواستی یافت نشد',
  invalid: 'اطلاعات ارسالی نامعتبر است',
  rate_limited: 'تعداد درخواست‌ها زیاد است، کمی بعد دوباره تلاش کنید',
  conflict: 'تعارض در داده‌ها رخ داد',
  server_error: 'خطای سرور — اطلاعات شما روی دستگاه محفوظ است',
  protocol_mismatch: 'نسخهٔ برنامه قدیمی است، لطفاً بروزرسانی کنید',
};

export function errorMessage(code: string): string {
  return ERROR_MESSAGES[code as ErrorCode] ?? 'خطای ناشناخته';
}

// ─────────────────── کمک‌ها ───────────────────

/** تبدیل تغییر محلی به شکل قابل ارسال */
export function toPushChange(c: Change): PushChange | null {
  if (!isSyncedEntity(c.entity)) return null;
  return {
    id: c.id,
    entity: c.entity,
    entityId: c.entityId,
    op: c.op,
    payload: c.payload,
    lamport: c.lamport,
    deviceId: c.deviceId,
    at: c.at,
  };
}

/**
 * اعتبارسنجی تغییر در سمت سرور.
 * سرور هرگز نباید به دادهٔ کلاینت اعتماد کند.
 */
export function validatePushChange(c: unknown): string | null {
  if (typeof c !== 'object' || c === null) return 'ساختار تغییر نامعتبر است';
  const x = c as Partial<PushChange>;

  if (typeof x.id !== 'string' || !x.id) return 'شناسهٔ تغییر الزامی است';
  if (typeof x.entityId !== 'string' || !x.entityId) return 'شناسهٔ موجودیت الزامی است';
  if (typeof x.entity !== 'string' || !isSyncedEntity(x.entity)) {
    return `موجودیت «${String(x.entity)}» قابل همگام‌سازی نیست`;
  }
  if (x.op !== 'put' && x.op !== 'delete') return 'نوع عملیات نامعتبر است';
  if (typeof x.lamport !== 'number' || !Number.isFinite(x.lamport) || x.lamport < 0) {
    return 'ساعت منطقی نامعتبر است';
  }
  if (typeof x.deviceId !== 'string' || !x.deviceId) return 'شناسهٔ دستگاه الزامی است';
  if (x.op === 'put' && (typeof x.payload !== 'object' || x.payload === null)) {
    return 'محتوای تغییر نامعتبر است';
  }
  return null;
}

export function validatePushBody(body: unknown): string | null {
  if (typeof body !== 'object' || body === null) return 'بدنهٔ درخواست نامعتبر است';
  const b = body as Partial<PushBody>;
  if (typeof b.businessId !== 'string' || !b.businessId) return 'شناسهٔ کسب‌وکار الزامی است';
  if (typeof b.deviceId !== 'string' || !b.deviceId) return 'شناسهٔ دستگاه الزامی است';
  if (!Array.isArray(b.changes)) return 'فهرست تغییرات الزامی است';
  if (b.changes.length > MAX_PUSH_CHANGES) {
    return `حداکثر ${MAX_PUSH_CHANGES} تغییر در هر درخواست مجاز است`;
  }
  for (const c of b.changes) {
    const err = validatePushChange(c);
    if (err) return err;
  }
  return null;
}

/** شمارهٔ موبایل ایرانی */
export function normalizePhone(input: string): string | null {
  const latin = input
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06f0))
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660))
    .replace(/[^\d+]/g, '');

  let d = latin;
  if (d.startsWith('+98')) d = '0' + d.slice(3);
  else if (d.startsWith('0098')) d = '0' + d.slice(4);
  else if (d.startsWith('98') && d.length === 12) d = '0' + d.slice(2);
  else if (d.startsWith('9') && d.length === 10) d = '0' + d;

  return /^09\d{9}$/.test(d) ? d : null;
}

export function maskPhone(phone: string): string {
  return phone.length === 11 ? `${phone.slice(0, 4)}***${phone.slice(-4)}` : phone;
}
