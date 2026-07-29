/**
 * آزمون سرتاسری همگام‌سازی: دو دستگاه، یک سرور واقعی.
 *
 * این مهم‌ترین آزمون این فاز است — ثابت می‌کند مغازه‌داری که روی
 * گوشی فاکتور می‌زند، همان فاکتور را روی تبلت صندوق می‌بیند.
 */
import { test, describe, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createApp } from '../../server/dist/src/http.js';

const merge = await import(new URL('../test-out/syncEngine.js', import.meta.url).href)
  .catch(() => null);

let server;
let base;
let app;

before(async () => {
  app = createApp({
    dev: true,
    rateLimit: { windowMs: 60_000, max: 100_000 },
    otpLimit: { windowMs: 60_000, perPhone: 100, perIp: 100_000 },
  });
  server = createServer((req, res) => { void app.handler(req, res); });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => {
  server.close();
  app.close();
});

async function call(path, { method = 'GET', body, token } = {}) {
  const res = await fetch(base + path, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  });
  return { status: res.status, body: await res.json().catch(() => null) };
}

async function signIn(phone, deviceId) {
  const otp = await call('/auth/otp', { method: 'POST', body: { phone } });
  const v = await call('/auth/verify', {
    method: 'POST',
    body: { phone, code: otp.body.devCode, deviceId },
  });
  return v.body.token;
}

const change = (over = {}) => ({
  id: `c-${Math.random().toString(36).slice(2)}`,
  entity: 'invoice',
  entityId: 'inv-1',
  op: 'put',
  payload: { number: 'F-1001', total: 500000 },
  lamport: 1,
  deviceId: 'phone',
  at: '2026-07-29T10:00:00.000Z',
  ...over,
});

describe('همگام‌سازی سرتاسری دو دستگاه', () => {
  test('فاکتور ثبت‌شده روی گوشی، روی تبلت دیده می‌شود', async () => {
    const token = await signIn('09141111111', 'phone');
    const biz = await call('/businesses', { method: 'POST', body: { name: 'مغازه' }, token });
    const bid = biz.body.id;

    // گوشی: ثبت فاکتور
    const pushed = await call('/sync/push', {
      method: 'POST', token,
      body: {
        businessId: bid, deviceId: 'phone',
        changes: [change({ payload: { number: 'F-2001', total: 750000 } })],
      },
    });
    assert.equal(pushed.body.accepted[0].outcome, 'applied');

    // تبلت: دریافت
    const pulled = await call(`/sync/pull?businessId=${bid}&deviceId=tablet&since=0`, { token });
    assert.equal(pulled.body.changes.length, 1);
    assert.equal(pulled.body.changes[0].payload.number, 'F-2001');
    assert.equal(pulled.body.changes[0].payload.total, 750000);
  });

  test('ویرایش همزمان دو دستگاه، نتیجهٔ یکسان می‌دهد', async () => {
    const token = await signIn('09142222222', 'phone');
    const biz = await call('/businesses', { method: 'POST', body: { name: 'م' }, token });
    const bid = biz.body.id;

    // هر دو دستگاه آفلاین یک رکورد را ویرایش کردند
    await call('/sync/push', {
      method: 'POST', token,
      body: {
        businessId: bid, deviceId: 'phone',
        changes: [change({ entityId: 'p1', entity: 'party', lamport: 3, deviceId: 'phone', payload: { name: 'از گوشی' } })],
      },
    });
    await call('/sync/push', {
      method: 'POST', token,
      body: {
        businessId: bid, deviceId: 'tablet',
        changes: [change({ entityId: 'p1', entity: 'party', lamport: 7, deviceId: 'tablet', payload: { name: 'از تبلت' } })],
      },
    });

    const snap = await call(`/sync/snapshot?businessId=${bid}`, { token });
    assert.equal(snap.body.entities.party.length, 1, 'باید یک رکورد بماند');
    assert.equal(snap.body.entities.party[0].name, 'از تبلت', 'ساعت منطقی بالاتر برنده');
  });

  test('کار آفلاین سپس همگام‌سازی انبوه', async () => {
    const token = await signIn('09143333333', 'phone');
    const biz = await call('/businesses', { method: 'POST', body: { name: 'م' }, token });
    const bid = biz.body.id;

    // شبیه‌سازی یک روز کار آفلاین: ۱۵۰ فاکتور
    const batch = Array.from({ length: 150 }, (_, i) =>
      change({ entityId: `inv-${i}`, lamport: i + 1, payload: { number: `F-${i}`, total: i * 1000 } }));

    const r = await call('/sync/push', {
      method: 'POST', token,
      body: { businessId: bid, deviceId: 'phone', changes: batch },
    });
    assert.equal(r.body.accepted.filter((a) => a.outcome === 'applied').length, 150);

    // تبلت همه را با صفحه‌بندی می‌گیرد
    let cursor = 0, total = 0, guard = 0;
    while (guard++ < 20) {
      const p = await call(`/sync/pull?businessId=${bid}&deviceId=tablet&since=${cursor}&limit=50`, { token });
      total += p.body.changes.length;
      cursor = p.body.cursor;
      if (!p.body.hasMore) break;
    }
    assert.equal(total, 150);
  });

  test('قطعی وسط ارسال داده را دوباره نمی‌سازد', async () => {
    const token = await signIn('09144444444', 'phone');
    const biz = await call('/businesses', { method: 'POST', body: { name: 'م' }, token });
    const bid = biz.body.id;

    const batch = [change({ entityId: 'a', lamport: 1 }), change({ entityId: 'b', lamport: 2 })];
    const body = { businessId: bid, deviceId: 'phone', changes: batch };

    await call('/sync/push', { method: 'POST', token, body });
    // کلاینت پاسخ را ندید و دقیقاً همان بسته را دوباره فرستاد
    const retry = await call('/sync/push', { method: 'POST', token, body });

    assert.ok(retry.body.accepted.every((a) => a.outcome === 'duplicate'));
    const snap = await call(`/sync/snapshot?businessId=${bid}`, { token });
    assert.equal(snap.body.entities.invoice.length, 2, 'نباید رکورد تکراری بسازد');
  });

  test('دو کاربر روی یک کسب‌وکار همکاری می‌کنند', async () => {
    const owner = await signIn('09145555555', 'owner-dev');
    const biz = await call('/businesses', { method: 'POST', body: { name: 'مشترک' }, token: owner });
    const bid = biz.body.id;

    await call(`/businesses/${bid}/members`, {
      method: 'POST', body: { phone: '09146666666', role: 'salesperson' }, token: owner,
    });
    const seller = await signIn('09146666666', 'seller-dev');

    // فروشنده فاکتور می‌زند
    await call('/sync/push', {
      method: 'POST', token: seller,
      body: {
        businessId: bid, deviceId: 'seller-dev',
        changes: [change({ entityId: 'inv-x', payload: { number: 'F-9', total: 1000 }, deviceId: 'seller-dev' })],
      },
    });

    // مالک آن را می‌بیند
    const pulled = await call(`/sync/pull?businessId=${bid}&deviceId=owner-dev&since=0`, { token: owner });
    assert.equal(pulled.body.changes.length, 1);
    assert.equal(pulled.body.changes[0].payload.number, 'F-9');
  });

  test('حذف در یک دستگاه به دیگری منتقل می‌شود', async () => {
    const token = await signIn('09147777777', 'phone');
    const biz = await call('/businesses', { method: 'POST', body: { name: 'م' }, token });
    const bid = biz.body.id;

    await call('/sync/push', {
      method: 'POST', token,
      body: {
        businessId: bid, deviceId: 'phone',
        changes: [change({ entityId: 'gone', lamport: 1 })],
      },
    });
    await call('/sync/push', {
      method: 'POST', token,
      body: {
        businessId: bid, deviceId: 'phone',
        changes: [change({ entityId: 'gone', lamport: 2, op: 'delete', payload: null })],
      },
    });

    const snap = await call(`/sync/snapshot?businessId=${bid}`, { token });
    assert.equal(snap.body.entities.invoice?.length ?? 0, 0, 'رکورد حذف‌شده نباید در تصویر باشد');

    const pulled = await call(`/sync/pull?businessId=${bid}&deviceId=tablet&since=0`, { token });
    assert.ok(pulled.body.changes.some((c) => c.op === 'delete'));
  });
});

