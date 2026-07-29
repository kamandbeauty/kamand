import type { AuditLog, ID } from './types.js';
import { formatJalali } from './jalali.js';

/**
 * ═══════════════════════════════════════════════════════════════
 *  ردّ ممیزی و قفل دورهٔ مالی
 * ═══════════════════════════════════════════════════════════════
 *
 * در تحلیل بازار این دو مورد را «اجباری در نرم‌افزار مالی چندکاربره»
 * نوشتیم. دلیلش ساده است:
 *
 *  - وقتی چند نفر روی یک دفتر کار می‌کنند، باید بشود فهمید چه کسی
 *    چه چیزی را کِی تغییر داده. بدون آن، اختلاف بین شرکا حل‌نشدنی است.
 *  - وقتی سال مالی بسته و اظهارنامه داده شد، ویرایش سند آن دوره یعنی
 *    ناهماهنگی با چیزی که به سازمان امور مالیاتی اعلام شده.
 */

// ─────────────────── ردّ ممیزی ───────────────────

export const AUDITED_ENTITIES = [
  'invoice', 'party', 'product', 'transaction', 'cheque',
  'treasury', 'entry', 'business', 'account', 'membership',
] as const;

export type AuditedEntity = (typeof AUDITED_ENTITIES)[number];

export const ENTITY_LABELS: Record<AuditedEntity, string> = {
  invoice: 'فاکتور',
  party: 'شخص',
  product: 'کالا',
  transaction: 'تراکنش',
  cheque: 'چک',
  treasury: 'حساب خزانه',
  entry: 'سند حسابداری',
  business: 'کسب‌وکار',
  account: 'حساب',
  membership: 'دسترسی کاربر',
};

export const ACTION_LABELS: Record<AuditLog['action'], string> = {
  create: 'ایجاد',
  update: 'ویرایش',
  delete: 'حذف',
  restore: 'بازیابی',
};

/**
 * فیلدهایی که هرگز در ردّ ممیزی ذخیره نمی‌شوند.
 * ذخیرهٔ آن‌ها نه مفید است نه بی‌خطر.
 */
const REDACTED_KEYS = new Set(['token', 'password', 'privateKeyPem', 'code_hash', 'codeHash']);

function redact(value: unknown): unknown {
  if (value === null || typeof value !== 'object') return value;
  if (Array.isArray(value)) return value.map(redact);

  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
    out[k] = REDACTED_KEYS.has(k) ? '‹حذف‌شده›' : redact(v);
  }
  return out;
}

export interface FieldChange {
  field: string;
  before: unknown;
  after: unknown;
}

/**
 * تفاوت دو نسخه از یک رکورد.
 * فقط فیلدهای تغییرکرده نگه داشته می‌شوند تا ردّ ممیزی حجیم نشود.
 */
export function diffRecords(
  before: Record<string, unknown> | null | undefined,
  after: Record<string, unknown> | null | undefined,
): FieldChange[] {
  const changes: FieldChange[] = [];
  const keys = new Set([...Object.keys(before ?? {}), ...Object.keys(after ?? {})]);

  for (const key of keys) {
    if (key === 'updatedAt' || key === 'lamport') continue;
    const b = before?.[key];
    const a = after?.[key];
    if (JSON.stringify(b) !== JSON.stringify(a)) {
      changes.push({ field: key, before: redact(b), after: redact(a) });
    }
  }
  return changes;
}

export interface AuditInput {
  businessId: ID;
  userId: ID;
  action: AuditLog['action'];
  entity: AuditedEntity;
  entityId: ID;
  before?: Record<string, unknown> | null;
  after?: Record<string, unknown> | null;
  /** توضیح خوانا برای کاربر */
  summary?: string;
}

/**
 * فیلدهایی که برای شناسایی یک رکورد کافی‌اند.
 *
 * ⚠️ چرا خلاصه‌سازی لازم است: پیش‌تر هنگام ایجاد، **کل رکورد** در
 * ردّ ممیزی کپی می‌شد. یعنی هر فاکتور دو بار ذخیره می‌گشت و ردّ
 * ممیزی به بزرگ‌ترین مصرف‌کنندهٔ حافظه تبدیل می‌شد — با ۱۰۰۰ فاکتور
 * حدود ۱.۵ مگابایت، بیشتر از خود فاکتورها.
 *
 * ردّ ممیزی باید بگوید «چه کسی چه کاری کرد»، نه اینکه نسخهٔ دوم
 * دادگان باشد.
 */
const SUMMARY_KEYS = [
  'number', 'name', 'date', 'total', 'amount', 'status',
  'type', 'kind', 'phone', 'barcode', 'dueDate', 'description',
];

const MAX_SNAPSHOT_KEYS = 12;

/** خلاصهٔ رکورد برای ثبت در ردّ ممیزی */
export function summarizeRecord(
  record: Record<string, unknown> | null | undefined,
): Record<string, unknown> | null {
  if (!record) return null;

  const out: Record<string, unknown> = {};

  // فیلدهای شناسایی‌کننده در اولویت‌اند
  for (const key of SUMMARY_KEYS) {
    if (key in record && record[key] !== undefined && record[key] !== null) {
      out[key] = redact(record[key]);
    }
  }

  // فیلدهای سادهٔ دیگر تا سقف مشخص.
  // آرایه و شیء تودرتو حذف می‌شوند مگر فیلد حساس باشند — آن‌ها
  // باید صریحاً «حذف‌شده» علامت بخورند تا نبودشان عمدی به نظر برسد.
  for (const [k, v] of Object.entries(record)) {
    if (k in out || k === 'id' || k === 'businessId') continue;
    if (v === null || v === undefined) continue;

    if (REDACTED_KEYS.has(k)) {
      out[k] = '‹حذف‌شده›';
      continue;
    }
    if (Object.keys(out).length >= MAX_SNAPSHOT_KEYS) continue;
    if (typeof v === 'object') {
      // شیء تودرتو ذخیره نمی‌شود، ولی اگر داخلش راز باشد رد پایش می‌ماند
      const inner = redact(v);
      if (JSON.stringify(inner).includes('‹حذف‌شده›')) out[k] = inner;
      continue;
    }
    out[k] = v;
  }

  return out;
}

