import { test, describe, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { createServer, type Server } from 'node:http';
import { createApp } from '../src/http.js';
import type { DB } from '../src/db.js';

/**
 * آزمون سرتاسری روی HTTP واقعی.
 * سناریوی اصلی: دو دستگاه که یک کسب‌وکار مشترک را همگام می‌کنند.
 */

let server: Server;
let base: string;
let db: DB;
let close: () => void;

before(async () => {
  const app = createApp({
    dev: true,
    rateLimit: { windowMs: 60_000, max: 10_000 },
    otpLimit: { windowMs: 60_000, perPhone: 50, perIp: 10_000 },
  });
  db = app.db;
  close = app.close;
  server = createServer((req, res) => { void app.handler(req, res); });
  await new Promise<void>((r) => server.listen(0, '127.0.0.1', r));
  const addr = server.address();
  base = `http://127.0.0.1:${typeof addr === 'object' && addr ? addr.port : 0}`;
});

after(() => {
  server.close();
  close();
});

async function call(
  path: string,
  opts: { method?: string; body?: unknown; token?: string } = {},
): Promise<{ status: number; body: any }> {
  const res = await fetch(base + path, {
    method: opts.method ?? 'GET',
    headers: {
      'content-type': 'application/json',
      ...(opts.token ? { authorization: `Bearer ${opts.token}` } : {}),
    },
    ...(opts.body !== undefined ? { body: JSON.stringify(opts.body) } : {}),
  });
  return { status: res.status, body: await res.json().catch(() => null) };
}

/** ورود کامل یک کاربر و برگرداندن توکن */
async function login(phone: string, deviceId: string): Promise<string> {
  const otp = await call('/auth/otp', { method: 'POST', body: { phone } });
  const v = await call('/auth/verify', {
    method: 'POST',
    body: { phone, code: otp.body.devCode, deviceId },
  });
  return v.body.token as string;
}

describe('سلامت و قرارداد', () => {
  test('مسیر سلامت پاسخ می‌دهد', async () => {
    const r = await call('/health');
    assert.equal(r.status, 200);
    assert.equal(r.body.ok, true);
    assert.equal(r.body.protocol, 1);
  });

  test('مسیر ناشناخته ۴۰۴ می‌دهد', async () => {
    const r = await call('/nope');
    assert.equal(r.status, 404);
    assert.equal(r.body.error, 'not_found');
  });

  test('پیام خطا فارسی است', async () => {
    const r = await call('/me');
    assert.equal(r.status, 401);
    assert.match(r.body.message, /[\u0600-\u06FF]/);
  });
});

describe('احراز هویت روی HTTP', () => {
  test('چرخهٔ ورود کامل', async () => {
    const otp = await call('/auth/otp', { method: 'POST', body: { phone: '09121111111' } });
    assert.equal(otp.status, 200);
    assert.equal(otp.body.sent, true);
    assert.ok(otp.body.devCode);

    const v = await call('/auth/verify', {
      method: 'POST',
      body: { phone: '09121111111', code: otp.body.devCode, deviceId: 'd1' },
    });
    assert.equal(v.status, 200);
    assert.ok(v.body.token);
    assert.equal(v.body.user.phone, '09121111111');
    assert.deepEqual(v.body.businesses, []);
  });

  test('شمارهٔ نامعتبر رد می‌شود', async () => {
    const r = await call('/auth/otp', { method: 'POST', body: { phone: '123' } });
    assert.equal(r.status, 400);
    assert.equal(r.body.error, 'invalid');
  });

  test('توکن نامعتبر دسترسی نمی‌دهد', async () => {
    const r = await call('/me', { token: 'invalid-token-xyz' });
    assert.equal(r.status, 401);
  });

  test('خروج توکن را باطل می‌کند', async () => {
    const token = await login('09122222222', 'd1');
    assert.equal((await call('/me', { token })).status, 200);
    await call('/auth/logout', { method: 'POST', token });
    assert.equal((await call('/me', { token })).status, 401);
  });
});

describe('کسب‌وکار و دسترسی', () => {
  test('ساخت کسب‌وکار و دیدن آن در پروفایل', async () => {
    const token = await login('09123333333', 'd1');
    const b = await call('/businesses', { method: 'POST', body: { name: 'بوتیک ونک' }, token });
    assert.equal(b.status, 201);
    assert.equal(b.body.role, 'owner');

    const me = await call('/me', { token });
    assert.equal(me.body.businesses.length, 1);
    assert.equal(me.body.businesses[0].name, 'بوتیک ونک');
  });

  test('کاربر بیگانه به کسب‌وکار دسترسی ندارد', async () => {
    const owner = await login('09124444444', 'd1');
    const b = await call('/businesses', { method: 'POST', body: { name: 'مال من' }, token: owner });

    const stranger = await login('09125555555', 'd2');
    const r = await call(`/sync/pull?businessId=${b.body.id}&deviceId=d2&since=0`, { token: stranger });
    assert.equal(r.status, 403);
    assert.equal(r.body.error, 'forbidden');
  });

  test('نقش فقط-خواندنی اجازهٔ ارسال ندارد', async () => {
    const owner = await login('09126666666', 'd1');
    const b = await call('/businesses', { method: 'POST', body: { name: 'فروشگاه' }, token: owner });

    await call(`/businesses/${b.body.id}/members`, {
      method: 'POST', body: { phone: '09127777777', role: 'viewer' }, token: owner,
    });

    const viewer = await login('09127777777', 'd3');

    // خواندن مجاز
    const read = await call(`/sync/pull?businessId=${b.body.id}&deviceId=d3&since=0`, { token: viewer });
    assert.equal(read.status, 200);

    // نوشتن ممنوع
    const write = await call('/sync/push', {
      method: 'POST', token: viewer,
      body: {
        businessId: b.body.id, deviceId: 'd3',
        changes: [{
          id: 'c1', entity: 'party', entityId: 'p1', op: 'put',
          payload: { name: 'x' }, lamport: 1, deviceId: 'd3', at: '2026-01-01T00:00:00Z',
        }],
      },
    });
    assert.equal(write.status, 403);
  });

  test('فقط مالک می‌تواند کاربر اضافه کند', async () => {
    const owner = await login('09128888888', 'd1');
    const b = await call('/businesses', { method: 'POST', body: { name: 'ف' }, token: owner });
    await call(`/businesses/${b.body.id}/members`, {
      method: 'POST', body: { phone: '09129999999', role: 'accountant' }, token: owner,
    });

    const accountant = await login('09129999999', 'd4');
    const r = await call(`/businesses/${b.body.id}/members`, {
      method: 'POST', body: { phone: '09120000001', role: 'viewer' }, token: accountant,
    });
    assert.equal(r.status, 403);
  });
});

describe('همگام‌سازی دو دستگاه', () => {
  test('تغییر یک دستگاه به دستگاه دیگر می‌رسد', async () => {
    const token = await login('09131111111', 'phone');
    const b = await call('/businesses', { method: 'POST', body: { name: 'مغازه' }, token });
    const bid = b.body.id;

    // دستگاه اول فاکتوری ثبت می‌کند
    const pushed = await call('/sync/push', {
      method: 'POST', token,
      body: {
        businessId: bid, deviceId: 'phone',
        changes: [{
          id: 'ch-1', entity: 'invoice', entityId: 'inv-1', op: 'put',
          payload: { number: 'F-1001', total: 500000 },
          lamport: 1, deviceId: 'phone', at: '2026-07-29T10:00:00Z',
        }],
      },
    });
    assert.equal(pushed.status, 200);
    assert.equal(pushed.body.accepted[0].outcome, 'applied');

    // دستگاه دوم آن را می‌گیرد
    const pulled = await call(`/sync/pull?businessId=${bid}&deviceId=tablet&since=0`, { token });
    assert.equal(pulled.status, 200);
    assert.equal(pulled.body.changes.length, 1);
    assert.equal(pulled.body.changes[0].payload.number, 'F-1001');

    // دستگاه اول تغییر خودش را نمی‌گیرد
    const own = await call(`/sync/pull?businessId=${bid}&deviceId=phone&since=0`, { token });
    assert.equal(own.body.changes.length, 0);
  });

  test('ارسال مجدد پس از قطعی، داده را دوباره نمی‌سازد', async () => {
    const token = await login('09132222222', 'd1');
    const b = await call('/businesses', { method: 'POST', body: { name: 'م' }, token });
    const body = {
      businessId: b.body.id, deviceId: 'd1',
      changes: [{
        id: 'retry-1', entity: 'party', entityId: 'p9', op: 'put',
        payload: { name: 'مشتری' }, lamport: 1, deviceId: 'd1', at: '2026-07-29T10:00:00Z',
      }],
    };

    const first = await call('/sync/push', { method: 'POST', token, body });
    assert.equal(first.body.accepted[0].outcome, 'applied');

    // کلاینت پاسخ را ندید و دوباره فرستاد
    const second = await call('/sync/push', { method: 'POST', token, body });
    assert.equal(second.body.accepted[0].outcome, 'duplicate');

    const snap = await call(`/sync/snapshot?businessId=${b.body.id}`, { token });
    assert.equal(snap.body.entities.party.length, 1, 'نباید رکورد تکراری بسازد');
  });

  test('تصویر لحظه‌ای برای دستگاه تازه', async () => {
    const token = await login('09133333333', 'd1');
    const b = await call('/businesses', { method: 'POST', body: { name: 'م' }, token });

    await call('/sync/push', {
      method: 'POST', token,
      body: {
        businessId: b.body.id, deviceId: 'd1',
        changes: [
          { id: 's1', entity: 'party', entityId: 'p1', op: 'put', payload: { name: 'الف' }, lamport: 1, deviceId: 'd1', at: '2026-01-01T00:00:00Z' },
          { id: 's2', entity: 'product', entityId: 'pr1', op: 'put', payload: { name: 'کالا' }, lamport: 2, deviceId: 'd1', at: '2026-01-01T00:00:00Z' },
        ],
      },
    });

    const snap = await call(`/sync/snapshot?businessId=${b.body.id}`, { token });
    assert.equal(snap.status, 200);
    assert.equal(snap.body.entities.party.length, 1);
    assert.equal(snap.body.entities.product.length, 1);
    assert.ok(snap.body.cursor > 0);
  });
});

describe('اعتبارسنجی ورودی', () => {
  test('موجودیت ناشناخته رد می‌شود', async () => {
    const token = await login('09134444444', 'd1');
    const b = await call('/businesses', { method: 'POST', body: { name: 'م' }, token });
    const r = await call('/sync/push', {
      method: 'POST', token,
      body: {
        businessId: b.body.id, deviceId: 'd1',
        changes: [{
          id: 'x', entity: 'hackers', entityId: 'y', op: 'put',
          payload: {}, lamport: 1, deviceId: 'd1', at: '2026-01-01T00:00:00Z',
        }],
      },
    });
    assert.equal(r.status, 400);
    assert.match(r.body.message, /قابل همگام‌سازی نیست/);
  });

  test('ساعت منطقی منفی رد می‌شود', async () => {
    const token = await login('09135555555', 'd1');
    const b = await call('/businesses', { method: 'POST', body: { name: 'م' }, token });
    const r = await call('/sync/push', {
      method: 'POST', token,
      body: {
        businessId: b.body.id, deviceId: 'd1',
        changes: [{
          id: 'x', entity: 'party', entityId: 'y', op: 'put',
          payload: {}, lamport: -5, deviceId: 'd1', at: '2026-01-01T00:00:00Z',
        }],
      },
    });
    assert.equal(r.status, 400);
  });

  test('JSON خراب پیام روشن می‌دهد', async () => {
    const res = await fetch(base + '/auth/otp', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: '{ناقص',
    });
    assert.equal(res.status, 400);
    const body = (await res.json()) as { message: string };
    assert.match(body.message, /JSON/);
  });

  test('نشانک نامعتبر رد می‌شود', async () => {
    const token = await login('09136666666', 'd1');
    const b = await call('/businesses', { method: 'POST', body: { name: 'م' }, token });
    const r = await call(`/sync/pull?businessId=${b.body.id}&deviceId=d1&since=abc`, { token });
    assert.equal(r.status, 400);
  });
});

describe('محدودیت نرخ', () => {
  test('درخواست کد بیش از حد محدود می‌شود', async () => {
    const app = createApp({
      dev: true,
      rateLimit: { windowMs: 60_000, max: 10_000 },
      otpLimit: { windowMs: 60_000, perPhone: 5, perIp: 6 },
    });
    const s = createServer((req, res) => { void app.handler(req, res); });
    await new Promise<void>((r) => s.listen(0, '127.0.0.1', r));
    const addr = s.address();
    const b2 = `http://127.0.0.1:${typeof addr === 'object' && addr ? addr.port : 0}`;

    let limited = false;
    for (let i = 0; i < 8; i++) {
      const res = await fetch(`${b2}/auth/otp`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ phone: `0913000000${i}` }),
      });
      if (res.status === 429) { limited = true; break; }
    }
    s.close();
    app.close();
    assert.equal(limited, true, 'باید پس از چند درخواست محدود شود');
  });
});
