import {
  buildPacket, buildRequest, mapTaxStatus, TAX_API_BASE, TAX_ENDPOINTS,
  taxErrorMessage, validateTransportConfig,
  type TaxInquiryResult, type TaxPacket, type TaxTransportConfig,
} from '@javid/core';
import { randomUUID } from 'node:crypto';
import { nodeTaxCrypto } from './tax-crypto.js';

/**
 * کلاینت ارسال صورتحساب به سامانهٔ مؤدیان.
 *
 * ⚠️ این کلاینت بدون اعتبارنامهٔ واقعی قابل استفادهٔ عملیاتی نیست:
 * گواهی امضا از مرکز میانی، کلید عمومی سازمان و اطلاعات کارپوشه لازم است.
 * ساختار، امضا و رمزگذاری کامل پیاده و آزمون شده‌اند؛ فقط نقطهٔ اتصال
 * به سرور واقعی نیاز به کلید دارد.
 *
 * طراحی `fetchImpl` تزریق‌شدنی است تا بدون شبکه هم قابل آزمون باشد.
 */

export type FetchLike = (url: string, init?: RequestInit) => Promise<Response>;

export interface TaxClientOptions extends TaxTransportConfig {
  fetchImpl?: FetchLike;
  timeoutMs?: number;
}

export class TaxClientError extends Error {
  readonly code: string;
  readonly retryable: boolean;
  constructor(code: string, message: string, retryable = false) {
    super(message);
    this.name = 'TaxClientError';
    this.code = code;
    this.retryable = retryable;
  }
}

export interface SubmitResult {
  uid: string;
  referenceNumber?: string;
  status: 'queued' | 'sent' | 'rejected';
  error?: string;
}

export class TaxClient {
  private readonly cfg: TaxClientOptions;
  private readonly fetchImpl: FetchLike;
  private readonly base: string;
  private token: string | null = null;
  private tokenExpiry = 0;

  constructor(cfg: TaxClientOptions) {
    const issues = validateTransportConfig(cfg);
    if (issues.length > 0) {
      throw new TaxClientError('invalid_config', issues.join('؛ '));
    }
    this.cfg = cfg;
    this.fetchImpl = cfg.fetchImpl ?? ((u, i) => fetch(u, i));
    this.base = (cfg.baseUrl ?? TAX_API_BASE).replace(/\/+$/, '');
  }

