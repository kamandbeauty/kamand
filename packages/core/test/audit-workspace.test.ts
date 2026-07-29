import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import {
  assertNotLocked, ACTION_LABELS, createAuditLog, describeAudit, diffRecords,
  ENTITY_LABELS, filterAudit, historyOf, isDateLocked, PeriodLockedError,
  validateLockRequest, validateUnlock, type PeriodLock,
} from '../dist/audit.js';
import {
  assertScoped, canDeleteWorkspace, hasPermission, missingPermissionMessage,
  permissionsOf, ROLE_LABELS, roleAtLeast, scopeTo, validateBusinessName,
  workspacesOf,
} from '../dist/workspace.js';
import type { AuditLog, Business, Membership, Role } from '../dist/types.js';

const NOW = '2026-07-29T10:00:00.000Z';

// ─────────── ردّ ممیزی ───────────

describe('ردّ ممیزی', () => {
  test('ایجاد رکورد با اطلاعات کامل', () => {
    const log = createAuditLog({
      businessId: 'b1', userId: 'u1', action: 'create',
      entity: 'invoice', entityId: 'inv-1',
      after: { number: 'F-1001', total: 500_000 },
    }, 'log-1', NOW);

    assert.equal(log.action, 'create');
    assert.equal(log.entity, 'invoice');
    assert.equal(log.userId, 'u1');
    assert.equal(log.at, NOW);
  });

  test('ویرایش فقط فیلدهای تغییرکرده را نگه می‌دارد', () => {
    const log = createAuditLog({
      businessId: 'b1', userId: 'u1', action: 'update',
      entity: 'party', entityId: 'p1',
      before: { name: 'قدیمی', phone: '0912', address: 'تهران' },
      after: { name: 'جدید', phone: '0912', address: 'تهران' },
    }, 'log-2', NOW);

    const changes = log.before as { field: string }[];
    assert.equal(changes.length, 1, 'فقط نام تغییر کرده');
    assert.equal(changes[0]?.field, 'name');
  });

  test('تفاوت‌گیری فیلدهای بی‌اهمیت را نادیده می‌گیرد', () => {
    const d = diffRecords(
      { name: 'الف', updatedAt: '2026-01-01', lamport: 1 },
      { name: 'الف', updatedAt: '2026-06-01', lamport: 9 },
    );
    assert.deepEqual(d, [], 'updatedAt و lamport نباید تغییر شمرده شوند');
  });

  test('فیلدهای حساس ذخیره نمی‌شوند', () => {
    const log = createAuditLog({
      businessId: 'b1', userId: 'u1', action: 'create',
      entity: 'business', entityId: 'b1',
      after: { name: 'فروشگاه', token: 'راز', privateKeyPem: 'کلید' },
    }, 'l', NOW);

    const after = log.after as Record<string, unknown>;
    assert.equal(after.name, 'فروشگاه');
    assert.equal(after.token, '‹حذف‌شده›');
    assert.equal(after.privateKeyPem, '‹حذف‌شده›');
  });

  test('فیلد حساس تودرتو هم پاک می‌شود', () => {
    const log = createAuditLog({
      businessId: 'b1', userId: 'u1', action: 'create',
      entity: 'business', entityId: 'b1',
      after: { config: { password: 'راز', name: 'ok' } },
    }, 'l', NOW);
    const after = log.after as { config: Record<string, unknown> };
    assert.equal(after.config.password, '‹حذف‌شده›');
    assert.equal(after.config.name, 'ok');
  });

  test('توضیح خوانای فارسی', () => {
    const log = createAuditLog({
      businessId: 'b1', userId: 'u1', action: 'delete',
      entity: 'invoice', entityId: 'i1',
    }, 'l', NOW);

    const text = describeAudit(log, 'آقای رضایی');
    assert.match(text, /آقای رضایی/);
    assert.match(text, /فاکتور/);
    assert.match(text, /حذف/);
    assert.match(text, /[۰-۹]/, 'تاریخ باید با ارقام فارسی باشد');
  });

  test('برچسب همهٔ موجودیت‌ها و عملیات فارسی است', () => {
    for (const label of Object.values(ENTITY_LABELS)) {
      assert.match(label, /[\u0600-\u06FF]/);
    }
    for (const label of Object.values(ACTION_LABELS)) {
      assert.match(label, /[\u0600-\u06FF]/);
    }
  });

  test('فیلتر بر اساس کاربر، موجودیت و بازه', () => {
    const logs: AuditLog[] = [
      { id: '1', businessId: 'b', userId: 'u1', action: 'create', entity: 'invoice', entityId: 'i1', at: '2026-01-01T00:00:00Z' },
      { id: '2', businessId: 'b', userId: 'u2', action: 'update', entity: 'party', entityId: 'p1', at: '2026-06-01T00:00:00Z' },
      { id: '3', businessId: 'b', userId: 'u1', action: 'delete', entity: 'invoice', entityId: 'i1', at: '2026-07-01T00:00:00Z' },
    ];

    assert.equal(filterAudit(logs, { userId: 'u1' }).length, 2);
    assert.equal(filterAudit(logs, { entity: 'invoice' }).length, 2);
    assert.equal(filterAudit(logs, { action: 'delete' }).length, 1);
    assert.equal(filterAudit(logs, { from: '2026-05-01T00:00:00Z' }).length, 2);
  });

  test('نتایج از جدید به قدیم مرتب می‌شوند', () => {
    const logs: AuditLog[] = [
      { id: '1', businessId: 'b', userId: 'u', action: 'create', entity: 'invoice', entityId: 'i', at: '2026-01-01T00:00:00Z' },
      { id: '2', businessId: 'b', userId: 'u', action: 'update', entity: 'invoice', entityId: 'i', at: '2026-07-01T00:00:00Z' },
    ];
    assert.equal(filterAudit(logs)[0]?.id, '2');
  });

  test('تاریخچهٔ یک رکورد مشخص', () => {
    const logs: AuditLog[] = [
      { id: '1', businessId: 'b', userId: 'u', action: 'create', entity: 'invoice', entityId: 'i1', at: '2026-01-01T00:00:00Z' },
      { id: '2', businessId: 'b', userId: 'u', action: 'update', entity: 'invoice', entityId: 'i2', at: '2026-02-01T00:00:00Z' },
    ];
    const h = historyOf(logs, 'invoice', 'i1');
    assert.equal(h.length, 1);
    assert.equal(h[0]?.id, '1');
  });
});

