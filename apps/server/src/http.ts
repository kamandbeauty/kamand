import { createServer, type IncomingMessage, type ServerResponse } from 'node:http';
import {
  ERROR_CODES, normalizePhone, PROTOCOL_VERSION, validatePushBody,
  type ApiError, type ErrorCode, type PullResult, type PushBody,
  type RequestOtpBody, type RequestOtpResult, type VerifyOtpBody, type VerifyOtpResult,
} from '@javid/core';
import { openDB, type DB } from './db.js';
import {
  addMember, businessesOf, canWrite, createBusiness, requestOtp,
  revokeSession, roleOf, sessionOf, verifyOtp, type Role, type Session,
} from './auth.js';
import { pull, push, snapshot } from './sync.js';
import { providerFromEnv, sendWithRetry, type SmsProvider } from './sms.js';

/**
 * لایهٔ HTTP بدون فریم‌ورک.
 * دلیل: وابستگی کمتر یعنی سطح حملهٔ کمتر و بروزرسانی ساده‌تر برای
 * سرویسی که دادهٔ مالی نگه می‌دارد.
 */

export interface ServerOptions {
  db?: DB;
  dev?: boolean;
  /** محدودیت نرخ عمومی: تعداد درخواست در پنجرهٔ زمانی */
  rateLimit?: { windowMs: number; max: number };
  /**
   * محدودیت درخواست کد تأیید.
   * دو سطحی است: سخت‌گیرانه روی هر شماره، سهل‌گیرانه‌تر روی هر IP —
   * چون چند کارمند یک مغازه پشت یک IP مشترک هستند و نباید
   * همدیگر را قفل کنند.
   */
  otpLimit?: { windowMs: number; perPhone: number; perIp: number };
  /** سرویس ارسال پیامک — پیش‌فرض از متغیرهای محیطی خوانده می‌شود */
  sms?: SmsProvider;
}

const MAX_BODY_BYTES = 4 * 1024 * 1024;

interface Ctx {
  req: IncomingMessage;
  res: ServerResponse;
  url: URL;
  db: DB;
  dev: boolean;
  session: Session | null;
  sms: SmsProvider;
}

function send(res: ServerResponse, status: number, body: unknown): void {
  const json = JSON.stringify(body);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(json),
    'x-protocol-version': String(PROTOCOL_VERSION),
  });
  res.end(json);
}

function fail(res: ServerResponse, status: number, error: ErrorCode, message: string, details?: unknown): void {
  const body: ApiError = { error, message };
  if (details !== undefined) body.details = details;
  send(res, status, body);
}

async function readBody(req: IncomingMessage): Promise<unknown> {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const chunk of req) {
    size += (chunk as Buffer).length;
    if (size > MAX_BODY_BYTES) throw new Error('حجم درخواست بیش از حد مجاز است');
    chunks.push(chunk as Buffer);
  }
  if (chunks.length === 0) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8')) as unknown;
  } catch {
    throw new Error('بدنهٔ درخواست JSON معتبر نیست');
  }
}

function bearer(req: IncomingMessage): string | null {
  const h = req.headers.authorization;
  if (!h?.startsWith('Bearer ')) return null;
  return h.slice(7).trim() || null;
}

// ─────────────────── محدودیت نرخ ───────────────────

class RateLimiter {
  private hits = new Map<string, number[]>();
  constructor(private windowMs: number, private max: number) {}

  check(key: string): boolean {
    const now = Date.now();
    const arr = (this.hits.get(key) ?? []).filter((t) => now - t < this.windowMs);
    if (arr.length >= this.max) {
      this.hits.set(key, arr);
      return false;
    }
    arr.push(now);
    this.hits.set(key, arr);
    return true;
  }

  /** پاکسازی دوره‌ای تا حافظه نشت نکند */
  sweep(): void {
    const now = Date.now();
    for (const [k, v] of this.hits) {
      const kept = v.filter((t) => now - t < this.windowMs);
      if (kept.length === 0) this.hits.delete(k);
      else this.hits.set(k, kept);
    }
  }
}

// ─────────────────── مسیرها ───────────────────

/** دسترسی به کسب‌وکار را بررسی و نقش را برمی‌گرداند */
function requireAccess(ctx: Ctx, businessId: string): Role | null {
  if (!ctx.session) {
    fail(ctx.res, 401, ERROR_CODES.UNAUTHORIZED, 'برای ادامه باید وارد حساب کاربری شوید');
    return null;
  }
  const role = roleOf(ctx.db, ctx.session.userId, businessId);
  if (!role) {
    fail(ctx.res, 403, ERROR_CODES.FORBIDDEN, 'شما به این کسب‌وکار دسترسی ندارید');
    return null;
  }
  return role;
}

