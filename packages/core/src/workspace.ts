import type { Business, ID, Membership, Role } from './types.js';

/**
 * ═══════════════════════════════════════════════════════════════
 *  چند کسب‌وکاره — multi-tenant سمت کلاینت
 * ═══════════════════════════════════════════════════════════════
 *
 * یک کاربر می‌تواند چند فروشگاه، شعبه یا شرکت داشته باشد و بین آن‌ها
 * جابه‌جا شود. الزام اصلی: **جداسازی کامل**. هیچ کوئری‌ای نباید
 * دادهٔ یک کسب‌وکار را در دیگری نشان دهد.
 *
 * این ماژول ابزار جداسازی و اعتبارسنجی را می‌دهد؛ ذخیره‌سازی
 * وظیفهٔ لایهٔ بالاتر است.
 */

export interface WorkspaceRef {
  id: ID;
  name: string;
  role: Role;
  /** آخرین باری که کاربر در این کسب‌وکار کار کرده */
  lastOpenedAt?: string;
  isActive?: boolean;
}

export const ROLE_LABELS: Record<Role, string> = {
  owner: 'مالک',
  accountant: 'حسابدار',
  salesperson: 'فروشنده',
  viewer: 'فقط مشاهده',
};

export const ROLE_DESCRIPTIONS: Record<Role, string> = {
  owner: 'دسترسی کامل، شامل مدیریت کاربران و بستن دورهٔ مالی',
  accountant: 'ثبت اسناد، گزارش‌گیری و تنظیمات مالی',
  salesperson: 'ثبت فاکتور و دریافت وجه',
  viewer: 'فقط مشاهده و گزارش‌گیری',
};

/** ترتیب قدرت نقش‌ها — برای مقایسه */
const ROLE_RANK: Record<Role, number> = {
  owner: 4,
  accountant: 3,
  salesperson: 2,
  viewer: 1,
};

export function roleAtLeast(role: Role | null, minimum: Role): boolean {
  if (!role) return false;
  return ROLE_RANK[role] >= ROLE_RANK[minimum];
}

// ─────────────────── اجازه‌ها ───────────────────

export type Permission =
  | 'invoice.create' | 'invoice.edit' | 'invoice.delete'
  | 'party.manage' | 'product.manage' | 'treasury.manage'
  | 'entry.manual' | 'report.view' | 'export.data'
  | 'settings.edit' | 'member.manage' | 'period.lock' | 'period.unlock'
  | 'tax.submit';

const ROLE_PERMISSIONS: Record<Role, Permission[]> = {
  owner: [
    'invoice.create', 'invoice.edit', 'invoice.delete',
    'party.manage', 'product.manage', 'treasury.manage',
    'entry.manual', 'report.view', 'export.data',
    'settings.edit', 'member.manage', 'period.lock', 'period.unlock',
    'tax.submit',
  ],
  accountant: [
    'invoice.create', 'invoice.edit', 'invoice.delete',
    'party.manage', 'product.manage', 'treasury.manage',
    'entry.manual', 'report.view', 'export.data',
    'settings.edit', 'period.lock', 'tax.submit',
  ],
  salesperson: [
    'invoice.create', 'invoice.edit',
    'party.manage', 'report.view', 'export.data',
  ],
  viewer: ['report.view', 'export.data'],
};

export const PERMISSION_LABELS: Record<Permission, string> = {
  'invoice.create': 'ثبت فاکتور',
  'invoice.edit': 'ویرایش فاکتور',
  'invoice.delete': 'حذف فاکتور',
  'party.manage': 'مدیریت اشخاص',
  'product.manage': 'مدیریت کالاها',
  'treasury.manage': 'مدیریت خزانه',
  'entry.manual': 'ثبت سند دستی',
  'report.view': 'مشاهدهٔ گزارش‌ها',
  'export.data': 'دریافت خروجی',
  'settings.edit': 'تغییر تنظیمات',
  'member.manage': 'مدیریت کاربران',
  'period.lock': 'بستن دورهٔ مالی',
  'period.unlock': 'بازکردن دورهٔ مالی',
  'tax.submit': 'ارسال به سامانهٔ مؤدیان',
};