// ─────────── قفل دورهٔ مالی ───────────

describe('قفل دورهٔ مالی', () => {
  const lock: PeriodLock = {
    businessId: 'b1',
    lockedThrough: '2026-03-20',
    lockedBy: 'u1',
    lockedAt: NOW,
  };

  test('تاریخ داخل دورهٔ بسته قفل است', () => {
    assert.equal(isDateLocked('2026-01-15', lock), true);
    assert.equal(isDateLocked('2026-03-20', lock), true, 'خودِ تاریخ هم قفل است');
    assert.equal(isDateLocked('2026-03-21', lock), false);
  });

  test('بدون قفل، همه‌چیز باز است', () => {
    assert.equal(isDateLocked('2020-01-01', null), false);
    assert.equal(isDateLocked('2020-01-01', undefined), false);
  });

  test('ثبت در دورهٔ بسته خطای روشن می‌دهد', () => {
    assert.throws(
      () => assertNotLocked('2026-01-15', lock),
      (e: PeriodLockedError) => {
        assert.equal(e.name, 'PeriodLockedError');
        assert.match(e.message, /[۰-۹]/, 'تاریخ در پیام باید فارسی باشد');
        assert.match(e.message, /بسته شده/);
        return true;
      },
    );
  });

  test('ثبت خارج دورهٔ بسته مجاز است', () => {
    assert.doesNotThrow(() => assertNotLocked('2026-06-01', lock));
  });

  test('بستن دورهٔ آینده مجاز نیست', () => {
    const issues = validateLockRequest('2027-01-01', { today: '2026-07-29' });
    assert.ok(issues.some((i) => i.includes('آینده')));
  });

  test('عقب بردن قفل هشدار می‌دهد', () => {
    const issues = validateLockRequest('2026-01-01', {
      today: '2026-07-29',
      currentLock: lock,
    });
    assert.ok(issues.some((i) => i.includes('بازکردن')));
  });

  test('سند نامتوازن مانع بستن دوره می‌شود', () => {
    const issues = validateLockRequest('2026-06-01', {
      today: '2026-07-29',
      unbalancedCount: 3,
    });
    assert.ok(issues.some((i) => i.includes('نامتوازن')));
  });

  test('درخواست معتبر خطایی ندارد', () => {
    assert.deepEqual(validateLockRequest('2026-06-01', { today: '2026-07-29' }), []);
  });

  test('بازکردن دوره نیازمند دلیل است', () => {
    assert.ok(validateUnlock({ reason: '' }).length > 0);
    assert.ok(validateUnlock({ reason: 'کوتاه' }).length > 0);
    assert.deepEqual(validateUnlock({ reason: 'اصلاح خطای ثبت فاکتور شمارهٔ ۱۲۳' }), []);
  });
});