export function createApp(opts: ServerOptions = {}) {
  const db = opts.db ?? openDB(process.env.JAVID_DB ?? ':memory:');
  const dev = opts.dev ?? process.env.NODE_ENV !== 'production';
  const rl = new RateLimiter(opts.rateLimit?.windowMs ?? 60_000, opts.rateLimit?.max ?? 120);
  const otpWindow = opts.otpLimit?.windowMs ?? 10 * 60_000;
  const otpPhoneRl = new RateLimiter(otpWindow, opts.otpLimit?.perPhone ?? 5);
  const otpIpRl = new RateLimiter(otpWindow, opts.otpLimit?.perIp ?? 40);

  const sms = opts.sms ?? providerFromEnv();
  const sweeper = setInterval(() => { rl.sweep(); otpPhoneRl.sweep(); otpIpRl.sweep(); }, 60_000);
  sweeper.unref?.();

  const handler = async (req: IncomingMessage, res: ServerResponse): Promise<void> => {
    // CORS — برنامهٔ وب از دامنهٔ دیگری صدا می‌زند
    res.setHeader('access-control-allow-origin', '*');
    res.setHeader('access-control-allow-headers', 'authorization, content-type');
    res.setHeader('access-control-allow-methods', 'GET, POST, DELETE, OPTIONS');

    if (req.method === 'OPTIONS') {
      res.writeHead(204);
      res.end();
      return;
    }

    const url = new URL(req.url ?? '/', 'http://localhost');
    const ip = req.socket.remoteAddress ?? 'unknown';

    if (!rl.check(ip)) {
      fail(res, 429, ERROR_CODES.RATE_LIMITED, 'تعداد درخواست‌ها زیاد است، کمی بعد دوباره تلاش کنید');
      return;
    }

    const ctx: Ctx = { req, res, url, db, dev, sms, session: sessionOf(db, bearer(req)) };
    const path = url.pathname.replace(/\/+$/, '') || '/';

    try {
      await route(ctx, path, { phone: otpPhoneRl, ip: otpIpRl });
    } catch (e) {
      const msg = (e as Error).message;
      if (msg.includes('JSON') || msg.includes('حجم')) {
        fail(res, 400, ERROR_CODES.INVALID, msg);
      } else {
        process.stderr.write(`خطای سرور: ${String(e)}\n`);
        fail(res, 500, ERROR_CODES.SERVER, 'خطای سرور — اطلاعات شما روی دستگاه محفوظ است');
      }
    }
  };

  return { handler, db, close: () => { clearInterval(sweeper); db.close(); } };
}

interface OtpLimiters { phone: RateLimiter; ip: RateLimiter }

