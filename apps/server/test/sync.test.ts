import { test, describe, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import type { PushChange } from '@javid/core';
import { openDB, latestSeq, serverLamport, type DB } from '../src/db.js';
import { createBusiness, newId, requestOtp, verifyOtp, roleOf, canWrite, addMember } from '../src/auth.js';
import { pull, push, shouldApply, snapshot, deviceCursor } from '../src/sync.js';

/**
 * آزمون‌های موتور همگام‌سازی.
 * تمرکز روی سه تضمین: idempotency، حل تعارض قطعی‌گرا، و اتمی بودن.
 */

let db: DB;
let userId: string;
let bizId: string;

beforeEach(() => {
  db = openDB(':memory:');
  userId = newId();
  db.prepare('INSERT INTO users (id, phone, created_at) VALUES (?, ?, ?)')
    .run(userId, '09120000000', new Date().toISOString());
  bizId = createBusiness(db, userId, 'فروشگاه آزمون').id;
});

function change(over: Partial<PushChange> = {}): PushChange {
  return {
    id: newId(),
    entity: 'party',
    entityId: 'e1',
    op: 'put',
    payload: { name: 'مشتری' },
    lamport: 1,
    deviceId: 'dev-a',
    at: '2026-07-29T10:00:00.000Z',
    ...over,
  };
}

// ─────────── ارسال ───────────

describe('ارسال تغییرات', () => {
  test('تغییر جدید اعمال می‌شود', () => {
    const c = change();
    const r = push(db, bizId, userId, [c]);
    assert.equal(r.accepted[0]?.outcome, 'applied');
    assert.equal(r.serverLamport, 1);
    assert.ok(r.cursor > 0);
  });

  test('ارسال مجدد همان تغییر رکورد تکراری نمی‌سازد', () => {
    const c = change();
    push(db, bizId, userId, [c]);
    const seqAfterFirst = latestSeq(db, bizId);

    const again = push(db, bizId, userId, [c]);
    assert.equal(again.accepted[0]?.outcome, 'duplicate');
    assert.equal(latestSeq(db, bizId), seqAfterFirst, 'دفتر نباید رشد کند');
  });

  test('ارسال دستهٔ بزرگ همه ثبت می‌شود', () => {
    const batch = Array.from({ length: 200 }, (_, i) =>
      change({ entityId: `e${i}`, lamport: i + 1 }));
    const r = push(db, bizId, userId, batch);
    assert.equal(r.accepted.filter((a) => a.outcome === 'applied').length, 200);
    assert.equal(r.serverLamport, 200);
  });

  test('دفتر حتی تغییر بازنده را هم ثبت می‌کند (ردّ ممیزی)', () => {
    push(db, bizId, userId, [change({ lamport: 5, deviceId: 'dev-a' })]);
    push(db, bizId, userId, [change({ lamport: 2, deviceId: 'dev-b' })]);

    const rows = db.prepare('SELECT COUNT(*) AS n FROM changes WHERE business_id = ?')
      .get(bizId) as unknown as { n: number };
    assert.equal(rows.n, 2, 'هر دو تغییر باید در دفتر باشند');

    const state = db.prepare('SELECT lamport FROM entity_state WHERE business_id = ? AND entity_id = ?')
      .get(bizId, 'e1') as unknown as { lamport: number };
    assert.equal(state.lamport, 5, 'ولی حالت باید برندهٔ تعارض باشد');
  });

  test('بستهٔ تغییرات اتمی است', () => {
    const good = change({ entityId: 'ok' });
    // ساعت منطقی رشتهٔ نامعتبر → درج SQL شکست می‌خورد
    const bad = { ...change({ entityId: 'bad' }), lamport: {} as unknown as number };

    assert.throws(() => push(db, bizId, userId, [good, bad]));

    const n = db.prepare('SELECT COUNT(*) AS n FROM changes WHERE business_id = ?')
      .get(bizId) as unknown as { n: number };
    assert.equal(n.n, 0, 'هیچ تغییری نباید ثبت شده باشد');
  });
});

// ─────────── حل تعارض ───────────

describe('حل تعارض', () => {
  test('ساعت منطقی بالاتر برنده است', () => {
    assert.equal(shouldApply(change({ lamport: 5 }), { lamport: 3, device_id: 'x', at: 'z' }), true);
    assert.equal(shouldApply(change({ lamport: 2 }), { lamport: 3, device_id: 'x', at: 'z' }), false);
  });

  test('در تساوی ساعت، زمان جدیدتر برنده است', () => {
    const cur = { lamport: 3, device_id: 'a', at: '2026-01-01T00:00:00Z' };
    assert.equal(shouldApply(change({ lamport: 3, at: '2026-06-01T00:00:00Z' }), cur), true);
    assert.equal(shouldApply(change({ lamport: 3, at: '2025-01-01T00:00:00Z' }), cur), false);
  });

  test('داوری نهایی با شناسهٔ دستگاه، قطعی‌گراست', () => {
    const at = '2026-01-01T00:00:00Z';
    const cur = { lamport: 3, device_id: 'bbb', at };
    assert.equal(shouldApply(change({ lamport: 3, at, deviceId: 'ccc' }), cur), true);
    assert.equal(shouldApply(change({ lamport: 3, at, deviceId: 'aaa' }), cur), false);
  });

  test('ترتیب رسیدن روی نتیجهٔ نهایی اثر ندارد', () => {
    const a = change({ entityId: 'x', lamport: 7, deviceId: 'dev-a', payload: { v: 'A' } });
    const b = change({ entityId: 'x', lamport: 4, deviceId: 'dev-b', payload: { v: 'B' } });

    // ترتیب اول
    push(db, bizId, userId, [a, b]);
    const s1 = snapshot(db, bizId).entities.party?.[0];

    // ترتیب معکوس روی پایگاه دادهٔ تازه
    const db2 = openDB(':memory:');
    const u2 = newId();
    db2.prepare('INSERT INTO users (id, phone, created_at) VALUES (?, ?, ?)')
      .run(u2, '09120000001', new Date().toISOString());
    const biz2 = createBusiness(db2, u2, 'دوم').id;
    push(db2, biz2, u2, [b, a]);
    const s2 = snapshot(db2, biz2).entities.party?.[0];

    assert.deepEqual(s1, s2, 'نتیجه باید مستقل از ترتیب باشد');
    assert.deepEqual(s1, { v: 'A' });
  });
});

// ─────────── دریافت ───────────

describe('دریافت تغییرات', () => {
  test('دستگاه تغییرات خودش را دریافت نمی‌کند', () => {
    push(db, bizId, userId, [change({ deviceId: 'dev-a', entityId: 'a1' })]);
    push(db, bizId, userId, [change({ deviceId: 'dev-b', entityId: 'b1' })]);

    const forA = pull(db, bizId, 0, 'dev-a');
    assert.equal(forA.changes.length, 1);
    assert.equal(forA.changes[0]?.entityId, 'b1');
  });

  test('همگام‌سازی افزایشی است', () => {
    push(db, bizId, userId, [change({ deviceId: 'dev-b', entityId: 'x1', lamport: 1 })]);
    const first = pull(db, bizId, 0, 'dev-a');
    assert.equal(first.changes.length, 1);

    // بدون تغییر جدید، چیزی برنمی‌گردد
    const second = pull(db, bizId, first.cursor, 'dev-a');
    assert.equal(second.changes.length, 0);

    push(db, bizId, userId, [change({ deviceId: 'dev-b', entityId: 'x2', lamport: 2 })]);
    const third = pull(db, bizId, first.cursor, 'dev-a');
    assert.equal(third.changes.length, 1);
    assert.equal(third.changes[0]?.entityId, 'x2');
  });

  test('صفحه‌بندی با hasMore کار می‌کند', () => {
    const batch = Array.from({ length: 30 }, (_, i) =>
      change({ deviceId: 'dev-b', entityId: `e${i}`, lamport: i + 1 }));
    push(db, bizId, userId, batch);

    const page1 = pull(db, bizId, 0, 'dev-a', 10);
    assert.equal(page1.changes.length, 10);
    assert.equal(page1.hasMore, true);

    const page2 = pull(db, bizId, page1.cursor, 'dev-a', 10);
    assert.equal(page2.changes.length, 10);
    assert.notEqual(page1.changes[0]?.id, page2.changes[0]?.id);

    const page3 = pull(db, bizId, page2.cursor, 'dev-a', 100);
    assert.equal(page3.changes.length, 10);
    assert.equal(page3.hasMore, false);
  });

  test('نشانک دستگاه ذخیره می‌شود', () => {
    push(db, bizId, userId, [change({ deviceId: 'dev-b' })]);
    const r = pull(db, bizId, 0, 'dev-a');
    assert.equal(deviceCursor(db, bizId, 'dev-a'), r.cursor);
  });

  test('حذف هم منتقل می‌شود', () => {
    push(db, bizId, userId, [change({ deviceId: 'dev-b', op: 'delete', payload: null, lamport: 3 })]);
    const r = pull(db, bizId, 0, 'dev-a');
    assert.equal(r.changes[0]?.op, 'delete');
    assert.equal(r.changes[0]?.payload, null);
  });

  test('کسب‌وکارها از هم جدا هستند', () => {
    const otherBiz = createBusiness(db, userId, 'دیگری').id;
    push(db, bizId, userId, [change({ deviceId: 'dev-b', entityId: 'mine' })]);

    assert.equal(pull(db, otherBiz, 0, 'dev-a').changes.length, 0, 'نشتی بین کسب‌وکارها');
    assert.equal(pull(db, bizId, 0, 'dev-a').changes.length, 1);
  });
});

// ─────────── تصویر لحظه‌ای ───────────

describe('تصویر لحظه‌ای', () => {
  test('فقط آخرین حالت هر موجودیت برمی‌گردد', () => {
    push(db, bizId, userId, [
      change({ entityId: 'p1', lamport: 1, payload: { name: 'قدیمی' } }),
      change({ entityId: 'p1', lamport: 2, payload: { name: 'جدید' } }),
      change({ entityId: 'p2', lamport: 3, payload: { name: 'دومی' } }),
    ]);

    const snap = snapshot(db, bizId);
    assert.equal(snap.entities.party?.length, 2);
    assert.ok(snap.entities.party?.some((p) => (p as { name: string }).name === 'جدید'));
    assert.ok(!snap.entities.party?.some((p) => (p as { name: string }).name === 'قدیمی'));
  });

  test('موجودیت حذف‌شده در تصویر نمی‌آید', () => {
    push(db, bizId, userId, [change({ entityId: 'p1', lamport: 1 })]);
    push(db, bizId, userId, [change({ entityId: 'p1', lamport: 2, op: 'delete', payload: null })]);
    assert.equal(snapshot(db, bizId).entities.party?.length ?? 0, 0);
  });

  test('موجودیت‌ها به تفکیک نوع گروه‌بندی می‌شوند', () => {
    push(db, bizId, userId, [
      change({ entity: 'party', entityId: 'a', lamport: 1 }),
      change({ entity: 'product', entityId: 'b', lamport: 2 }),
      change({ entity: 'invoice', entityId: 'c', lamport: 3 }),
    ]);
    const snap = snapshot(db, bizId);
    assert.equal(snap.entities.party?.length, 1);
    assert.equal(snap.entities.product?.length, 1);
    assert.equal(snap.entities.invoice?.length, 1);
  });
});

// ─────────── احراز هویت ───────────

describe('احراز هویت', () => {
  test('چرخهٔ کامل کد یک‌بارمصرف', () => {
    const req = requestOtp(db, '09121234567', true);
    assert.equal(req.ok, true);
    assert.ok(req.code, 'در حالت توسعه کد برگردانده می‌شود');

    const v = verifyOtp(db, '09121234567', req.code!, 'dev-1');
    assert.equal(v.ok, true);
    assert.ok(v.token);
    assert.equal(v.user?.phone, '09121234567');
  });

  test('کد اشتباه رد می‌شود', () => {
    requestOtp(db, '09121234567', true);
    const v = verifyOtp(db, '09121234567', '000000', 'dev-1');
    assert.equal(v.ok, false);
    assert.match(v.error ?? '', /صحیح نیست/);
  });

  test('پس از تلاش‌های زیاد قفل می‌شود', () => {
    const req = requestOtp(db, '09121234567', true);
    for (let i = 0; i < 5; i++) verifyOtp(db, '09121234567', '000000', 'dev-1');
    const v = verifyOtp(db, '09121234567', req.code!, 'dev-1');
    assert.equal(v.ok, false, 'حتی کد درست هم پس از قفل شدن رد می‌شود');
  });

  test('ارسال مجدد زودهنگام محدود می‌شود', () => {
    requestOtp(db, '09121234567', true);
    const again = requestOtp(db, '09121234567', true);
    assert.equal(again.ok, false);
    assert.ok(again.retryAfter > 0);
  });

  test('کد خام ذخیره نمی‌شود', () => {
    const req = requestOtp(db, '09121234567', true);
    const row = db.prepare('SELECT code_hash FROM otp_codes WHERE phone = ?')
      .get('09121234567') as unknown as { code_hash: string };
    assert.notEqual(row.code_hash, req.code);
    assert.equal(row.code_hash.length, 64, 'باید هش SHA-256 باشد');
  });

  test('شمارهٔ موبایل با قالب‌های مختلف پذیرفته می‌شود', () => {
    for (const p of ['09121234567', '+989121234567', '989121234567', '۰۹۱۲۱۲۳۴۵۶۷']) {
      const r = requestOtp(db, p, true);
      assert.equal(r.ok || r.retryAfter > 0, true, `قالب ${p} باید شناخته شود`);
      db.prepare('DELETE FROM otp_codes').run();
    }
  });

  test('کاربر موجود دوباره ساخته نمی‌شود', () => {
    const r1 = requestOtp(db, '09121234567', true);
    const v1 = verifyOtp(db, '09121234567', r1.code!, 'dev-1');
    db.prepare('DELETE FROM otp_codes').run();
    const r2 = requestOtp(db, '09121234567', true);
    const v2 = verifyOtp(db, '09121234567', r2.code!, 'dev-2');
    assert.equal(v1.user?.id, v2.user?.id);
  });
});

// ─────────── دسترسی ───────────

describe('نقش و دسترسی', () => {
  test('سازندهٔ کسب‌وکار مالک است', () => {
    assert.equal(roleOf(db, userId, bizId), 'owner');
  });

  test('کاربر بیرونی دسترسی ندارد', () => {
    const other = newId();
    db.prepare('INSERT INTO users (id, phone, created_at) VALUES (?, ?, ?)')
      .run(other, '09129999999', new Date().toISOString());
    assert.equal(roleOf(db, other, bizId), null);
  });

  test('فقط نقش‌های مجاز می‌توانند بنویسند', () => {
    assert.equal(canWrite('owner'), true);
    assert.equal(canWrite('accountant'), true);
    assert.equal(canWrite('salesperson'), true);
    assert.equal(canWrite('viewer'), false);
    assert.equal(canWrite(null), false);
  });

  test('افزودن کاربر با شمارهٔ موبایل', () => {
    const r = addMember(db, bizId, '09125555555', 'accountant');
    assert.equal(r.ok, true);
    const u = db.prepare('SELECT id FROM users WHERE phone = ?')
      .get('09125555555') as unknown as { id: string };
    assert.equal(roleOf(db, u.id, bizId), 'accountant');
  });

  test('تغییر نقش کاربر موجود', () => {
    addMember(db, bizId, '09125555555', 'salesperson');
    addMember(db, bizId, '09125555555', 'viewer');
    const u = db.prepare('SELECT id FROM users WHERE phone = ?')
      .get('09125555555') as unknown as { id: string };
    assert.equal(roleOf(db, u.id, bizId), 'viewer');
  });
});