/**
 * بررسی اجازه.
 *
 * ⚠️ توجه: `report.view` و `export.data` برای همهٔ نقش‌ها فعال است —
 * حتی «فقط مشاهده». این ادامهٔ تعهد اول است: دادهٔ کسب‌وکار نباید
 * پشت نقش هم قفل شود، فقط نوشتن محدود می‌گردد.
 */
export function hasPermission(role: Role | null, permission: Permission): boolean {
  if (!role) return false;
  return ROLE_PERMISSIONS[role].includes(permission);
}

export function permissionsOf(role: Role): Permission[] {
  return [...ROLE_PERMISSIONS[role]];
}

export function missingPermissionMessage(permission: Permission, role: Role | null): string {
  const label = PERMISSION_LABELS[permission];
  const roleName = role ? ROLE_LABELS[role] : 'بدون دسترسی';
  return `نقش «${roleName}» اجازهٔ «${label}» را ندارد`;
}

// ─────────────────── جداسازی داده ───────────────────

interface Scoped {
  businessId: ID;
}

/**
 * فیلتر کردن هر مجموعه به یک کسب‌وکار.
 *
 * این تابع ساده عمداً وجود دارد: هر جای کد که دادهٔ چند موجودیت را
 * می‌خواند باید از آن رد شود، تا فراموش کردن فیلتر سخت‌تر باشد.
 */
export function scopeTo<T extends Scoped>(items: T[], businessId: ID): T[] {
  return items.filter((i) => i.businessId === businessId);
}

/** بررسی نشتی داده — در آزمون‌ها و حالت توسعه مفید است */
export function assertScoped<T extends Scoped>(items: T[], businessId: ID, label = 'داده'): void {
  const stray = items.find((i) => i.businessId !== businessId);
  if (stray) {
    throw new Error(
      `نشتی داده در ${label}: رکوردی متعلق به کسب‌وکار دیگر یافت شد (${stray.businessId})`,
    );
  }
}

// ─────────────────── مدیریت فضاها ───────────────────

export function workspacesOf(
  memberships: Membership[],
  businesses: Business[],
  activeId?: ID | null,
): WorkspaceRef[] {
  const byId = new Map(businesses.map((b) => [b.id, b]));

  const out: WorkspaceRef[] = [];
  for (const m of memberships) {
    const b = byId.get(m.businessId);
    if (!b) continue;
    out.push({ id: b.id, name: b.name, role: m.role, isActive: b.id === activeId });
  }
  return out.sort((a, b) => a.name.localeCompare(b.name, 'fa'));
}

export function validateBusinessName(name: string, existing: string[]): string[] {
  const issues: string[] = [];
  const trimmed = name.trim();

  if (!trimmed) issues.push('نام کسب‌وکار الزامی است');
  if (trimmed.length > 100) issues.push('نام کسب‌وکار نباید بیش از ۱۰۰ نویسه باشد');
  if (existing.some((e) => e.trim() === trimmed)) {
    issues.push('کسب‌وکاری با این نام از قبل وجود دارد');
  }

  return issues;
}

/**
 * آیا حذف کسب‌وکار مجاز است؟
 * آخرین کسب‌وکار حذف نمی‌شود چون کاربر بدون فضای کاری می‌ماند.
 */
export function canDeleteWorkspace(
  workspaces: WorkspaceRef[],
  id: ID,
): { ok: boolean; reason?: string } {
  if (workspaces.length <= 1) {
    return { ok: false, reason: 'آخرین کسب‌وکار قابل حذف نیست' };
  }
  const w = workspaces.find((x) => x.id === id);
  if (!w) return { ok: false, reason: 'کسب‌وکار یافت نشد' };
  if (w.role !== 'owner') return { ok: false, reason: 'فقط مالک می‌تواند کسب‌وکار را حذف کند' };
  return { ok: true };
}