async function route(ctx: Ctx, path: string, otpRl: OtpLimiters): Promise<void> {
  const { req, res, db } = ctx;
  const method = req.method ?? 'GET';

  // ─── سلامت ───
  if (path === '/health' && method === 'GET') {
    return send(res, 200, { ok: true, protocol: PROTOCOL_VERSION, time: new Date().toISOString() });
  }

  // ─── درخواست کد ───
  if (path === '/auth/otp' && method === 'POST') {
    const body = (await readBody(req)) as RequestOtpBody;
    const ip = req.socket.remoteAddress ?? 'unknown';
    const phone = normalizePhone(String(body?.phone ?? ''));

    if (!phone) return fail(res, 400, ERROR_CODES.INVALID, 'شمارهٔ موبایل نامعتبر است');

    if (!otpRl.phone.check(`otp:${phone}`)) {
      return fail(res, 429, ERROR_CODES.RATE_LIMITED, 'درخواست کد برای این شماره بیش از حد مجاز است');
    }
    if (!otpRl.ip.check(`otp-ip:${ip}`)) {
      return fail(res, 429, ERROR_CODES.RATE_LIMITED, 'درخواست کد بیش از حد مجاز — چند دقیقه صبر کنید');
    }

    const out = requestOtp(db, phone, ctx.dev);
    if (!out.ok) {
      const code = out.error?.includes('نامعتبر') ? ERROR_CODES.INVALID : ERROR_CODES.RATE_LIMITED;
      return fail(res, code === ERROR_CODES.INVALID ? 400 : 429, code, out.error ?? 'ارسال کد ناموفق بود');
    }

    // ارسال پیامک؛ شکست آن نباید کل درخواست را بشکند چون کد
    // در حالت توسعه از مسیر پاسخ هم در دسترس است.
    if (out.generated) {
      const smsResult = await sendWithRetry(ctx.sms, phone, out.generated);
      if (!smsResult.ok) {
        process.stderr.write(`[پیامک] ارسال ناموفق: ${smsResult.error}\n`);
        if (!ctx.dev) {
          return fail(res, 502, ERROR_CODES.SERVER, 'ارسال پیامک ناموفق بود، دوباره تلاش کنید');
        }
      }
    }

    const result: RequestOtpResult = { sent: true, retryAfter: out.retryAfter };
    if (out.code) result.devCode = out.code;
    return send(res, 200, result);
  }

  // ─── تأیید کد ───
  if (path === '/auth/verify' && method === 'POST') {
    const body = (await readBody(req)) as VerifyOtpBody;
    const out = verifyOtp(
      db,
      String(body?.phone ?? ''),
      String(body?.code ?? ''),
      String(body?.deviceId ?? ''),
      body?.deviceName,
    );
    if (!out.ok) return fail(res, 400, ERROR_CODES.INVALID, out.error ?? 'تأیید ناموفق بود');

    const result: VerifyOtpResult = {
      token: out.token!,
      user: out.user!,
      businesses: out.businesses ?? [],
    };
    return send(res, 200, result);
  }

  // ─── خروج ───
  if (path === '/auth/logout' && method === 'POST') {
    const token = bearer(req);
    if (token) revokeSession(db, token);
    return send(res, 200, { ok: true });
  }

  // ─── من کیستم ───
  if (path === '/me' && method === 'GET') {
    if (!ctx.session) {
      return fail(res, 401, ERROR_CODES.UNAUTHORIZED, 'برای ادامه باید وارد حساب کاربری شوید');
    }
    const user = db
      .prepare('SELECT id, phone, name FROM users WHERE id = ?')
      .get(ctx.session.userId);
    return send(res, 200, { user, businesses: businessesOf(db, ctx.session.userId) });
  }

  // ─── کسب‌وکارها ───
  if (path === '/businesses' && method === 'POST') {
    if (!ctx.session) {
      return fail(res, 401, ERROR_CODES.UNAUTHORIZED, 'برای ادامه باید وارد حساب کاربری شوید');
    }
    const body = (await readBody(req)) as { name?: string; id?: string };
    const name = String(body?.name ?? '').trim();
    if (!name) return fail(res, 400, ERROR_CODES.INVALID, 'نام کسب‌وکار الزامی است');

    const biz = createBusiness(db, ctx.session.userId, name, body?.id);
    return send(res, 201, biz);
  }

  // ─── افزودن کاربر ───
  const memberMatch = path.match(/^\/businesses\/([^/]+)\/members$/);
  if (memberMatch && method === 'POST') {
    const businessId = memberMatch[1]!;
    const role = requireAccess(ctx, businessId);
    if (!role) return;
    if (role !== 'owner') {
      return fail(res, 403, ERROR_CODES.FORBIDDEN, 'فقط مالک می‌تواند کاربر اضافه کند');
    }

    const body = (await readBody(req)) as { phone?: string; role?: Role };
    const out = addMember(db, businessId, String(body?.phone ?? ''), body?.role ?? 'salesperson');
    if (!out.ok) return fail(res, 400, ERROR_CODES.INVALID, out.error ?? 'افزودن کاربر ناموفق بود');
    return send(res, 200, { ok: true });
  }

  // ─── ارسال تغییرات ───
  if (path === '/sync/push' && method === 'POST') {
    const body = (await readBody(req)) as PushBody;

    const invalid = validatePushBody(body);
    if (invalid) return fail(res, 400, ERROR_CODES.INVALID, invalid);

    const role = requireAccess(ctx, body.businessId);
    if (!role) return;

    if (!canWrite(role)) {
      return fail(res, 403, ERROR_CODES.FORBIDDEN, 'نقش شما اجازهٔ ثبت اطلاعات ندارد');
    }

    const result = push(db, body.businessId, ctx.session!.userId, body.changes);
    return send(res, 200, result);
  }

  // ─── دریافت تغییرات ───
  if (path === '/sync/pull' && method === 'GET') {
    const businessId = ctx.url.searchParams.get('businessId') ?? '';
    const deviceId = ctx.url.searchParams.get('deviceId') ?? ctx.session?.deviceId ?? '';
    const since = Number(ctx.url.searchParams.get('since') ?? '0');
    const limit = Number(ctx.url.searchParams.get('limit') ?? '0') || undefined;

    if (!businessId) return fail(res, 400, ERROR_CODES.INVALID, 'شناسهٔ کسب‌وکار الزامی است');
    if (!Number.isFinite(since) || since < 0) {
      return fail(res, 400, ERROR_CODES.INVALID, 'نشانک نامعتبر است');
    }

    const role = requireAccess(ctx, businessId);
    if (!role) return;

    const result: PullResult = pull(db, businessId, since, deviceId, limit);
    return send(res, 200, result);
  }

  // ─── تصویر لحظه‌ای ───
  if (path === '/sync/snapshot' && method === 'GET') {
    const businessId = ctx.url.searchParams.get('businessId') ?? '';
    if (!businessId) return fail(res, 400, ERROR_CODES.INVALID, 'شناسهٔ کسب‌وکار الزامی است');

    const role = requireAccess(ctx, businessId);
    if (!role) return;

    return send(res, 200, snapshot(db, businessId));
  }

  fail(res, 404, ERROR_CODES.NOT_FOUND, 'مسیر درخواستی یافت نشد');
}

export function startServer(port: number, opts: ServerOptions = {}) {
  const app = createApp(opts);
  const server = createServer((req, res) => { void app.handler(req, res); });
  server.listen(port);
  return { server, db: app.db, close: () => { server.close(); app.close(); } };
}
