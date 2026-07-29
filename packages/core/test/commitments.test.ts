import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import {
  ALWAYS_ALLOWED, can, evaluateStatus, GRACE_DAYS,
  shouldRemind, subscriptionNotice, type Capability,
} from '../dist/subscription.js';
import {
  LamportClock, MemorySyncQueue, resolveConflict, syncStatus, uuid,
} from '../dist/sync.js';
import { createBackup, parseBackup, serializeBackup, toCSV, toExcelXML } from '../dist/export.js';
import type { Subscription } from '../dist/types.js';

const NOW = new Date('2026-07-29T10:00:00Z');

function sub(expiresAt: string, status: Subscription['status'] = 'active'): Subscription {
  return { businessId: 'b1', plan: 'monthly', startedAt: '2026-06-29', expiresAt, status };
}

/**
 * این آزمون‌ها تعهدات معماری را تضمین می‌کنند.
 * شکستن هرکدام یعنی نقض قولی که به کاربر داده‌ایم.
 */

describe('تعهد ۱ — دادهٔ کاربر گروگان گرفته نمی‌شود', () => {
  test('خواندن حتی بدون هیچ اشتراکی آزاد است', () => {
    for (const cap of ALWAYS_ALLOWED) {
      assert.equal(can(cap, null, NOW), true, `${cap} باید همیشه مجاز باشد`);
    }
  });

  test('خواندن پس از انقضای کامل هم آزاد است', () => {
    const expired = sub('2020-01-01');
    assert.equal(evaluateStatus(expired, NOW), 'read_only');
    for (const cap of ALWAYS_ALLOWED) {
      assert.equal(can(cap, expired, NOW), true, `${cap} باید پس از انقضا هم مجاز باشد`);
    }
  });

  test('خروجی گرفتن و پشتیبان هرگز قفل نمی‌شود', () => {
    const expired = sub('2020-01-01');
    assert.equal(can('export', expired, NOW), true);
    assert.equal(can('backup', expired, NOW), true);
    assert.equal(can('print', expired, NOW), true);
    assert.equal(can('report', expired, NOW), true);
  });

  test('فقط نوشتن پس از انقضا قفل می‌شود', () => {
    const expired = sub('2020-01-01');
    const writes: Capability[] = ['write', 'delete', 'sync_push'];
    for (const cap of writes) {
      assert.equal(can(cap, expired, NOW), false, `${cap} باید قفل باشد`);
    }
  });

  test('دورهٔ ارفاق پس از انقضا نوشتن را باز نگه می‌دارد', () => {
    const justExpired = sub('2026-07-26'); // ۳ روز پیش
    assert.equal(evaluateStatus(justExpired, NOW), 'grace');
    assert.equal(can('write', justExpired, NOW), true);
  });

  test('پس از پایان ارفاق نوشتن قفل می‌شود', () => {
    const old = sub('2026-07-01');
    assert.equal(evaluateStatus(old, NOW), 'read_only');
    assert.equal(can('write', old, NOW), false);
  });

  test('اطلاع‌رسانی پیش از انقضا انجام می‌شود', () => {
    assert.equal(shouldRemind(sub('2026-08-12'), NOW), true); // ۱۴ روز
    assert.equal(shouldRemind(sub('2026-08-05'), NOW), true); // ۷ روز
    assert.equal(shouldRemind(sub('2026-07-30'), NOW), true); // ۱ روز
    assert.equal(shouldRemind(sub('2026-09-30'), NOW), false);
  });

  test('پیام انقضا به کاربر اطمینان می‌دهد داده‌اش سالم است', () => {
    const n = subscriptionNotice(sub('2020-01-01'), NOW);
    assert.equal(n.level, 'expired');
    assert.equal(n.canWrite, false);
    assert.match(n.message, /دست‌نخورده|محفوظ/);
    assert.match(n.message, /چاپ|دریافت/);
  });

  test('هشدار پلکانی نزدیک انقضا', () => {
    assert.equal(subscriptionNotice(sub('2026-07-31'), NOW).level, 'critical');
    assert.equal(subscriptionNotice(sub('2026-08-04'), NOW).level, 'warning');
    assert.equal(subscriptionNotice(sub('2026-08-10'), NOW).level, 'info');
    assert.equal(subscriptionNotice(sub('2026-12-01'), NOW).level, 'none');
  });

  test('دورهٔ ارفاق دقیقاً هفت روز است', () => {
    assert.equal(GRACE_DAYS, 7);
  });
});