export function createAuditLog(input: AuditInput, id: ID, now: string): AuditLog {
  const changes = input.action === 'update'
    ? diffRecords(input.before, input.after)
    : undefined;

  return {
    id,
    businessId: input.businessId,
    userId: input.userId,
    action: input.action,
    entity: input.entity,
    entityId: input.entityId,
    before: input.action === 'update' ? changes : summarizeRecord(input.before),
    after: input.action === 'update' ? undefined : summarizeRecord(input.after),
    at: now,
  };
}

/** توضیح خوانای فارسی برای یک رکورد ردّ ممیزی */
export function describeAudit(log: AuditLog, userName?: string): string {
  const entity = ENTITY_LABELS[log.entity as AuditedEntity] ?? log.entity;
  const action = ACTION_LABELS[log.action] ?? log.action;
  const who = userName ? `${userName} ` : '';
  const when = formatJalali(new Date(log.at), 'long');
  return `${who}${entity} را ${action} کرد — ${when}`;
}

export interface AuditFilter {
  from?: string;
  to?: string;
  userId?: ID;
  entity?: AuditedEntity;
  entityId?: ID;
  action?: AuditLog['action'];
}

export function filterAudit(logs: AuditLog[], f: AuditFilter = {}): AuditLog[] {
  return logs
    .filter((l) => {
      if (f.from && l.at < f.from) return false;
      if (f.to && l.at > f.to) return false;
      if (f.userId && l.userId !== f.userId) return false;
      if (f.entity && l.entity !== f.entity) return false;
      if (f.entityId && l.entityId !== f.entityId) return false;
      if (f.action && l.action !== f.action) return false;
      return true;
    })
    .sort((a, b) => b.at.localeCompare(a.at));
}

/** تاریخچهٔ یک رکورد مشخص — «این فاکتور چه تغییراتی داشته؟» */
export function historyOf(logs: AuditLog[], entity: AuditedEntity, entityId: ID): AuditLog[] {
  return filterAudit(logs, { entity, entityId });
}

// ─────────────────── قفل دورهٔ مالی ───────────────────

export interface PeriodLock {
  businessId: ID;
  /** همهٔ اسناد تا این تاریخ قفل هستند (شامل خودش) */
  lockedThrough: string;
  lockedBy: ID;
  lockedAt: string;
  note?: string;
}

export class PeriodLockedError extends Error {
  readonly date: string;
  readonly lockedThrough: string;

  constructor(date: string, lockedThrough: string) {
    super(
      `دورهٔ مالی تا ${formatJalali(new Date(lockedThrough), 'long')} بسته شده است ` +
      `و امکان ثبت یا ویرایش در ${formatJalali(new Date(date), 'long')} وجود ندارد`,
    );
    this.name = 'PeriodLockedError';
    this.date = date;
    this.lockedThrough = lockedThrough;
  }
}

export function isDateLocked(date: string, lock: PeriodLock | null | undefined): boolean {
  if (!lock) return false;
  return date <= lock.lockedThrough;
}

export function assertNotLocked(date: string, lock: PeriodLock | null | undefined): void {
  if (isDateLocked(date, lock)) {
    throw new PeriodLockedError(date, lock!.lockedThrough);
  }
}

/**
 * آیا می‌توان دوره را تا این تاریخ بست؟
 * بستن دوره‌ای که اسناد نامتوازن دارد یا تاریخش آینده است، مجاز نیست.
 */
export function validateLockRequest(
  through: string,
  opts: { today: string; currentLock?: PeriodLock | null; unbalancedCount?: number },
): string[] {
  const issues: string[] = [];

  if (through > opts.today) {
    issues.push('نمی‌توان دوره‌ای در آینده را بست');
  }
  if (opts.currentLock && through < opts.currentLock.lockedThrough) {
    issues.push(
      `دوره هم‌اکنون تا ${formatJalali(new Date(opts.currentLock.lockedThrough), 'long')} بسته است؛ ` +
      'بازکردن دورهٔ بسته‌شده نیازمند تأیید مالک است',
    );
  }
  if (opts.unbalancedCount && opts.unbalancedCount > 0) {
    issues.push(`${opts.unbalancedCount} سند نامتوازن وجود دارد؛ ابتدا آن‌ها را اصلاح کنید`);
  }

  return issues;
}

/**
 * بازکردن قفل دوره.
 *
 * عمداً یک عملیات جداگانه و ثبت‌شونده است: بازکردن دورهٔ بسته‌شده
 * یعنی احتمال ناهماهنگی با اظهارنامهٔ ارسالی، پس باید ردّ ممیزی داشته باشد.
 */
export interface UnlockRequest {
  businessId: ID;
  userId: ID;
  reason: string;
  at: string;
}

export function validateUnlock(req: Partial<UnlockRequest>): string[] {
  const issues: string[] = [];
  if (!req.reason?.trim()) issues.push('ذکر دلیل بازکردن دوره الزامی است');
  if ((req.reason?.trim().length ?? 0) < 10) issues.push('دلیل باید حداقل ۱۰ نویسه باشد');
  return issues;
}
