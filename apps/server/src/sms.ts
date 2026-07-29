import { maskPhone } from '@javid/core';

/**
 * ارسال پیامک کد تأیید.
 *
 * طراحی به صورت **آداپتور** است چون سرویس‌دهندهٔ پیامک ایرانی متنوع‌اند
 * (کاوه‌نگار، فراز اس‌ام‌اس، ملی‌پیامک و…) و هرکدام API متفاوتی دارند.
 * افزودن سرویس جدید یعنی یک تابع، نه تغییر در منطق احراز هویت.
 *
 * پیش‌فرض `console` است تا برنامه بدون هیچ اعتبارنامه‌ای کار کند —
 * همان اصلی که در کل پروژه رعایت شده: نبود سرویس بیرونی نباید
 * توسعه یا استفاده را متوقف کند.
 */

export interface SmsResult {
  ok: boolean;
  provider: string;
  messageId?: string;
  error?: string;
}

export interface SmsProvider {
  readonly name: string;
  send(phone: string, code: string): Promise<SmsResult>;
}

const OTP_TEMPLATE = (code: string) =>
  `کد ورود شما به جاوید: ${code}\nاین کد تا ۲ دقیقه معتبر است.\nآن را در اختیار کسی قرار ندهید.`;

/**
 * پیش‌فرض توسعه — کد را در لاگ سرور چاپ می‌کند.
 *
 * خروجی عمداً روی stderr است نه stdout: خروجی تشخیصی نباید با
 * جریان استاندارد برنامه قاطی شود (این موضوع در آزمون‌ها جریان TAP
 * را خراب می‌کرد).
 */
export const consoleProvider: SmsProvider = {
  name: 'console',
  async send(phone, code) {
    if (process.env.SMS_SILENT !== '1') {
      process.stderr.write(`[پیامک] ${maskPhone(phone)} → کد ${code}\n`);
    }
    return { ok: true, provider: 'console', messageId: `dev-${Date.now()}` };
  },
};

/** سرویس بی‌صدا — برای آزمون */
export const silentProvider: SmsProvider = {
  name: 'silent',
  async send() {
    return { ok: true, provider: 'silent', messageId: 'test' };
  },
};

const TIMEOUT_MS = 10_000;

async function postJson(url: string, body: unknown, headers: Record<string, string> = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json', ...headers },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    const text = await res.text();
    return { status: res.status, body: text ? JSON.parse(text) : null };
  } finally {
    clearTimeout(timer);
  }
}

/**
 * کاوه‌نگار — سرویس رایج ایرانی.
 * از الگوی تأیید (verify lookup) استفاده می‌کند که برای کد یک‌بارمصرف
 * سریع‌تر تحویل داده می‌شود و نیازی به تأیید متن ندارد.
 */
export function kavenegarProvider(apiKey: string, template = 'javid-otp'): SmsProvider {
  return {
    name: 'kavenegar',
    async send(phone, code) {
      try {
        const url =
          `https://api.kavenegar.com/v1/${encodeURIComponent(apiKey)}/verify/lookup.json` +
          `?receptor=${encodeURIComponent(phone)}&token=${encodeURIComponent(code)}` +
          `&template=${encodeURIComponent(template)}`;

        const controller = new AbortController();
        const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
        const res = await fetch(url, { signal: controller.signal }).finally(() => clearTimeout(timer));
        const data = (await res.json()) as { return?: { status: number; message: string }; entries?: { messageid: number }[] };

        if (data.return?.status !== 200) {
          return { ok: false, provider: 'kavenegar', error: data.return?.message ?? 'ارسال ناموفق بود' };
        }
        return { ok: true, provider: 'kavenegar', messageId: String(data.entries?.[0]?.messageid ?? '') };
      } catch (e) {
        return { ok: false, provider: 'kavenegar', error: (e as Error).message };
      }
    },
  };
}

