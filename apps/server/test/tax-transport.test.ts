import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { createDecipheriv, privateDecrypt, constants } from 'node:crypto';
import {
  buildPacket, buildRequest, flattenForNormalization, fromBase64,
  isTransportReady, mapTaxStatus, normalizeRequest, normalizeValue,
  PACKET_TYPE_INVOICE, TAX_ENDPOINTS, taxErrorMessage,
  toBase64, utf8Bytes, validateTransportConfig, xorWithKey,
} from '@javid/core';
import { generateTestKeyPair, nodeTaxCrypto, verifyRsaSha256 } from '../src/tax-crypto.js';

/**
 * آزمون لایهٔ انتقال سامانهٔ مؤدیان.
 *
 * نکتهٔ کلیدی: چون به سامانهٔ واقعی دسترسی نداریم، هر چیزی که
 * **قابل راستی‌آزمایی مستقل** است را واقعاً راستی‌آزمایی می‌کنیم:
 * امضا با کلید عمومی بررسی می‌شود، رمزگذاری واقعاً رمزگشایی می‌شود.
 */

const keys = generateTestKeyPair(2048);
const orgKeys = generateTestKeyPair(4096);

// ─────────── نرمال‌سازی ───────────

describe('نرمال‌سازی درخواست', () => {
  test('مثال رسمی دستورالعمل بازتولید می‌شود', () => {
    // نمونهٔ جدول ۱ سند سازمان
    const input = { k2: 'v1', k4: 'v2', k3: { k1: 'v4', k5: 'v5' } };
    assert.equal(normalizeRequest(input), 'v1#v4#v5#v2');
  });

  test('کلیدهای شیء الفبایی مرتب می‌شوند', () => {
    assert.equal(normalizeRequest({ z: '1', a: '2', m: '3' }), '2#3#1');
  });

  test('ترتیب عناصر آرایه دستکاری نمی‌شود', () => {
    const r = normalizeRequest({ items: ['c', 'a', 'b'] });
    assert.equal(r, 'c#a#b', 'آرایه باید ترتیب اصلی را حفظ کند');
  });

  test('مقدار null و رشتهٔ خالی با ### مشخص می‌شود', () => {
    assert.equal(normalizeValue(null), '###');
    assert.equal(normalizeValue(undefined), '###');
    assert.equal(normalizeValue(''), '###');
    assert.equal(normalizeRequest({ a: null, b: 'x' }), '####x');
  });

  test('کاراکتر # در متن با ## فرار داده می‌شود', () => {
    assert.equal(normalizeValue('a#b'), 'a##b');
    assert.equal(normalizeRequest({ a: 'x#y' }), 'x##y');
  });

  test('ریشهٔ آرایه داخل packets قرار می‌گیرد', () => {
    const asArray = normalizeRequest([{ a: '1' }, { a: '2' }]);
    const asObject = normalizeRequest({ packets: [{ a: '1' }, { a: '2' }] });
    assert.equal(asArray, asObject);
  });

  test('اشیای تودرتو با مسیر نقطه‌ای مسطح می‌شوند', () => {
    const flat = flattenForNormalization({ a: { b: { c: 'x' } } });
    assert.equal(flat[0]?.key, 'a.b.c');
    assert.equal(flat[0]?.value, 'x');
  });

  test('عدد و بولین به رشته تبدیل می‌شوند', () => {
    assert.equal(normalizeRequest({ n: 1000, b: true }), 'true#1000');
  });

  test('نرمال‌سازی قطعی‌گراست', () => {
    const inv = { header: { taxid: 'A1', tbill: 1090000 }, body: [{ am: 1, fee: 1000 }] };
    assert.equal(normalizeRequest(inv), normalizeRequest({ ...inv }));
  });

  test('ساختار صورتحساب واقعی نرمال می‌شود', () => {
    const invoice = {
      header: { taxid: 'AA56CD0E0620002F2B4E78', indatim: 1655620821274, inty: 2, irtaxid: null, tbill: 1090000 },
      body: [{ sstid: '2153265989636', am: 1, fee: 1000000, vam: 90000 }],
    };
    const r = normalizeRequest(invoice);
    assert.ok(r.includes('AA56CD0E0620002F2B4E78'));
    assert.ok(r.includes('###'), 'irtaxid null باید ### شود');
    assert.ok(r.split('#').length > 5);
  });
});

// ─────────── امضا ───────────

