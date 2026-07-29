/**
 * ═══════════════════════════════════════════════════════════════
 *  لایهٔ انتقال سامانهٔ مؤدیان — نرمال‌سازی، امضا و رمزگذاری
 * ═══════════════════════════════════════════════════════════════
 *
 * این ماژول بخش **قابل‌پیاده‌سازی و قابل‌آزمون** اتصال به سامانه است:
 * ساخت بسته، نرمال‌سازی، امضای دیجیتال و رمزگذاری.
 *
 * آنچه اینجا نیست و بدون اعتبارنامهٔ واقعی ممکن نیست:
 *  - گواهی امضای دیجیتال از مرکز میانی معتبر (rca.gov.ir)
 *  - کلید عمومی ۴۰۹۶ بیتی سازمان (از متد GET_SERVER_INFORMATION)
 *  - نام کاربری و رمز کارپوشه برای دریافت توکن
 *
 * طراحی به صورت **تزریق وابستگی** است: عملیات رمزنگاری از بیرون
 * داده می‌شود تا هسته به Web Crypto یا node:crypto وابسته نباشد
 * و در هر دو محیط کار کند.
 *
 * ⚠️ دستورالعمل سازمان بروزرسانی می‌شود. پیش از بهره‌برداری عملیاتی
 * آخرین نسخه را از intamedia.ir بررسی کنید.
 */

export const TAX_API_BASE = 'https://tp.tax.gov.ir/req';

/** مسیرهای سامانه — self-tsp برای مؤدی که خودش ارسال می‌کند */
export const TAX_ENDPOINTS = {
  ENQUEUE_NORMAL: '/api/self-tsp/async/normal-enqueue',
  ENQUEUE_FAST: '/api/self-tsp/async/fast-enqueue',
  GET_TOKEN: '/api/self-tsp/sync/GET_TOKEN',
  GET_SERVER_INFO: '/api/self-tsp/sync/GET_SERVER_INFORMATION',
  GET_FISCAL_INFO: '/api/self-tsp/sync/GET_FISCAL_INFORMATION',
  INQUIRY_BY_UID: '/api/self-tsp/sync/INQUIRY_BY_UID',
  INQUIRY_BY_REFERENCE: '/api/self-tsp/sync/INQUIRY_BY_REFERENCE_NUMBER',
  INQUIRY_BY_TIME: '/api/self-tsp/sync/INQUIRY_BY_TIME',
  INQUIRY_BY_TIME_RANGE: '/api/self-tsp/sync/INQUIRY_BY_TIME_RANGE',
  GET_STUFF_LIST: '/api/self-tsp/sync/GET_SERVICE_STUFF_LIST',
  GET_ECONOMIC_CODE: '/api/self-tsp/sync/GET_ECONOMIC_CODE_INFORMATION',
} as const;

export const PACKET_TYPE_INVOICE = 'INVOICE.V01';

// ─────────────────── نرمال‌سازی ───────────────────

/**
 * تبدیل شیء تودرتو به فهرست مسطح کلید-مقدار با مسیر نقطه‌ای.
 *
 * قاعدهٔ سامانه: آرایه‌ها **مرتب نمی‌شوند** و ترتیب اصلی حفظ می‌شود؛
 * فقط کلیدهای شیء الفبایی مرتب می‌گردند.
 */
export function flattenForNormalization(
  value: unknown,
  prefix = '',
  out: { key: string; value: unknown }[] = [],
): { key: string; value: unknown }[] {
  if (Array.isArray(value)) {
    value.forEach((item, i) => {
      flattenForNormalization(item, prefix ? `${prefix}.${i}` : String(i), out);
    });
    return out;
  }

  if (value !== null && typeof value === 'object') {
    // کلیدهای شیء الفبایی مرتب می‌شوند
    const keys = Object.keys(value as Record<string, unknown>).sort();
    for (const k of keys) {
      const child = (value as Record<string, unknown>)[k];
      flattenForNormalization(child, prefix ? `${prefix}.${k}` : k, out);
    }
    return out;
  }

  out.push({ key: prefix, value });
  return out;
}

/**
 * تبدیل یک مقدار به قطعهٔ رشتهٔ نرمال.
 *  - null یا رشتهٔ خالی  →  ###
 *  - کاراکتر # در متن    →  ##
 */
