import { formatJalali } from './jalali.js';
import { formatMoney, moneyToWords, toPersianDigits, type Rial } from './money.js';
import { computeInvoice } from './invoice.js';
import type { Business, Invoice, Party, Product, ID } from './types.js';

/**
 * چاپ حرارتی ESC/POS — نیاز اصلی فروشگاه‌ها.
 *
 * ⚠️ چالش فارسی: چاپگرهای حرارتی معمولاً از یونیکد پشتیبانی نمی‌کنند و
 * باید متن به صفحه‌کد عربی (CP864) تبدیل شود. به‌علاوه فارسی نویسه‌های
 * پیوسته دارد و چاپگر آن‌ها را نمی‌چسباند، پس باید خودمان شکل درست هر
 * حرف را انتخاب و ترتیب را معکوس کنیم.
 *
 * این ماژول خروجی بایت تولید می‌کند؛ ارسال به چاپگر (بلوتوث/USB/شبکه)
 * وظیفهٔ لایهٔ بالاتر است.
 */

// ─────────────────── فرمان‌های ESC/POS ───────────────────

const ESC = 0x1b;
const GS = 0x1d;

export const CMD = {
  INIT: [ESC, 0x40],
  ALIGN_RIGHT: [ESC, 0x61, 0x02],
  ALIGN_CENTER: [ESC, 0x61, 0x01],
  ALIGN_LEFT: [ESC, 0x61, 0x00],
  BOLD_ON: [ESC, 0x45, 0x01],
  BOLD_OFF: [ESC, 0x45, 0x00],
  DOUBLE_ON: [GS, 0x21, 0x11],
  DOUBLE_OFF: [GS, 0x21, 0x00],
  FEED: [0x0a],
  CUT: [GS, 0x56, 0x42, 0x00],
  DRAWER: [ESC, 0x70, 0x00, 0x19, 0xfa],
  /** انتخاب صفحه‌کد عربی */
  CODEPAGE_ARABIC: [ESC, 0x74, 0x25],
} as const;

// ─────────────────── شکل‌دهی حروف فارسی ───────────────────

/**
 * جدول اشکال حروف: [منفرد، آغازین، میانی، پایانی]
 * حروفی که به بعد نمی‌چسبند فقط دو شکل دارند.
 */
interface Glyph {
  isolated: string;
  initial: string;
  medial: string;
  final: string;
  /** آیا این حرف به حرف بعدی می‌چسبد؟ */
  connects: boolean;
}

const G = (iso: string, ini: string, med: string, fin: string, connects = true): Glyph => ({
  isolated: iso, initial: ini, medial: med, final: fin, connects,
});

const SHAPES: Record<string, Glyph> = {
  'ا': G('\uFE8D', '\uFE8D', '\uFE8E', '\uFE8E', false),
  'آ': G('\uFE81', '\uFE81', '\uFE82', '\uFE82', false),
  'أ': G('\uFE83', '\uFE83', '\uFE84', '\uFE84', false),
  'إ': G('\uFE87', '\uFE87', '\uFE88', '\uFE88', false),
  'ب': G('\uFE8F', '\uFE91', '\uFE92', '\uFE90'),
  'پ': G('\uFB56', '\uFB58', '\uFB59', '\uFB57'),
  'ت': G('\uFE95', '\uFE97', '\uFE98', '\uFE96'),
  'ث': G('\uFE99', '\uFE9B', '\uFE9C', '\uFE9A'),
  'ج': G('\uFE9D', '\uFE9F', '\uFEA0', '\uFE9E'),
  'چ': G('\uFB7A', '\uFB7C', '\uFB7D', '\uFB7B'),
  'ح': G('\uFEA1', '\uFEA3', '\uFEA4', '\uFEA2'),
  'خ': G('\uFEA5', '\uFEA7', '\uFEA8', '\uFEA6'),
  'د': G('\uFEA9', '\uFEA9', '\uFEAA', '\uFEAA', false),
  'ذ': G('\uFEAB', '\uFEAB', '\uFEAC', '\uFEAC', false),
  'ر': G('\uFEAD', '\uFEAD', '\uFEAE', '\uFEAE', false),
  'ز': G('\uFEAF', '\uFEAF', '\uFEB0', '\uFEB0', false),
  'ژ': G('\uFB8A', '\uFB8A', '\uFB8B', '\uFB8B', false),
  'س': G('\uFEB1', '\uFEB3', '\uFEB4', '\uFEB2'),
  'ش': G('\uFEB5', '\uFEB7', '\uFEB8', '\uFEB6'),
  'ص': G('\uFEB9', '\uFEBB', '\uFEBC', '\uFEBA'),
  'ض': G('\uFEBD', '\uFEBF', '\uFEC0', '\uFEBE'),
  'ط': G('\uFEC1', '\uFEC3', '\uFEC4', '\uFEC2'),
  'ظ': G('\uFEC5', '\uFEC7', '\uFEC8', '\uFEC6'),
  'ع': G('\uFEC9', '\uFECB', '\uFECC', '\uFECA'),
  'غ': G('\uFECD', '\uFECF', '\uFED0', '\uFECE'),
  'ف': G('\uFED1', '\uFED3', '\uFED4', '\uFED2'),
  'ق': G('\uFED5', '\uFED7', '\uFED8', '\uFED6'),
  'ک': G('\uFB8E', '\uFB90', '\uFB91', '\uFB8F'),
  'ك': G('\uFED9', '\uFEDB', '\uFEDC', '\uFEDA'),
  'گ': G('\uFB92', '\uFB94', '\uFB95', '\uFB93'),
  'ل': G('\uFEDD', '\uFEDF', '\uFEE0', '\uFEDE'),
  'م': G('\uFEE1', '\uFEE3', '\uFEE4', '\uFEE2'),
  'ن': G('\uFEE5', '\uFEE7', '\uFEE8', '\uFEE6'),
  'و': G('\uFEED', '\uFEED', '\uFEEE', '\uFEEE', false),
  'ه': G('\uFEE9', '\uFEEB', '\uFEEC', '\uFEEA'),
  'ة': G('\uFE93', '\uFE93', '\uFE94', '\uFE94', false),
  'ی': G('\uFBFC', '\uFBFE', '\uFBFF', '\uFBFD'),
  'ي': G('\uFEF1', '\uFEF3', '\uFEF4', '\uFEF2'),
  'ئ': G('\uFE89', '\uFE8B', '\uFE8C', '\uFE8A'),
  'ء': G('\uFE80', '\uFE80', '\uFE80', '\uFE80', false),
};