// ─────────── چند کسب‌وکاره ───────────

describe('نقش و اجازه', () => {
  test('مالک همهٔ اجازه‌ها را دارد', () => {
    assert.equal(hasPermission('owner', 'member.manage'), true);
    assert.equal(hasPermission('owner', 'period.unlock'), true);
    assert.equal(hasPermission('owner', 'invoice.delete'), true);
  });

  test('فروشنده اجازهٔ مدیریت کاربر ندارد', () => {
    assert.equal(hasPermission('salesperson', 'invoice.create'), true);
    assert.equal(hasPermission('salesperson', 'member.manage'), false);
    assert.equal(hasPermission('salesperson', 'settings.edit'), false);
  });

  test('حسابدار دوره را می‌بندد ولی باز نمی‌کند', () => {
    assert.equal(hasPermission('accountant', 'period.lock'), true);
    assert.equal(hasPermission('accountant', 'period.unlock'), false);
  });

  test('گزارش و خروجی برای همهٔ نقش‌ها آزاد است', () => {
    // ادامهٔ تعهد اول: دادهٔ کاربر پشت نقش هم قفل نمی‌شود
    for (const role of ['owner', 'accountant', 'salesperson', 'viewer'] as Role[]) {
      assert.equal(hasPermission(role, 'report.view'), true, `${role} باید گزارش ببیند`);
      assert.equal(hasPermission(role, 'export.data'), true, `${role} باید خروجی بگیرد`);
    }
  });

  test('فقط-مشاهده هیچ اجازهٔ نوشتنی ندارد', () => {
    const perms = permissionsOf('viewer');
    assert.ok(!perms.some((p) => p.includes('create') || p.includes('edit') || p.includes('delete')));
  });

  test('بدون نقش هیچ اجازه‌ای نیست', () => {
    assert.equal(hasPermission(null, 'report.view'), false);
  });

  test('مقایسهٔ سطح نقش', () => {
    assert.equal(roleAtLeast('owner', 'accountant'), true);
    assert.equal(roleAtLeast('salesperson', 'accountant'), false);
    assert.equal(roleAtLeast('viewer', 'viewer'), true);
    assert.equal(roleAtLeast(null, 'viewer'), false);
  });

  test('پیام نبود اجازه فارسی و گویاست', () => {
    const msg = missingPermissionMessage('member.manage', 'salesperson');
    assert.match(msg, /فروشنده/);
    assert.match(msg, /مدیریت کاربران/);
  });

  test('برچسب نقش‌ها فارسی است', () => {
    for (const label of Object.values(ROLE_LABELS)) {
      assert.match(label, /[\u0600-\u06FF]/);
    }
  });
});

