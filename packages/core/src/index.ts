/**
 * جاوید — هستهٔ حسابداری
 *
 * این پکیج هیچ وابستگی‌ای به رابط کاربری، مرورگر یا پایگاه داده ندارد.
 * دلیل: تجربهٔ رقبا نشان داد چندپلتفرمی شدن با منطق گره‌خورده به UI
 * منجر به بازنویسی کامل و افت کیفیت می‌شود.
 *
 * سه تعهد قفل‌شده در معماری:
 *   ۱. دادهٔ کاربر هرگز گروگان گرفته نمی‌شود  → subscription.ts + export.ts
 *   ۲. برنامه بدون اینترنت کار می‌کند          → sync.ts
 *   ۳. منطق دامنه از رابط کاربری جداست        → همین پکیج
 */

export * from './money.js';
export * from './jalali.js';
export * from './types.js';
export * from './accounts.js';
export * from './ledger.js';
export * from './inventory.js';
export * from './invoice.js';
export * from './posting.js';
export * from './reports.js';
export * from './subscription.js';
export * from './sync.js';
export * from './export.js';
export * from './tax.js';
export * from './escpos.js';
export * from './protocol.js';
export * from './tax-transport.js';
export * from './audit.js';
export * from './workspace.js';
export * from './closing.js';
export * from './analytics.js';
export * from './health.js';
export * from './search.js';

export const VERSION = '0.1.0';
export const APP_NAME = 'جاوید';