  private async call(path: string, body: unknown, headers: Record<string, string> = {}) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.cfg.timeoutMs ?? 30_000);
    try {
      const res = await this.fetchImpl(this.base + path, {
        method: 'POST',
        headers: { 'content-type': 'application/json', ...headers },
        body: JSON.stringify(body),
        signal: controller.signal,
      });

      const text = await res.text();
      const data = text ? (JSON.parse(text) as unknown) : null;

      if (!res.ok) {
        const retryable = res.status >= 500 || res.status === 429;
        throw new TaxClientError(
          `http_${res.status}`,
          `سامانه پاسخ ${res.status} داد`,
          retryable,
        );
      }
      return data;
    } catch (e) {
      if (e instanceof TaxClientError) throw e;
      if ((e as Error).name === 'AbortError') {
        throw new TaxClientError('timeout', 'پاسخی از سامانهٔ مؤدیان دریافت نشد', true);
      }
      throw new TaxClientError('network', 'اتصال به سامانهٔ مؤدیان برقرار نشد', true);
    } finally {
      clearTimeout(timer);
    }
  }

  /** دریافت توکن JWT — تا انقضا در حافظه نگه داشته می‌شود */
  async getToken(): Promise<string> {
    if (this.token && Date.now() < this.tokenExpiry) return this.token;

    if (!this.cfg.username || !this.cfg.password) {
      throw new TaxClientError('no_credentials', 'نام کاربری یا رمز کارپوشه تنظیم نشده است');
    }

    const data = (await this.call(TAX_ENDPOINTS.GET_TOKEN, {
      username: this.cfg.username,
      password: this.cfg.password,
    })) as { accessToken?: string; token?: string; expiresIn?: number } | null;

    const token = data?.accessToken ?? data?.token;
    if (!token) throw new TaxClientError('no_token', 'توکنی از سامانه دریافت نشد');

    this.token = token;
    // یک دقیقه زودتر منقضی می‌کنیم تا در مرز زمانی گیر نکنیم
    this.tokenExpiry = Date.now() + ((data?.expiresIn ?? 3600) - 60) * 1000;
    return token;
  }

  /** کلید عمومی سازمان برای رمزگذاری */
  async getServerPublicKey(): Promise<string | null> {
    const data = (await this.call(TAX_ENDPOINTS.GET_SERVER_INFO, {})) as
      | { publicKeys?: { key: string; id: string }[] }
      | null;
    return data?.publicKeys?.[0]?.key ?? null;
  }

  /** ساخت بستهٔ آمادهٔ ارسال بدون تماس با شبکه — برای پیش‌نمایش و آزمون */
  async preparePacket(invoice: unknown, uid: string = randomUUID()): Promise<TaxPacket> {
    return buildPacket({
      invoice,
      uid,
      fiscalId: this.cfg.fiscalId,
      privateKeyPem: this.cfg.privateKeyPem,
      orgPublicKeyPem: this.cfg.orgPublicKeyPem ?? null,
      encryptionKeyId: this.cfg.encryptionKeyId ?? null,
      crypto: nodeTaxCrypto,
    });
  }

  /** ارسال یک یا چند صورتحساب به صف سامانه */
  async submit(invoices: unknown[], opts: { fast?: boolean } = {}): Promise<SubmitResult[]> {
    if (invoices.length === 0) return [];

    const token = await this.getToken();
    const packets = await Promise.all(invoices.map((inv) => this.preparePacket(inv)));

    const headers = { requestTraceId: randomUUID(), timestamp: Date.now() };
    const req = await buildRequest(
      packets,
      headers,
      this.cfg.privateKeyPem,
      nodeTaxCrypto,
      this.cfg.signatureKeyId ?? null,
    );

    const path = opts.fast ? TAX_ENDPOINTS.ENQUEUE_FAST : TAX_ENDPOINTS.ENQUEUE_NORMAL;
    const data = (await this.call(path, req.body, {
      Authorization: token,
      requestTraceId: headers.requestTraceId,
      timestamp: String(headers.timestamp),
    })) as { result?: { uid: string; referenceNumber?: string; errorCode?: string; errorDetail?: string }[] } | null;

    const byUid = new Map((data?.result ?? []).map((r) => [r.uid, r]));

    return packets.map((p) => {
      const r = byUid.get(p.uid);
      if (!r) return { uid: p.uid, status: 'queued' as const };
      if (r.errorCode) {
        return {
          uid: p.uid,
          status: 'rejected' as const,
          error: r.errorDetail ?? taxErrorMessage(r.errorCode),
        };
      }
      return { uid: p.uid, referenceNumber: r.referenceNumber, status: 'sent' as const };
    });
  }

  /** استعلام وضعیت با شناسهٔ یکتای ارسال */
  async inquireByUid(uids: string[]): Promise<TaxInquiryResult[]> {
    const token = await this.getToken();
    const data = (await this.call(
      TAX_ENDPOINTS.INQUIRY_BY_UID,
      { uidList: uids },
      { Authorization: token },
    )) as { result?: TaxInquiryResult[] } | null;
    return data?.result ?? [];
  }

  /** استعلام با رسید یکتای دریافت */
  async inquireByReference(referenceNumbers: string[]): Promise<TaxInquiryResult[]> {
    const token = await this.getToken();
    const data = (await this.call(
      TAX_ENDPOINTS.INQUIRY_BY_REFERENCE,
      { referenceNumber: referenceNumbers },
      { Authorization: token },
    )) as { result?: TaxInquiryResult[] } | null;
    return data?.result ?? [];
  }

  /** نگاشت نتیجهٔ استعلام به وضعیت داخلی */
  static toSubmissionStatus(r: TaxInquiryResult): {
    status: 'sent' | 'accepted' | 'rejected';
    confirmationNumber?: string;
    errors?: { code: string; message: string }[];
  } {
    return {
      status: mapTaxStatus(r.status),
      confirmationNumber: r.data?.confirmationNumber,
      errors: r.data?.errors?.map((e) => ({
        code: e.code,
        message: e.message || taxErrorMessage(e.code),
      })),
    };
  }
}
