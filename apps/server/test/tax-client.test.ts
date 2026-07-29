import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { TaxClient, TaxClientError } from '../src/tax-client.js';
import { generateTestKeyPair, verifyRsaSha256 } from '../src/tax-crypto.js';
import { normalizeRequest } from '@javid/core';
import {
  consoleProvider, kavenegarProvider, melipayamakProvider,
  providerFromEnv, sendWithRetry, silentProvider, webhookProvider,
} from '../src/sms.js';

const keys = generateTestKeyPair(2048);

const baseCfg = {
  fiscalId: 'A1D2E3',
  privateKeyPem: keys.privateKeyPem,
  username: 'user',
  password: 'pass',
  baseUrl: 'https://tax.test',
};

const invoice = {
  header: { taxid: 'A1D2E3050B700000000014', inty: 1, tbill: 1_100_000 },
  body: [{ sstid: '2710000000001', am: 1, fee: 1_000_000 }],
};

/** ساخت fetch ساختگی که درخواست‌ها را ثبت می‌کند */
function mockFetch(responses: Record<string, unknown>) {
  const calls: { url: string; body: any; headers: any }[] = [];
  const impl = async (url: string, init?: RequestInit) => {
    const body = init?.body ? JSON.parse(String(init.body)) : null;
    calls.push({ url, body, headers: init?.headers });

    const key = Object.keys(responses).find((k) => url.includes(k));
    if (!key) {
      return new Response(JSON.stringify({ error: 'not found' }), { status: 404 });
    }
    return new Response(JSON.stringify(responses[key]), { status: 200 });
  };
  return { impl, calls };
}

describe('کلاینت سامانهٔ مؤدیان', () => {
  test('پیکربندی ناقص در سازنده رد می‌شود', () => {
    assert.throws(
      () => new TaxClient({ fiscalId: '', privateKeyPem: keys.privateKeyPem }),
      TaxClientError,
    );
    assert.throws(
      () => new TaxClient({ fiscalId: 'A1D2E3', privateKeyPem: 'قلابی' }),
      TaxClientError,
    );
  });

  test('توکن دریافت و در حافظه نگه داشته می‌شود', async () => {
    const { impl, calls } = mockFetch({
      GET_TOKEN: { accessToken: 'jwt-abc', expiresIn: 3600 },
    });
    const c = new TaxClient({ ...baseCfg, fetchImpl: impl });

    assert.equal(await c.getToken(), 'jwt-abc');
    assert.equal(await c.getToken(), 'jwt-abc');
    assert.equal(calls.length, 1, 'توکن نباید دوباره درخواست شود');
  });

  test('نبود اعتبارنامه خطای روشن می‌دهد', async () => {
    const { impl } = mockFetch({});
    const c = new TaxClient({
      fiscalId: 'A1D2E3', privateKeyPem: keys.privateKeyPem, fetchImpl: impl,
    });
    await assert.rejects(() => c.getToken(), /کارپوشه/);
  });

  test('بستهٔ آماده امضای معتبر دارد', async () => {
    const { impl } = mockFetch({});
    const c = new TaxClient({ ...baseCfg, fetchImpl: impl });
    const p = await c.preparePacket(invoice, 'uid-fixed');

    assert.equal(p.uid, 'uid-fixed');
    assert.equal(p.fiscalId, 'A1D2E3');
    assert.equal(
      verifyRsaSha256(normalizeRequest(invoice), p.dataSignature, keys.publicKeyPem),
      true,
    );
  });

  test('ارسال، بسته و امضا را به سامانه می‌فرستد', async () => {
    const { impl, calls } = mockFetch({
      GET_TOKEN: { accessToken: 'jwt', expiresIn: 3600 },
      'normal-enqueue': { result: [] },
    });
    const c = new TaxClient({ ...baseCfg, fetchImpl: impl });
    const out = await c.submit([invoice]);

    assert.equal(out.length, 1);
    assert.equal(out[0]?.status, 'queued');

    const submitCall = calls.find((x) => x.url.includes('normal-enqueue'))!;
    assert.equal(submitCall.body.packets.length, 1);
    assert.ok(submitCall.body.signature, 'امضای سطح درخواست باید باشد');
    assert.equal(submitCall.headers.Authorization, 'jwt');
    assert.ok(submitCall.headers.requestTraceId);
  });

  test('خطای سامانه به پیام فارسی تبدیل می‌شود', async () => {
    let capturedUid = '';
    const impl = async (url: string, init?: RequestInit) => {
      const body = init?.body ? JSON.parse(String(init.body)) : null;
      if (url.includes('GET_TOKEN')) {
        return new Response(JSON.stringify({ accessToken: 'jwt', expiresIn: 3600 }), { status: 200 });
      }
      capturedUid = body.packets[0].uid;
      return new Response(
        JSON.stringify({ result: [{ uid: capturedUid, errorCode: '0400101' }] }),
        { status: 200 },
      );
    };

    const c = new TaxClient({ ...baseCfg, fetchImpl: impl });
    const out = await c.submit([invoice]);

    assert.equal(out[0]?.status, 'rejected');
    assert.match(out[0]?.error ?? '', /امضا/);
  });

  test('خطای سرور قابل تلاش مجدد علامت می‌خورد', async () => {
    const impl = async (url: string) => {
      if (url.includes('GET_TOKEN')) {
        return new Response(JSON.stringify({ accessToken: 'j', expiresIn: 3600 }), { status: 200 });
      }
      return new Response('{}', { status: 503 });
    };
    const c = new TaxClient({ ...baseCfg, fetchImpl: impl });

    await assert.rejects(
      () => c.submit([invoice]),
      (e: TaxClientError) => e.retryable === true && e.code === 'http_503',
    );
  });

  test('خطای ۴۰۰ قابل تلاش مجدد نیست', async () => {
    const impl = async (url: string) => {
      if (url.includes('GET_TOKEN')) {
        return new Response(JSON.stringify({ accessToken: 'j', expiresIn: 3600 }), { status: 200 });
      }
      return new Response('{}', { status: 400 });
    };
    const c = new TaxClient({ ...baseCfg, fetchImpl: impl });
    await assert.rejects(() => c.submit([invoice]), (e: TaxClientError) => e.retryable === false);
  });

  test('استعلام وضعیت', async () => {
    const { impl } = mockFetch({
      GET_TOKEN: { accessToken: 'jwt', expiresIn: 3600 },
      INQUIRY_BY_UID: {
        result: [{ uid: 'u1', status: 'SUCCESS', data: { confirmationNumber: 'CONF-9' } }],
      },
    });
    const c = new TaxClient({ ...baseCfg, fetchImpl: impl });
    const r = await c.inquireByUid(['u1']);

    assert.equal(r.length, 1);
    const mapped = TaxClient.toSubmissionStatus(r[0]!);
    assert.equal(mapped.status, 'accepted');
    assert.equal(mapped.confirmationNumber, 'CONF-9');
  });

  test('وضعیت ناموفق با خطاهای فارسی برمی‌گردد', () => {
    const mapped = TaxClient.toSubmissionStatus({
      uid: 'u', status: 'FAILED',
      data: { errors: [{ code: '0300101', message: '' }] },
    });
    assert.equal(mapped.status, 'rejected');
    assert.match(mapped.errors?.[0]?.message ?? '', /شمارهٔ منحصربه‌فرد/);
  });

  test('ارسال فهرست خالی تماس شبکه نمی‌گیرد', async () => {
    const { impl, calls } = mockFetch({});
    const c = new TaxClient({ ...baseCfg, fetchImpl: impl });
    assert.deepEqual(await c.submit([]), []);
    assert.equal(calls.length, 0);
  });
});