describe('ادغام سمت کلاینت', { skip: !merge }, () => {
  test('تغییر جدید به پایگاه دادهٔ محلی اضافه می‌شود', () => {
    const db = { parties: [] };
    const r = merge.mergeChange(db, {
      seq: 1, id: 'c1', entity: 'party', entityId: 'p1', op: 'put',
      payload: { id: 'p1', name: 'مشتری' }, lamport: 1, deviceId: 'srv', at: '2026-01-01T00:00:00Z',
    });
    assert.equal(r.db.parties.length, 1);
    assert.equal(r.db.parties[0].name, 'مشتری');
    assert.equal(r.conflicted, false);
  });

  test('نسخهٔ محلی جدیدتر حفظ می‌شود', () => {
    const db = { parties: [{ id: 'p1', name: 'محلی', lamport: 9, deviceId: 'zzz', updatedAt: '2026-06-01' }] };
    const r = merge.mergeChange(db, {
      seq: 2, id: 'c2', entity: 'party', entityId: 'p1', op: 'put',
      payload: { id: 'p1', name: 'سرور' }, lamport: 2, deviceId: 'aaa', at: '2026-01-01',
    });
    assert.equal(r.conflicted, true);
    assert.equal(r.db.parties[0].name, 'محلی');
  });

  test('حذف سرور به صورت نرم اعمال می‌شود', () => {
    const db = { invoices: [{ id: 'i1', number: 'F-1' }] };
    const r = merge.mergeChange(db, {
      seq: 3, id: 'c3', entity: 'invoice', entityId: 'i1', op: 'delete',
      payload: null, lamport: 5, deviceId: 'srv', at: '2026-07-01T00:00:00Z',
    });
    assert.ok(r.db.invoices[0].deletedAt, 'باید حذف نرم شود، نه پاک شدن فیزیکی');
  });

  test('موجودیت ناشناخته نادیده گرفته می‌شود', () => {
    const db = { parties: [] };
    const r = merge.mergeChange(db, {
      seq: 4, id: 'c4', entity: 'unknown_thing', entityId: 'x', op: 'put',
      payload: {}, lamport: 1, deviceId: 'srv', at: '2026-01-01',
    });
    assert.deepEqual(r.db, db);
  });
});
