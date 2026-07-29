import type { Subscription, SubscriptionStatus } from './types.js';

/**
 * ═══════════════════════════════════════════════════════════════
 *  تعهد شمارهٔ ۱ جاوید: دادهٔ کاربر هرگز گروگان گرفته نمی‌شود.
 * ═══════════════════════════════════════════════════════════════
 *
 * این ماژول عمداً کوچک و صریح نوشته شده تا هیچ‌کس نتواند
 * ناخواسته دسترسیِ خواندن را پشت اشتراک قفل کند.
 *
 * پس از انقضای اشتراک:
 *   ✅ خواندن، جستجو، گزارش، چاپ و خروجی گرفتن → همیشه آزاد
 *   ⛔ فقط ثبت رکورد جدید و ویرایش → قفل
 *
 * دلیل: بزرگ‌ترین شکایت کاربران رقیب این بود که با تمام شدن
 * اشتراک، به دفتر حساب مشتریان خودشان دسترسی نداشتند.
 */

/** عملیاتی که هرگز قفل نمی‌شوند — این فهرست فقط می‌تواند بزرگ‌تر شود */
export const ALWAYS_ALLOWED = [
  'read',
  'search',
  'report',
  'print',
  'export',
  'backup',
  'login',
  'switch_business',
  'renew',
] as const;

export type Capability = (typeof ALWAYS_ALLOWED)[number] | 'write' | 'delete' | 'sync_push';

export const GRACE_DAYS = 7;

export function daysBetween(a: Date, b: Date): number {
  const MS = 86_400_000;
  const da = Date.UTC(a.getFullYear(), a.getMonth(), a.getDate());
  const db = Date.UTC(b.getFullYear(), b.getMonth(), b.getDate());
  return Math.round((db - da) / MS);
}

export function evaluateStatus(sub: Subscription, now: Date): SubscriptionStatus {
  const expires = new Date(sub.expiresAt);
  const remaining = daysBetween(now, expires);
  if (remaining >= 0) return sub.status === 'trial' ? 'trial' : 'active';
  if (remaining >= -GRACE_DAYS) return 'grace';
  return 'read_only';
}

export function can(capability: Capability, sub: Subscription | null, now: Date): boolean {
  // بدون اشتراک هم خواندن آزاد است — دادهٔ محلی متعلق به کاربر است
  if ((ALWAYS_ALLOWED as readonly string[]).includes(capability)) return true;
  if (!sub) return false;
  const status = evaluateStatus(sub, now);
  return status === 'trial' || status === 'active' || status === 'grace';
}

export interface SubscriptionNotice {
  level: 'none' | 'info' | 'warning' | 'critical' | 'expired';
  daysRemaining: number;
  message: string;
  canWrite: boolean;
}

/** اطلاع‌رسانی پیش از انقضا — در ۱۴، ۷، ۳ و ۱ روز مانده */
export const REMINDER_DAYS = [14, 7, 3, 1];

export function subscriptionNotice(sub: Subscription | null, now: Date): SubscriptionNotice {
  if (!sub) {
    return {
      level: 'expired',
      daysRemaining: 0,
      canWrite: false,
      message: 'اشتراک فعالی وجود ندارد. اطلاعات شما محفوظ است و می‌توانید آن‌ها را ببینید، چاپ کنید و خروجی بگیرید.',
    };
  }

  const remaining = daysBetween(now, new Date(sub.expiresAt));
  const status = evaluateStatus(sub, now);
  const canWrite = status !== 'read_only';

  if (status === 'read_only') {
    return {
      level: 'expired',
      daysRemaining: remaining,
      canWrite: false,
      message:
        'اشتراک شما به پایان رسیده است. همهٔ اطلاعات شما دست‌نخورده باقی مانده و همچنان می‌توانید آن‌ها را مشاهده، جستجو، چاپ و به صورت فایل دریافت کنید. برای ثبت رکورد جدید، اشتراک را تمدید کنید.',
    };
  }

  if (status === 'grace') {
    return {
      level: 'critical',
      daysRemaining: remaining,
      canWrite: true,
      message: `اشتراک شما منقضی شده است. تا ${GRACE_DAYS + remaining} روز دیگر همچنان می‌توانید اطلاعات ثبت کنید.`,
    };
  }

  if (remaining <= 3) {
    return {
      level: 'critical',
      daysRemaining: remaining,
      canWrite,
      message: `تنها ${remaining} روز تا پایان اشتراک باقی مانده است.`,
    };
  }

  if (remaining <= 7) {
    return {
      level: 'warning',
      daysRemaining: remaining,
      canWrite,
      message: `${remaining} روز تا پایان اشتراک باقی مانده است.`,
    };
  }

  if (remaining <= 14) {
    return {
      level: 'info',
      daysRemaining: remaining,
      canWrite,
      message: `${remaining} روز تا پایان اشتراک باقی مانده است.`,
    };
  }

  return { level: 'none', daysRemaining: remaining, canWrite, message: '' };
}

export function shouldRemind(sub: Subscription, now: Date): boolean {
  const remaining = daysBetween(now, new Date(sub.expiresAt));
  return REMINDER_DAYS.includes(remaining);
}

/** پیام صریح برای کاربر وقتی عملیات نوشتن قفل است */
export function writeBlockedMessage(): string {
  return (
    'برای ثبت اطلاعات جدید نیاز به اشتراک فعال دارید. ' +
    'اطلاعات فعلی شما همچنان کامل در دسترس است — می‌توانید آن‌ها را ببینید، ' +
    'چاپ کنید یا از بخش تنظیمات یک نسخهٔ کامل دریافت کنید.'
  );
}