describe('امضای دیجیتال', () => {
  test('امضا با کلید عمومی راستی‌آزمایی می‌شود', async () => {
    const data = 'v1#v4#v5#v2';
    const sig = await nodeTaxCrypto.signRsaSha256(data, keys.privateKeyPem);
    assert.equal(verifyRsaSha256(data, sig, keys.publicKeyPem), true);
  });

  test('دستکاری داده امضا را باطل می‌کند', async () => {
    const sig = await nodeTaxCrypto.signRsaSha256('اصلی', keys.privateKeyPem);
    assert.equal(verifyRsaSha256('دستکاری‌شده', sig, keys.publicKeyPem), false);
  });

  test('کلید دیگر امضا را تأیید نمی‌کند', async () => {
    const other = generateTestKeyPair(2048);
    const sig = await nodeTaxCrypto.signRsaSha256('داده', keys.privateKeyPem);
    assert.equal(verifyRsaSha256('داده', sig, other.publicKeyPem), false);
  });

  test('امضای RSA-2048 برابر ۲۵۶ بایت است', async () => {
    const sig = await nodeTaxCrypto.signRsaSha256('x', keys.privateKeyPem);
    assert.equal(fromBase64(sig).length, 256);
  });
});

// ─────────── XOR و رمزگذاری ───────────

describe('XOR و رمزگذاری', () => {
  test('XOR برگشت‌پذیر است', () => {
    const data = utf8Bytes('صورتحساب الکترونیکی');
    const key = nodeTaxCrypto.randomBytes(32);
    assert.deepEqual(xorWithKey(xorWithKey(data, key), key), data);
  });

  test('XOR روی بلوک‌های ۳۲ بایتی تکرار می‌شود', () => {
    const data = new Uint8Array(70).fill(0xff);
    const key = new Uint8Array(32).fill(0x0f);
    const out = xorWithKey(data, key);
    assert.equal(out.length, 70, 'طول باید حفظ شود');
    assert.equal(out[0], 0xf0);
    assert.equal(out[32], 0xf0, 'بلوک دوم همان کلید را می‌گیرد');
    assert.equal(out[69], 0xf0, 'بلوک ناقص آخر هم XOR می‌شود');
  });

  test('کلید خالی رد می‌شود', () => {
    assert.throws(() => xorWithKey(new Uint8Array(4), new Uint8Array(0)));
  });

  test('AES-GCM رمزگذاری واقعاً رمزگشایی می‌شود', async () => {
    const plain = utf8Bytes('متن آزمایشی فارسی');
    const key = nodeTaxCrypto.randomBytes(32);
    const iv = nodeTaxCrypto.randomBytes(16);

    const encrypted = await nodeTaxCrypto.aesGcmEncrypt(plain, key, iv);
    // ۱۶ بایت آخر برچسب احراز است
    const tag = encrypted.slice(-16);
    const body = encrypted.slice(0, -16);

    const decipher = createDecipheriv('aes-256-gcm', key, iv, { authTagLength: 16 });
    decipher.setAuthTag(Buffer.from(tag));
    const decrypted = Buffer.concat([decipher.update(Buffer.from(body)), decipher.final()]);

    assert.deepEqual(new Uint8Array(decrypted), plain);
  });

  test('کلید متقارن با RSA-OAEP رمز و رمزگشایی می‌شود', async () => {
    const key = nodeTaxCrypto.randomBytes(32);
    const wrapped = await nodeTaxCrypto.rsaOaepEncrypt(key, orgKeys.publicKeyPem);

    const unwrapped = privateDecrypt(
      { key: orgKeys.privateKeyPem, padding: constants.RSA_PKCS1_OAEP_PADDING, oaepHash: 'sha256' },
      Buffer.from(wrapped),
    );
    assert.deepEqual(new Uint8Array(unwrapped), key);
  });

  test('Base64 رفت و برگشت می‌کند', () => {
    const bytes = nodeTaxCrypto.randomBytes(64);
    assert.deepEqual(fromBase64(toBase64(bytes)), bytes);
  });
});

// ─────────── بسته ───────────