export function normalizeValue(value: unknown): string {
  if (value === null || value === undefined || value === '') return '###';
  const s = typeof value === 'boolean' ? String(value) : String(value);
  if (s === '') return '###';
  return s.replace(/#/g, '##');
}

/**
 * نرمال‌سازی کامل مطابق دستورالعمل سازمان.
 *
 * گام‌ها:
 *  ۱. مسطح‌سازی به کلید-مقدار با مسیر نقطه‌ای
 *  ۲. مرتب‌سازی الفبایی کلیدها
 *  ۳. ادغام مقادیر با جداکنندهٔ #
 *
 * اگر ریشه آرایه باشد، داخل فیلد packets قرار می‌گیرد.
 */
export function normalizeRequest(payload: unknown): string {
  const root = Array.isArray(payload) ? { packets: payload } : payload;
  const flat = flattenForNormalization(root);
  // مرتب‌سازی نهایی بر اساس کلید کامل، با ترتیب پایدار
  flat.sort((a, b) => (a.key < b.key ? -1 : a.key > b.key ? 1 : 0));
  return flat.map((f) => normalizeValue(f.value)).join('#');
}

// ─────────────────── قرارداد رمزنگاری ───────────────────

/**
 * عملیات رمزنگاری مورد نیاز، به صورت تزریق‌شدنی.
 * پیاده‌سازی Node در `apps/server` و پیاده‌سازی مرورگر در `apps/web` است.
 */
export interface TaxCrypto {
  /** امضای RSA-2048 با SHA-256 — خروجی Base64 */
  signRsaSha256(data: string, privateKeyPem: string): Promise<string>;
  /** تولید کلید متقارن ۲۵۶ بیتی */
  randomBytes(length: number): Uint8Array;
  /** رمزگذاری AES-256-GCM — خروجی شامل متن رمز و برچسب احراز */
  aesGcmEncrypt(plaintext: Uint8Array, key: Uint8Array, iv: Uint8Array): Promise<Uint8Array>;
  /** رمزگذاری کلید متقارن با RSA-OAEP-SHA256 و کلید عمومی سازمان */
  rsaOaepEncrypt(data: Uint8Array, publicKeyPem: string): Promise<Uint8Array>;
}

// ─────────────────── XOR ───────────────────

/**
 * XOR متن با کلید متقارن در بلوک‌های ۲۵۶ بیتی (۳۲ بایت).
 * بلوک آخر می‌تواند کوتاه‌تر باشد و با همان تعداد بایت XOR می‌شود.
 *
 * این گام پیش از AES/GCM انجام می‌شود و بخشی از الزام سامانه است.
 */
export function xorWithKey(data: Uint8Array, key: Uint8Array): Uint8Array {
  if (key.length === 0) throw new Error('کلید متقارن خالی است');
  const out = new Uint8Array(data.length);
  for (let i = 0; i < data.length; i++) {
    out[i] = data[i]! ^ key[i % key.length]!;
  }
  return out;
}

// ─────────────────── کدگذاری ───────────────────

export function toBase64(bytes: Uint8Array): string {
  const g = globalThis as { btoa?: (s: string) => string; Buffer?: typeof Buffer };
  if (g.Buffer) return g.Buffer.from(bytes).toString('base64');
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return g.btoa!(bin);
}

export function fromBase64(b64: string): Uint8Array {
  const g = globalThis as { atob?: (s: string) => string; Buffer?: typeof Buffer };
  if (g.Buffer) return new Uint8Array(g.Buffer.from(b64, 'base64'));
  const bin = g.atob!(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

export function toHex(bytes: Uint8Array): string {
  return [...bytes].map((b) => b.toString(16).padStart(2, '0')).join('');
}

export function utf8Bytes(s: string): Uint8Array {
  return new TextEncoder().encode(s);
}

// ─────────────────── بسته ───────────────────

export interface TaxPacket {
  uid: string;
  packetType: string;
  retry: boolean;
  data: unknown;
  encryptionKeyId?: string | null;
  symmetricKey?: string | null;
  iv?: string | null;
  fiscalId: string;
  dataSignature: string;
}

export interface TaxRequestBody {
  packets: TaxPacket[];
  signature: string;
  signatureKeyId?: string | null;
}

export interface TaxHeaders {
  Authorization?: string;
  requestTraceId: string;
  timestamp: number;
}

export interface BuildPacketInput {
  /** صورتحساب الکترونیکی ساخته‌شده توسط `buildElectronicInvoice` */
  invoice: unknown;
  /** شناسهٔ یکتای ارسال — UUID */
  uid: string;
  /** شناسهٔ یکتای حافظهٔ مالیاتی */
  fiscalId: string;
  /** کلید خصوصی مؤدی، PEM */
  privateKeyPem: string;
  /** کلید عمومی سازمان، PEM — از GET_SERVER_INFORMATION */
  orgPublicKeyPem?: string | null;
  /** شناسهٔ کلید رمزگذاری سازمان */
  encryptionKeyId?: string | null;
  retry?: boolean;
  crypto: TaxCrypto;
}

/**
 * ساخت یک بستهٔ صورتحساب: نرمال‌سازی، امضا و در صورت وجود کلید سازمان،
 * رمزگذاری.
 *
 * توجه: امضا روی **صورتحساب نرمال‌شده** انجام می‌شود، نه روی متن رمزشده.
 */
export async function buildPacket(input: BuildPacketInput): Promise<TaxPacket> {
  const { invoice, uid, fiscalId, privateKeyPem, crypto } = input;

  // ۱ — نرمال‌سازی و امضای صورتحساب
  const normalized = normalizeRequest(invoice);
  const dataSignature = await crypto.signRsaSha256(normalized, privateKeyPem);

  const packet: TaxPacket = {
    uid,
    packetType: PACKET_TYPE_INVOICE,
    retry: input.retry ?? false,
    data: invoice,
    fiscalId,
    dataSignature,
    encryptionKeyId: input.encryptionKeyId ?? null,
    symmetricKey: null,
    iv: null,
  };

  // ۲ — رمزگذاری، فقط اگر کلید عمومی سازمان در دست باشد
  if (input.orgPublicKeyPem) {
    const json = utf8Bytes(JSON.stringify(invoice));
    const key = crypto.randomBytes(32);
    const iv = crypto.randomBytes(16);

    const xored = xorWithKey(json, key);
    const encrypted = await crypto.aesGcmEncrypt(xored, key, iv);
    const wrappedKey = await crypto.rsaOaepEncrypt(key, input.orgPublicKeyPem);

    packet.data = toBase64(encrypted);
    packet.symmetricKey = toBase64(wrappedKey);
    packet.iv = toBase64(iv);
  }

  return packet;
}

/**
 * ساخت بدنهٔ کامل درخواست.
 * امضای سطح درخواست روی ادغام سرآیند و بدنه انجام می‌شود.
 */
export async function buildRequest(
  packets: TaxPacket[],
  headers: TaxHeaders,
  privateKeyPem: string,
  crypto: TaxCrypto,
  signatureKeyId?: string | null,
): Promise<{ headers: TaxHeaders; body: TaxRequestBody }> {
  const merged = {
    ...headers,
    packets,
  };

  const normalized = normalizeRequest(merged);
  const signature = await crypto.signRsaSha256(normalized, privateKeyPem);

  return {
    headers,
    body: { packets, signature, signatureKeyId: signatureKeyId ?? null },
  };
}

// ─────────────────── پاسخ ───────────────────

export type TaxPacketStatus = 'PENDING' | 'SUCCESS' | 'FAILED' | 'IN_PROGRESS';

export interface TaxAsyncResponse {
  uid: string;
  referenceNumber?: string;
  errorCode?: string | null;
  errorDetail?: string | null;
}

export interface TaxInquiryResult {
  uid: string;
  referenceNumber?: string;
  status: TaxPacketStatus;
  data?: {
    confirmationNumber?: string;
    errors?: { code: string; message: string }[];
  };
}

/** پیام فارسی برای کدهای خطای پرتکرار سامانه */
export const TAX_ERROR_MESSAGES: Record<string, string> = {
  '0300101': 'شمارهٔ منحصربه‌فرد مالیاتی با اطلاعات سامانه منطبق نیست',
  '0300102': 'تاریخ و زمان صدور صورتحساب نامعتبر است',
  '0300103': 'سریال داخلی صورتحساب تکراری است',
  '0300201': 'شناسهٔ کالا یا خدمت نامعتبر است',
  '0300202': 'نرخ مالیات بر ارزش افزوده نادرست است',
  '0300301': 'شمارهٔ اقتصادی خریدار نامعتبر است',
  '0300401': 'جمع مبالغ صورتحساب با اقلام آن نمی‌خواند',
  '0300501': 'صورتحساب مرجع برای اصلاح یا ابطال یافت نشد',
  '0400101': 'امضای دیجیتال معتبر نیست',
  '0400102': 'توکن منقضی شده است',
  '0400103': 'کلید عمومی ثبت‌نشده یا نامعتبر است',
};

export function taxErrorMessage(code: string): string {
  return TAX_ERROR_MESSAGES[code] ?? `خطای سامانه (کد ${code})`;
}

/** نگاشت وضعیت سامانه به وضعیت داخلی */
export function mapTaxStatus(status: TaxPacketStatus): 'sent' | 'accepted' | 'rejected' {
  switch (status) {
    case 'SUCCESS': return 'accepted';
    case 'FAILED': return 'rejected';
    default: return 'sent';
  }
}

// ─────────────────── اعتبارسنجی پیکربندی ───────────────────

export interface TaxTransportConfig {
  privateKeyPem: string;
  orgPublicKeyPem?: string | null;
  fiscalId: string;
  username?: string;
  password?: string;
  baseUrl?: string;
  encryptionKeyId?: string | null;
  signatureKeyId?: string | null;
}

/** بررسی آمادگی پیکربندی پیش از تلاش برای ارسال */
export function validateTransportConfig(c: Partial<TaxTransportConfig>): string[] {
  const issues: string[] = [];

  if (!c.fiscalId?.trim()) {
    issues.push('شناسهٔ یکتای حافظهٔ مالیاتی تنظیم نشده است');
  }
  if (!c.privateKeyPem?.trim()) {
    issues.push('کلید خصوصی امضای دیجیتال بارگذاری نشده است');
  } else if (!/-----BEGIN [A-Z ]*PRIVATE KEY-----/.test(c.privateKeyPem)) {
    issues.push('قالب کلید خصوصی معتبر نیست (باید PEM باشد)');
  }
  if (c.orgPublicKeyPem && !/-----BEGIN PUBLIC KEY-----/.test(c.orgPublicKeyPem)) {
    issues.push('قالب کلید عمومی سازمان معتبر نیست');
  }

  return issues;
}

export function isTransportReady(c: Partial<TaxTransportConfig>): boolean {
  return validateTransportConfig(c).length === 0;
}