/** ترکیب لام-الف که باید به یک نویسه تبدیل شود */
const LAM_ALEF: Record<string, [string, string]> = {
  'ا': ['\uFEFB', '\uFEFC'],
  'آ': ['\uFEF5', '\uFEF6'],
  'أ': ['\uFEF7', '\uFEF8'],
  'إ': ['\uFEF9', '\uFEFA'],
};

const isArabicLetter = (ch: string): boolean => ch in SHAPES;

/**
 * تبدیل متن فارسی به اشکال نمایشی و معکوس کردن ترتیب.
 * چاپگر حرارتی متن را از چپ می‌چیند، پس متن راست‌به‌چپ باید
 * از پیش معکوس شود.
 */
export function shapePersian(text: string): string {
  const out: string[] = [];
  const chars = [...text];

  for (let i = 0; i < chars.length; i++) {
    const ch = chars[i]!;

    // ترکیب لام + الف
    if (ch === 'ل' && i + 1 < chars.length) {
      const next = chars[i + 1]!;
      const combo = LAM_ALEF[next];
      if (combo) {
        const prev = chars[i - 1];
        const joinedBefore = prev !== undefined && isArabicLetter(prev) && SHAPES[prev]!.connects;
        out.push(joinedBefore ? combo[1] : combo[0]);
        i++;
        continue;
      }
    }

    if (!isArabicLetter(ch)) {
      out.push(ch);
      continue;
    }

    const prev = chars[i - 1];
    const next = chars[i + 1];
    const joinBefore = prev !== undefined && isArabicLetter(prev) && SHAPES[prev]!.connects;
    const joinAfter = next !== undefined && isArabicLetter(next);
    const g = SHAPES[ch]!;

    let shaped: string;
    if (joinBefore && joinAfter && g.connects) shaped = g.medial;
    else if (joinBefore && !(joinAfter && g.connects)) shaped = g.final;
    else if (!joinBefore && joinAfter && g.connects) shaped = g.initial;
    else shaped = g.isolated;

    out.push(shaped);
  }

  return out.join('');
}

/**
 * معکوس کردن متن برای چاپ راست‌به‌چپ.
 * قطعه‌های لاتین و عددی داخل متن نباید معکوس شوند.
 */
export function reverseForRTL(text: string): string {
  const tokens = text.match(/[a-zA-Z0-9.,:/\-+()]+|[^a-zA-Z0-9.,:/\-+()]+/g) ?? [];
  return tokens
    .map((t) => (/^[a-zA-Z0-9.,:/\-+()]+$/.test(t) ? t : [...t].reverse().join('')))
    .reverse()
    .join('');
}

export function preparePersian(text: string): string {
  return reverseForRTL(shapePersian(text));
}

// ─────────────────── سازندهٔ رسید ───────────────────

export interface ReceiptOptions {
  /** عرض کاغذ به تعداد نویسه: ۳۲ برای ۵۸ میلی‌متر، ۴۸ برای ۸۰ میلی‌متر */
  width?: 32 | 48;
  /** آماده‌سازی فارسی برای چاپگرهای بدون یونیکد */
  shapeArabic?: boolean;
  openDrawer?: boolean;
  cut?: boolean;
  footer?: string;
}

export class ReceiptBuilder {
  private bytes: number[] = [];
  /** بافر متنی موازی — برای پیش‌نمایش بدون فرمان‌های کنترلی */
  private lines: string[] = [];
  private current = '';
  private readonly width: number;
  private readonly shape: boolean;