describe('تعهد ۲ — کار بدون اینترنت', () => {
  test('شناسه‌ها سمت کلاینت تولید می‌شوند و یکتا هستند', () => {
    const ids = new Set(Array.from({ length: 2000 }, () => uuid()));
    assert.equal(ids.size, 2000);
    assert.match([...ids][0]!, /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i);
  });

  test('ساعت لامپورت ترتیب علّی را حفظ می‌کند', () => {
    const c = new LamportClock();
    assert.equal(c.tick(), 1);
    assert.equal(c.tick(), 2);
    c.observe(10);
    assert.equal(c.tick(), 11);
    c.observe(5); // عقب‌تر، نباید اثر کند
    assert.equal(c.tick(), 12);
  });

  test('صف تغییرات آفلاین انباشته می‌شود', () => {
    const q = new MemorySyncQueue();
    q.enqueue({ entity: 'invoice', entityId: 'i1', op: 'put', payload: {}, lamport: 1, deviceId: 'd1', at: '' });
    q.enqueue({ entity: 'invoice', entityId: 'i2', op: 'put', payload: {}, lamport: 2, deviceId: 'd1', at: '' });
    assert.equal(q.size(), 2);
    const ids = q.pending().map((c) => c.id);
    q.markSynced(ids);
    assert.equal(q.size(), 0);
  });

  test('صف به ترتیب ساعت منطقی خارج می‌شود', () => {
    const q = new MemorySyncQueue();
    q.enqueue({ entity: 'a', entityId: '2', op: 'put', payload: {}, lamport: 5, deviceId: 'd', at: '' });
    q.enqueue({ entity: 'a', entityId: '1', op: 'put', payload: {}, lamport: 1, deviceId: 'd', at: '' });
    assert.deepEqual(q.pending().map((c) => c.lamport), [1, 5]);
  });

  test('فشرده‌سازی چند تغییر روی یک رکورد', () => {
    const q = new MemorySyncQueue();
    for (let i = 1; i <= 5; i++) {
      q.enqueue({ entity: 'invoice', entityId: 'i1', op: 'put', payload: { v: i }, lamport: i, deviceId: 'd', at: '' });
    }
    assert.equal(q.size(), 5);
    q.compact();
    assert.equal(q.size(), 1);
    assert.deepEqual(q.pending()[0]!.payload, { v: 5 });
  });

  test('حل تعارض بر اساس ساعت منطقی', () => {
    const r = resolveConflict(
      { id: 'x', lamport: 5, updatedAt: '2026-01-01' },
      { id: 'x', lamport: 3, updatedAt: '2026-06-01' },
    );
    assert.equal(r.resolution, 'local');
  });

  test('حل تعارض قطعی‌گراست — نتیجه روی همهٔ دستگاه‌ها یکسان', () => {
    const a = { id: 'x', lamport: 1, updatedAt: '2026-01-01', deviceId: 'aaa' };
    const b = { id: 'x', lamport: 1, updatedAt: '2026-01-01', deviceId: 'bbb' };
    assert.equal(resolveConflict(a, b).winner.deviceId, 'bbb');
    assert.equal(resolveConflict(b, a).winner.deviceId, 'bbb');
  });

  test('وضعیت آفلاین به کاربر اطمینان می‌دهد', () => {
    const q = new MemorySyncQueue();
    q.enqueue({ entity: 'a', entityId: '1', op: 'put', payload: {}, lamport: 1, deviceId: 'd', at: '' });
    const s = syncStatus(false, q);
    assert.equal(s.state, 'offline');
    assert.equal(s.pendingCount, 1);
    assert.match(s.message, /آفلاین/);

    assert.equal(syncStatus(true, new MemorySyncQueue()).state, 'synced');
  });
});

describe('خروجی داده', () => {
  test('CSV با BOM تولید می‌شود تا اکسل فارسی را درست بخواند', () => {
    const csv = toCSV([{ name: 'مشتری', amount: 1000 }], [
      { key: 'name', header: 'نام', value: (r) => r.name },
      { key: 'amount', header: 'مبلغ', value: (r) => r.amount },
    ]);
    assert.ok(csv.startsWith('\uFEFF'));
    assert.match(csv, /نام,مبلغ/);
    assert.match(csv, /مشتری,1000/);
  });

  test('CSV کاراکترهای خاص را فرار می‌دهد', () => {
    const csv = toCSV([{ v: 'a,b' }, { v: 'خط"نقل' }], [
      { key: 'v', header: 'مقدار', value: (r) => r.v },
    ]);
    assert.match(csv, /"a,b"/);
    assert.match(csv, /"خط""نقل"/);
  });

  test('اکسل راست‌به‌چپ تولید می‌شود', () => {
    const xml = toExcelXML([
      { name: 'فاکتورها', rows: [{ n: 1 }] as never[], columns: [{ key: 'n', header: 'شماره', value: (r: never) => (r as { n: number }).n }] },
    ]);
    assert.match(xml, /DisplayRightToLeft/);
    assert.match(xml, /شماره/);
  });

  test('پشتیبان کامل رفت و برگشت می‌کند', () => {
    const backup = createBackup({ name: 'فروشگاه' }, { invoices: [{ id: 'i1' }] });
    const restored = parseBackup(serializeBackup(backup));
    assert.equal(restored.format, 'javid-backup');
    assert.deepEqual(restored.data.invoices, [{ id: 'i1' }]);
  });

  test('فایل نامعتبر رد می‌شود', () => {
    assert.throws(() => parseBackup('{"format":"other"}'), /معتبر نیست/);
    assert.throws(() => parseBackup('{"format":"javid-backup","version":99}'), /نسخهٔ جدیدتر/);
  });
});