describe('جداسازی داده', () => {
  const items = [
    { id: '1', businessId: 'b1', name: 'الف' },
    { id: '2', businessId: 'b2', name: 'ب' },
    { id: '3', businessId: 'b1', name: 'ج' },
  ];

  test('فیلتر فقط دادهٔ همان کسب‌وکار را می‌دهد', () => {
    const scoped = scopeTo(items, 'b1');
    assert.equal(scoped.length, 2);
    assert.ok(scoped.every((i) => i.businessId === 'b1'));
  });

  test('کسب‌وکار بدون داده، فهرست خالی می‌دهد', () => {
    assert.deepEqual(scopeTo(items, 'b3'), []);
  });

  test('نشتی داده تشخیص داده می‌شود', () => {
    assert.throws(() => assertScoped(items, 'b1'), /نشتی داده/);
    assert.doesNotThrow(() => assertScoped(scopeTo(items, 'b1'), 'b1'));
  });

  test('پیام نشتی، شناسهٔ متخلف را نشان می‌دهد', () => {
    assert.throws(() => assertScoped(items, 'b1', 'فاکتورها'), /b2/);
  });
});

describe('مدیریت فضاهای کاری', () => {
  const businesses: Business[] = [
    { id: 'b1', name: 'فروشگاه مرکزی', fiscalYearStartMonth: 1, costingMethod: 'fifo', defaultVatRate: 10, currencyUnit: 'toman', createdAt: NOW },
    { id: 'b2', name: 'شعبهٔ دوم', fiscalYearStartMonth: 1, costingMethod: 'fifo', defaultVatRate: 10, currencyUnit: 'toman', createdAt: NOW },
  ];
  const memberships: Membership[] = [
    { userId: 'u1', businessId: 'b1', role: 'owner' },
    { userId: 'u1', businessId: 'b2', role: 'accountant' },
  ];

  test('فهرست فضاها با نقش ساخته می‌شود', () => {
    const ws = workspacesOf(memberships, businesses, 'b1');
    assert.equal(ws.length, 2);
    assert.equal(ws.find((w) => w.id === 'b1')?.role, 'owner');
    assert.equal(ws.find((w) => w.id === 'b1')?.isActive, true);
    assert.equal(ws.find((w) => w.id === 'b2')?.isActive, false);
  });

  test('عضویت بدون کسب‌وکار نادیده گرفته می‌شود', () => {
    const ws = workspacesOf(
      [...memberships, { userId: 'u1', businessId: 'ghost', role: 'owner' }],
      businesses,
    );
    assert.equal(ws.length, 2);
  });

  test('اعتبارسنجی نام کسب‌وکار', () => {
    assert.ok(validateBusinessName('', []).length > 0);
    assert.ok(validateBusinessName('فروشگاه', ['فروشگاه']).some((i) => i.includes('وجود دارد')));
    assert.ok(validateBusinessName('x'.repeat(101), []).some((i) => i.includes('۱۰۰')));
    assert.deepEqual(validateBusinessName('فروشگاه جدید', ['قدیمی']), []);
  });

  test('آخرین کسب‌وکار حذف نمی‌شود', () => {
    const one = workspacesOf([memberships[0]!], [businesses[0]!]);
    const r = canDeleteWorkspace(one, 'b1');
    assert.equal(r.ok, false);
    assert.match(r.reason ?? '', /آخرین/);
  });

  test('فقط مالک حذف می‌کند', () => {
    const ws = workspacesOf(memberships, businesses);
    assert.equal(canDeleteWorkspace(ws, 'b2').ok, false, 'حسابدار نباید بتواند');
    assert.equal(canDeleteWorkspace(ws, 'b1').ok, true);
  });
});
