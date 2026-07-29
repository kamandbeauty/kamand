import {
  constants, createCipheriv, createPublicKey, generateKeyPairSync,
  publicEncrypt, randomBytes, sign, verify,
} from 'node:crypto';
import type { TaxCrypto } from '@javid/core';

/**
 * پیاده‌سازی عملیات رمزنگاری سامانهٔ مؤدیان با `node:crypto`.
 *
 * الگوریتم‌ها طبق دستورالعمل سازمان:
 *  - امضا: RSA-2048 + SHA-256 (PKCS#1 v1.5)
 *  - رمزگذاری صورتحساب: XOR با کلید متقارن، سپس AES-256-GCM
 *  - رمزگذاری کلید متقارن: RSA-OAEP-SHA256 با کلید عمومی سازمان
 */

export const nodeTaxCrypto: TaxCrypto = {
  async signRsaSha256(data: string, privateKeyPem: string): Promise<string> {
    return sign('sha256', Buffer.from(data, 'utf8'), privateKeyPem).toString('base64');
  },

  randomBytes(length: number): Uint8Array {
    return new Uint8Array(randomBytes(length));
  },

  async aesGcmEncrypt(plaintext: Uint8Array, key: Uint8Array, iv: Uint8Array): Promise<Uint8Array> {
    // سامانه IV با طول ۱۲۸ بیت می‌خواهد؛ GCM باید صریحاً تنظیم شود
    const cipher = createCipheriv('aes-256-gcm', key, iv, { authTagLength: 16 });
    const encrypted = Buffer.concat([cipher.update(plaintext), cipher.final()]);
    // برچسب احراز به انتهای متن رمز الحاق می‌شود
    return new Uint8Array(Buffer.concat([encrypted, cipher.getAuthTag()]));
  },

  async rsaOaepEncrypt(data: Uint8Array, publicKeyPem: string): Promise<Uint8Array> {
    return new Uint8Array(
      publicEncrypt(
        {
          key: createPublicKey(publicKeyPem),
          padding: constants.RSA_PKCS1_OAEP_PADDING,
          oaepHash: 'sha256',
        },
        Buffer.from(data),
      ),
    );
  },
};

/** بررسی امضا — برای آزمون و اعتبارسنجی پاسخ سازمان */
export function verifyRsaSha256(data: string, signatureB64: string, publicKeyPem: string): boolean {
  try {
    return verify(
      'sha256',
      Buffer.from(data, 'utf8'),
      publicKeyPem,
      Buffer.from(signatureB64, 'base64'),
    );
  } catch {
    return false;
  }
}

/**
 * تولید زوج کلید آزمایشی.
 *
 * ⚠️ فقط برای توسعه و آزمون. کلید واقعی باید از یک مرکز میانی معتبر
 * (فهرست در rca.gov.ir) دریافت و در کارپوشه ثبت شود.
 */
export function generateTestKeyPair(modulusLength: 2048 | 4096 = 2048): {
  publicKeyPem: string;
  privateKeyPem: string;
} {
  const { publicKey, privateKey } = generateKeyPairSync('rsa', {
    modulusLength,
    publicKeyEncoding: { type: 'spki', format: 'pem' },
    privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  });
  return { publicKeyPem: publicKey, privateKeyPem: privateKey };
}