// ─────────── پیامک ───────────

describe('سرویس پیامک', () => {
  test('سرویس بی‌صدا موفق برمی‌گرداند', async () => {
    const r = await silentProvider.send('09121234567', '123456');
    assert.equal(r.ok, true);
  });

  test('سرویس توسعه روی stdout چاپ نمی‌کند', async () => {
    // اگر روی stdout بنویسد جریان TAP آزمون خراب می‌شود
    const original = process.stdout.write;
    let wrote = false;
    process.stdout.write = ((...a: unknown[]) => { wrote = true; return true; }) as never;
    process.env.SMS_SILENT = '1';
    await consoleProvider.send('09121234567', '111111');
    process.stdout.write = original;
    delete process.env.SMS_SILENT;
    assert.equal(wrote, false);
  });

  test('انتخاب سرویس از متغیر محیطی', () => {
    assert.equal(providerFromEnv({} as NodeJS.ProcessEnv).name, 'console');
    assert.equal(
      providerFromEnv({ SMS_PROVIDER: 'kavenegar', KAVENEGAR_API_KEY: 'k' } as never).name,
      'kavenegar',
    );
    // پیکربندی ناقص باید به حالت توسعه برگردد، نه خطا
    assert.equal(providerFromEnv({ SMS_PROVIDER: 'kavenegar' } as never).name, 'console');
    assert.equal(providerFromEnv({ SMS_PROVIDER: 'webhook' } as never).name, 'console');
  });

  test('وب‌هوک کد را ارسال می‌کند', async () => {
    const original = globalThis.fetch;
    let received: any = null;
    globalThis.fetch = (async (_u: string, i: RequestInit) => {
      received = JSON.parse(String(i.body));
      return new Response('{}', { status: 200 });
    }) as never;

    const r = await webhookProvider('https://hook.test', 'secret').send('09121234567', '654321');
    globalThis.fetch = original;

    assert.equal(r.ok, true);
    assert.equal(received.code, '654321');
    assert.match(received.text, /جاوید/);
  });

  test('شکست وب‌هوک خطا برمی‌گرداند نه پرتاب', async () => {
    const original = globalThis.fetch;
    globalThis.fetch = (async () => new Response('{}', { status: 500 })) as never;
    const r = await webhookProvider('https://hook.test').send('09121234567', '1');
    globalThis.fetch = original;
    assert.equal(r.ok, false);
    assert.match(r.error ?? '', /500/);
  });

  test('تلاش مجدد پس از شکست موقت', async () => {
    let attempts = 0;
    const flaky = {
      name: 'flaky',
      async send() {
        attempts++;
        return attempts < 2
          ? { ok: false, provider: 'flaky', error: 'موقت' }
          : { ok: true, provider: 'flaky' };
      },
    };
    const r = await sendWithRetry(flaky, '09121234567', '1', 3);
    assert.equal(r.ok, true);
    assert.equal(attempts, 2);
  });

  test('شکست دائمی پس از تلاش‌ها گزارش می‌شود', async () => {
    const dead = {
      name: 'dead',
      async send() { return { ok: false, provider: 'dead', error: 'قطع' }; },
    };
    const r = await sendWithRetry(dead, '09121234567', '1', 2);
    assert.equal(r.ok, false);
  });

  test('سازندهٔ سرویس‌ها نام درست می‌دهند', () => {
    assert.equal(kavenegarProvider('k').name, 'kavenegar');
    assert.equal(melipayamakProvider('u', 'p', 'f').name, 'melipayamak');
    assert.equal(webhookProvider('https://x').name, 'webhook');
  });
});
