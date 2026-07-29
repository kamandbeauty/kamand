/**
 * پول در جاوید همیشه عدد صحیح (ریال) است، هرگز اعشاری.
 * محاسبات ممیز شناور در نرم‌افزار مالی منجر به خطای انباشته می‌شود.
 */

export type Rial = number;

const MAX_SAFE_RIAL = Number.MAX_SAFE_INTEGER;

export function rial(value: number): Rial {
  if (!Number.isFinite(value)) throw new Error('مبلغ نامعتبر است');
  const rounded = Math.round(value);
  if (Math.abs(rounded) > MAX_SAFE_RIAL) throw new Error('مبلغ خارج از محدودهٔ مجاز است');
  return rounded;
}

/** تومان به ریال */
export function toman(value: number): Rial {
  return rial(value * 10);
}

export function addMoney(...values: Rial[]): Rial {
  return values.reduce<Rial>((sum, v) => rial(sum + v), 0);
}

export function subMoney(a: Rial, b: Rial): Rial {
  return rial(a - b);
}

/**
 * ضرب مبلغ در مقدار (که می‌تواند اعشاری باشد، مثل ۲.۵ کیلو).
 * گرد کردن بانکی (half-even) برای جلوگیری از سوگیری انباشته.
 */
export function mulMoney(amount: Rial, qty: number): Rial {
  if (!Number.isFinite(qty)) throw new Error('مقدار نامعتبر است');
  return bankersRound(amount * qty);
}

/** درصد گرفتن از مبلغ — مثلاً مالیات یا تخفیف */
export function percentOf(amount: Rial, percent: number): Rial {
  if (!Number.isFinite(percent)) throw new Error('درصد نامعتبر است');
  return bankersRound((amount * percent) / 100);
}

/** گرد کردن نیم-زوج: ۰.۵ به نزدیک‌ترین عدد زوج گرد می‌شود */
export function bankersRound(value: number): number {
  const floor = Math.floor(value);
  const diff = value - floor;
  const EPS = 1e-9;
  if (Math.abs(diff - 0.5) < EPS) return floor % 2 === 0 ? floor : floor + 1;
  return Math.round(value);
}

/**
 * تقسیم مبلغ بین n سهم بدون گم شدن ریال.
 * باقی‌مانده به ترتیب بین سهم‌های اول توزیع می‌شود تا جمع دقیقاً برابر اصل بماند.
 */
export function allocate(amount: Rial, ratios: number[]): Rial[] {
  if (ratios.length === 0) throw new Error('نسبت‌ها خالی است');
  if (ratios.some((r) => r < 0)) throw new Error('نسبت منفی مجاز نیست');
  const total = ratios.reduce((a, b) => a + b, 0);
  if (total === 0) throw new Error('جمع نسبت‌ها صفر است');

  const shares = ratios.map((r) => Math.floor((amount * r) / total));
  let remainder = amount - shares.reduce((a, b) => a + b, 0);
  for (let i = 0; remainder > 0 && i < shares.length; i++, remainder--) {
    shares[i] = (shares[i] ?? 0) + 1;
  }
  return shares;
}

const ONES = ['', 'یک', 'دو', 'سه', 'چهار', 'پنج', 'شش', 'هفت', 'هشت', 'نه'];
const TEENS = ['ده', 'یازده', 'دوازده', 'سیزده', 'چهارده', 'پانزده', 'شانزده', 'هفده', 'هجده', 'نوزده'];
const TENS = ['', '', 'بیست', 'سی', 'چهل', 'پنجاه', 'شصت', 'هفتاد', 'هشتاد', 'نود'];
const HUNDREDS = ['', 'صد', 'دویست', 'سیصد', 'چهارصد', 'پانصد', 'ششصد', 'هفتصد', 'هشتصد', 'نهصد'];
const SCALES = ['', ' هزار', ' میلیون', ' میلیارد', ' بیلیون'];

function threeDigitsToWords(n: number): string {
  const parts: string[] = [];
  const h = Math.floor(n / 100);
  const rest = n % 100;
  if (h > 0) parts.push(HUNDREDS[h]!);
  if (rest >= 10 && rest < 20) {
    parts.push(TEENS[rest - 10]!);
  } else {
    const t = Math.floor(rest / 10);
    const o = rest % 10;
    if (t > 0) parts.push(TENS[t]!);
    if (o > 0) parts.push(ONES[o]!);
  }
  return parts.join(' و ');
}

/** مبلغ به حروف فارسی — برای چاپ روی فاکتور رسمی لازم است */
export function moneyToWords(amount: Rial, unit = 'ریال'): string {
  if (amount === 0) return `صفر ${unit}`;
  const negative = amount < 0;
  let n = Math.abs(amount);

  const groups: number[] = [];
  while (n > 0) {
    groups.push(n % 1000);
    n = Math.floor(n / 1000);
  }

  const words = groups
    .map((g, i) => (g === 0 ? '' : threeDigitsToWords(g) + SCALES[i]))
    .filter(Boolean)
    .reverse()
    .join(' و ');

  return `${negative ? 'منفی ' : ''}${words} ${unit}`;
}

const FA_DIGITS = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

export function toPersianDigits(input: string | number): string {
  return String(input).replace(/\d/g, (d) => FA_DIGITS[Number(d)]!);
}

export function toLatinDigits(input: string): string {
  return input
    .replace(/[۰-۹]/g, (d) => String(d.charCodeAt(0) - 0x06f0))
    .replace(/[٠-٩]/g, (d) => String(d.charCodeAt(0) - 0x0660));
}

/** قالب‌بندی مبلغ با جداکنندهٔ هزارگان و ارقام فارسی */
export function formatMoney(amount: Rial, opts: { persian?: boolean; unit?: string } = {}): string {
  const { persian = true, unit } = opts;
  const sign = amount < 0 ? '-' : '';
  const grouped = Math.abs(amount).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  const out = sign + (persian ? toPersianDigits(grouped) : grouped);
  return unit ? `${out} ${unit}` : out;
}