/** ملی‌پیامک */
export function melipayamakProvider(username: string, password: string, from: string): SmsProvider {
  return {
    name: 'melipayamak',
    async send(phone, code) {
      try {
        const r = await postJson('https://rest.payamak-panel.com/api/SendSMS/SendSMS', {
          username, password, to: phone, from, text: OTP_TEMPLATE(code), isflash: false,
        });
        const value = (r.body as { Value?: string; RetStatus?: number } | null);
        if (value?.RetStatus !== 1) {
          return { ok: false, provider: 'melipayamak', error: `کد وضعیت ${value?.RetStatus ?? '؟'}` };
        }
        return { ok: true, provider: 'melipayamak', messageId: value.Value };
      } catch (e) {
        return { ok: false, provider: 'melipayamak', error: (e as Error).message };
      }
    },
  };
}

/** سرویس سفارشی — برای وب‌هوک داخلی یا سرویس‌دهندهٔ دیگر */
export function webhookProvider(url: string, secret?: string): SmsProvider {
  return {
    name: 'webhook',
    async send(phone, code) {
      try {
        const r = await postJson(
          url,
          { phone, code, text: OTP_TEMPLATE(code) },
          secret ? { authorization: `Bearer ${secret}` } : {},
        );
        if (r.status >= 200 && r.status < 300) {
          return { ok: true, provider: 'webhook' };
        }
        return { ok: false, provider: 'webhook', error: `کد وضعیت ${r.status}` };
      } catch (e) {
        return { ok: false, provider: 'webhook', error: (e as Error).message };
      }
    },
  };
}

/**
 * انتخاب سرویس از متغیرهای محیطی.
 * نبود پیکربندی خطا نیست — به حالت توسعه برمی‌گردیم.
 */
export function providerFromEnv(env: NodeJS.ProcessEnv = process.env): SmsProvider {
  const kind = (env.SMS_PROVIDER ?? '').toLowerCase();

  switch (kind) {
    case 'kavenegar':
      if (!env.KAVENEGAR_API_KEY) {
        process.stderr.write('[پیامک] کلید کاوه‌نگار تنظیم نشده — حالت توسعه فعال ماند\n');
        return consoleProvider;
      }
      return kavenegarProvider(env.KAVENEGAR_API_KEY, env.KAVENEGAR_TEMPLATE);

    case 'melipayamak':
      if (!env.MELIPAYAMAK_USER || !env.MELIPAYAMAK_PASS || !env.MELIPAYAMAK_FROM) {
        process.stderr.write('[پیامک] اطلاعات ملی‌پیامک ناقص — حالت توسعه فعال ماند\n');
        return consoleProvider;
      }
      return melipayamakProvider(env.MELIPAYAMAK_USER, env.MELIPAYAMAK_PASS, env.MELIPAYAMAK_FROM);

    case 'webhook':
      if (!env.SMS_WEBHOOK_URL) {
        process.stderr.write('[پیامک] آدرس وب‌هوک تنظیم نشده — حالت توسعه فعال ماند\n');
        return consoleProvider;
      }
      return webhookProvider(env.SMS_WEBHOOK_URL, env.SMS_WEBHOOK_SECRET);

    default:
      return consoleProvider;
  }
}

/**
 * ارسال با تلاش مجدد.
 * پیامک ممکن است موقتاً شکست بخورد؛ ولی نباید کاربر را معطل کند،
 * پس تعداد تلاش کم و فاصله کوتاه است.
 */
export async function sendWithRetry(
  provider: SmsProvider,
  phone: string,
  code: string,
  attempts = 2,
): Promise<SmsResult> {
  let last: SmsResult = { ok: false, provider: provider.name, error: 'تلاشی انجام نشد' };
  for (let i = 0; i < attempts; i++) {
    last = await provider.send(phone, code);
    if (last.ok) return last;
    if (i < attempts - 1) await new Promise((r) => setTimeout(r, 400));
  }
  return last;
}