describe('ساخت بستهٔ صورتحساب', () => {
  const invoice = {
    header: { taxid: 'A1D2E3050B700000000014', inty: 1, tbill: 1_100_000 },
    body: [{ sstid: '2710000000001', am: 3, fee: 200_000, vam: 60_000 }],
  };

  test('بسته بدون رمزگذاری، داده را خام نگه می‌دارد', async () => {
    const p = await buildPacket({
      invoice, uid: 'uid-1', fiscalId: 'A1D2E3',
      privateKeyPem: keys.privateKeyPem, crypto: nodeTaxCrypto,
    });

    assert.equal(p.packetType, PACKET_TYPE_INVOICE);
    assert.equal(p.fiscalId, 'A1D2E3');
    assert.equal(p.retry, false);
    assert.deepEqual(p.data, invoice);
    assert.equal(p.symmetricKey, null);
    assert.ok(p.dataSignature);
  });

  test('امضای بسته روی صورتحساب نرمال‌شده معتبر است', async () => {
    const p = await buildPacket({
      invoice, uid: 'uid-1', fiscalId: 'A1D2E3',
      privateKeyPem: keys.privateKeyPem, crypto: nodeTaxCrypto,
    });

    const normalized = normalizeRequest(invoice);
    assert.equal(
      verifyRsaSha256(normalized, p.dataSignature, keys.publicKeyPem),
      true,
      'امضا باید روی رشتهٔ نرمال‌شده معتبر باشد',
    );
  });

  test('با کلید سازمان، داده رمز می‌شود و قابل بازگشایی است', async () => {
    const p = await buildPacket({
      invoice, uid: 'uid-2', fiscalId: 'A1D2E3',
      privateKeyPem: keys.privateKeyPem,
      orgPublicKeyPem: orgKeys.publicKeyPem,
      crypto: nodeTaxCrypto,
    });

    assert.equal(typeof p.data, 'string', 'داده باید Base64 شود');
    assert.ok(p.symmetricKey);
    assert.ok(p.iv);

    // بازگشایی کامل: کلید → AES-GCM → XOR → JSON
    const key = privateDecrypt(
      { key: orgKeys.privateKeyPem, padding: constants.RSA_PKCS1_OAEP_PADDING, oaepHash: 'sha256' },
      Buffer.from(fromBase64(p.symmetricKey!)),
    );
    const iv = fromBase64(p.iv!);
    const enc = fromBase64(p.data as string);

    const decipher = createDecipheriv('aes-256-gcm', key, iv, { authTagLength: 16 });
    decipher.setAuthTag(Buffer.from(enc.slice(-16)));
    const xored = Buffer.concat([
      decipher.update(Buffer.from(enc.slice(0, -16))),
      decipher.final(),
    ]);

    const json = xorWithKey(new Uint8Array(xored), new Uint8Array(key));
    assert.deepEqual(JSON.parse(new TextDecoder().decode(json)), invoice);
  });

  test('پرچم ارسال مجدد منتقل می‌شود', async () => {
    const p = await buildPacket({
      invoice, uid: 'u', fiscalId: 'A1D2E3', retry: true,
      privateKeyPem: keys.privateKeyPem, crypto: nodeTaxCrypto,
    });
    assert.equal(p.retry, true);
  });

  test('بدنهٔ درخواست امضای سطح بالا دارد', async () => {
    const p = await buildPacket({
      invoice, uid: 'u1', fiscalId: 'A1D2E3',
      privateKeyPem: keys.privateKeyPem, crypto: nodeTaxCrypto,
    });

    const headers = { requestTraceId: 'trace-1', timestamp: 1_700_000_000_000 };
    const req = await buildRequest([p], headers, keys.privateKeyPem, nodeTaxCrypto);

    assert.equal(req.body.packets.length, 1);
    assert.ok(req.body.signature);

    const normalized = normalizeRequest({ ...headers, packets: [p] });
    assert.equal(verifyRsaSha256(normalized, req.body.signature, keys.publicKeyPem), true);
  });
});

// ─────────── پیکربندی و خطاها ───────────

describe('پیکربندی انتقال', () => {
  test('پیکربندی کامل پذیرفته می‌شود', () => {
    assert.deepEqual(
      validateTransportConfig({ fiscalId: 'A1D2E3', privateKeyPem: keys.privateKeyPem }),
      [],
    );
    assert.equal(isTransportReady({ fiscalId: 'A1D2E3', privateKeyPem: keys.privateKeyPem }), true);
  });

  test('نبود کلید خصوصی گرفته می‌شود', () => {
    const issues = validateTransportConfig({ fiscalId: 'A1D2E3' });
    assert.ok(issues.some((i) => i.includes('کلید خصوصی')));
  });

  test('قالب نامعتبر کلید گرفته می‌شود', () => {
    const issues = validateTransportConfig({ fiscalId: 'A1D2E3', privateKeyPem: 'کلید قلابی' });
    assert.ok(issues.some((i) => i.includes('PEM')));
  });

  test('نبود شناسهٔ حافظه گرفته می‌شود', () => {
    const issues = validateTransportConfig({ privateKeyPem: keys.privateKeyPem });
    assert.ok(issues.some((i) => i.includes('حافظهٔ مالیاتی')));
  });

  test('پیام خطای سامانه فارسی است', () => {
    assert.match(taxErrorMessage('0300101'), /شمارهٔ منحصربه‌فرد/);
    assert.match(taxErrorMessage('0400101'), /امضا/);
    assert.match(taxErrorMessage('999999'), /کد 999999/);
  });

  test('نگاشت وضعیت سامانه', () => {
    assert.equal(mapTaxStatus('SUCCESS'), 'accepted');
    assert.equal(mapTaxStatus('FAILED'), 'rejected');
    assert.equal(mapTaxStatus('PENDING'), 'sent');
    assert.equal(mapTaxStatus('IN_PROGRESS'), 'sent');
  });

  test('مسیرهای سامانه تعریف شده‌اند', () => {
    assert.ok(TAX_ENDPOINTS.ENQUEUE_NORMAL.includes('normal-enqueue'));
    assert.ok(TAX_ENDPOINTS.GET_TOKEN.includes('GET_TOKEN'));
    assert.ok(TAX_ENDPOINTS.INQUIRY_BY_UID.includes('INQUIRY_BY_UID'));
  });
});