  constructor(opts: ReceiptOptions = {}) {
    this.width = opts.width ?? 48;
    this.shape = opts.shapeArabic ?? true;
    this.raw(CMD.INIT);
    this.raw(CMD.CODEPAGE_ARABIC);
    this.raw(CMD.ALIGN_RIGHT);
  }

  raw(cmd: readonly number[]): this {
    this.bytes.push(...cmd);
    return this;
  }

  /** افزودن یک سطر متن */
  text(line: string): this {
    this.lines.push(line);
    const prepared = this.shape ? preparePersian(line) : line;
    for (const ch of prepared) {
      const code = ch.codePointAt(0)!;
      if (code < 128) this.bytes.push(code);
      else {
        // نویسه‌های خارج از ASCII به صورت UTF-8 فرستاده می‌شوند؛
        // چاپگرهای مدرن یونیکد را می‌فهمند
        for (const b of new TextEncoder().encode(ch)) this.bytes.push(b);
      }
    }
    return this.raw(CMD.FEED);
  }

  center(line: string): this {
    this.raw(CMD.ALIGN_CENTER);
    this.text(line);
    return this.raw(CMD.ALIGN_RIGHT);
  }

  bold(line: string): this {
    this.raw(CMD.BOLD_ON);
    this.text(line);
    return this.raw(CMD.BOLD_OFF);
  }

  title(line: string): this {
    this.raw(CMD.ALIGN_CENTER).raw(CMD.DOUBLE_ON);
    this.text(line);
    return this.raw(CMD.DOUBLE_OFF).raw(CMD.ALIGN_RIGHT);
  }

  divider(char = '-'): this {
    return this.text(char.repeat(this.width));
  }

  /** سطر دوستونی: برچسب راست، مقدار چپ */
  row(label: string, value: string): this {
    const pad = Math.max(1, this.width - label.length - value.length);
    return this.text(`${label}${' '.repeat(pad)}${value}`);
  }

  feed(n = 1): this {
    for (let i = 0; i < n; i++) this.raw(CMD.FEED);
    return this;
  }

  cut(): this {
    return this.feed(3).raw(CMD.CUT);
  }

  openDrawer(): this {
    return this.raw(CMD.DRAWER);
  }

  build(): Uint8Array {
    return new Uint8Array(this.bytes);
  }

  /**
   * خروجی متنی برای پیش‌نمایش.
   * از بافر متنی خوانده می‌شود، نه از بایت‌ها — چون بایت‌ها هم شامل
   * فرمان‌های کنترلی‌اند و هم نویسه‌های فارسی را چندبایتی نگه می‌دارند.
   */
  preview(): string {
    return this.lines.join('\n');
  }
}

/** ساخت رسید فروش کامل */
export function buildReceipt(input: {
  invoice: Invoice;
  business: Business;
  party: Party | null;
  products: Map<ID, Product>;
  paid?: Rial;
  taxId?: string | null;
  options?: ReceiptOptions;
}): ReceiptBuilder {
  const { invoice, business, party, products, paid = 0, taxId, options = {} } = input;
  const r = new ReceiptBuilder(options);
  const t = computeInvoice(invoice);
  const unit = business.currencyUnit === 'toman' ? 'تومان' : 'ریال';
  const money = (v: Rial) => formatMoney(v, { persian: true });

  r.title(business.name);
  if (business.address) r.center(business.address);
  if (business.phone) r.center(toPersianDigits(business.phone));
  r.divider('=');

  r.row('شماره فاکتور', toPersianDigits(invoice.number));
  r.row('تاریخ', formatJalali(new Date(invoice.date), 'short'));
  if (party) r.row('خریدار', party.name);
  if (taxId) {
    r.text('شماره مالیاتی:');
    r.text(taxId);
  }
  r.divider();

  for (const [i, line] of invoice.lines.entries()) {
    const p = products.get(line.productId);
    r.text(`${toPersianDigits(i + 1)}. ${p?.name ?? 'کالا'}`);
    r.row(
      `   ${toPersianDigits(line.qty)} ${line.unit} × ${money(line.unitPrice)}`,
      money(t.lines[i]?.total ?? 0),
    );
  }

  r.divider();
  r.row('جمع', money(t.subtotal));
  if (t.totalDiscount > 0) r.row('تخفیف', money(t.totalDiscount));
  if (t.vat > 0) r.row('مالیات بر ارزش افزوده', money(t.vat));
  if (t.shipping > 0) r.row('هزینه حمل', money(t.shipping));

  r.divider('=');
  r.raw(CMD.BOLD_ON);
  r.row('قابل پرداخت', `${money(t.grandTotal)} ${unit}`);
  r.raw(CMD.BOLD_OFF);

  if (paid > 0) {
    r.row('پرداخت شده', money(paid));
    r.row('مانده', money(t.grandTotal - paid));
  }

  r.feed();
  r.text(moneyToWords(t.grandTotal, unit));
  r.feed();

  r.center(options.footer ?? 'از خرید شما سپاسگزاریم');
  if (options.openDrawer) r.openDrawer();
  if (options.cut !== false) r.cut();

  return r;
}
