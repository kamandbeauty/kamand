import { toLatinDigits, type Rial } from './money.js';
import type { Cheque, ID, Invoice, Party, Product } from './types.js';

/**
 * ═══════════════════════════════════════════════════════════════
 *  جستجوی سراسری
 * ═══════════════════════════════════════════════════════════════
 *
 * هر صفحه جستجوی خودش را داشت. با ۱۵۰ فاکتور و ۵۰ مشتری، کاربر
 * باید حدس می‌زد چیزی که دنبالش است در کدام صفحه است و به آنجا
 * می‌رفت.
 *
 * این ماژول یک نقطهٔ ورود واحد می‌دهد: کاربر تایپ می‌کند و
 * نتیجه از همهٔ بخش‌ها می‌آید.
 *
 * سه ملاحظهٔ فارسی که در جستجوی معمولی نادیده گرفته می‌شود:
 *  ۱. ارقام فارسی و عربی باید با لاتین یکی شمرده شوند
 *  ۲. «ی» و «ك» عربی با فارسی یکسان‌سازی شوند
 *  ۳. نیم‌فاصله و فاصلهٔ معمولی تفاوتی نکنند
 */

export type SearchKind = 'invoice' | 'party' | 'product' | 'cheque';

export interface SearchHit {
  kind: SearchKind;
  id: ID;
  title: string;
  subtitle?: string;
  amount?: Rial;
  date?: string;
  /** امتیاز تطابق — بالاتر یعنی مرتبط‌تر */
  score: number;
  page: string;
}

/**
 * یکسان‌سازی متن فارسی برای جستجو.
 *
 * بدون این، جستجوی «علی» متنی که با «ي» عربی نوشته شده را پیدا
 * نمی‌کند — مشکلی که در داده‌های واقعی ایرانی بسیار رایج است.
 */
export function normalizeSearchText(input: string): string {
  return toLatinDigits(input)
    .toLowerCase()
    // یکسان‌سازی حروف عربی و فارسی
    .replace(/[يى]/g, 'ی')
    .replace(/ك/g, 'ک')
    .replace(/[ۀة]/g, 'ه')
    .replace(/[أإآ]/g, 'ا')
    .replace(/ؤ/g, 'و')
    // حذف اعراب
    .replace(/[\u064B-\u0652\u0670]/g, '')
    // نیم‌فاصله و فاصلهٔ باریک → فاصلهٔ معمولی
    .replace(/[\u200c\u200f\u200e]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * امتیازدهی تطابق.
 * تطابق کامل > شروع با > شامل. صفر یعنی بی‌ربط.
 */
export function matchScore(haystack: string | undefined, needle: string): number {
  if (!haystack) return 0;
  const h = normalizeSearchText(haystack);
  if (!h) return 0;

  if (h === needle) return 100;
  if (h.startsWith(needle)) return 70;

  // تطابق در ابتدای یک کلمه ارزش بیشتری دارد
  if (h.includes(` ${needle}`)) return 50;
  if (h.includes(needle)) return 30;
  return 0;
}

export interface SearchInput {
  invoices: Invoice[];
  parties: Party[];
  products: Product[];
  cheques: Cheque[];
  /** مبلغ کل هر فاکتور — از بیرون داده می‌شود تا محاسبه تکرار نشود */
  invoiceTotal: (inv: Invoice) => Rial;
  partyName: (id: ID | null | undefined) => string | undefined;
}

const PARTY_KIND_LABEL: Record<Party['kind'], string> = {
  customer: 'مشتری',
  vendor: 'فروشنده',
  shareholder: 'سهامدار',
  employee: 'کارمند',
};

/**
 * جستجو در همهٔ موجودیت‌ها.
 * نتایج بر اساس امتیاز مرتب و به `limit` محدود می‌شوند.
 */
export function globalSearch(
  input: SearchInput,
  rawQuery: string,
  limit = 20,
): SearchHit[] {
  const q = normalizeSearchText(rawQuery);
  if (q.length < 2) return [];

  const hits: SearchHit[] = [];

  // ─── فاکتورها ───
  for (const inv of input.invoices) {
    if (inv.deletedAt) continue;
    const party = input.partyName(inv.partyId);

    const score = Math.max(
      matchScore(inv.number, q),
      matchScore(party, q) * 0.8,
      matchScore(inv.note, q) * 0.5,
    );
    if (score === 0) continue;

    hits.push({
      kind: 'invoice',
      id: inv.id,
      title: `فاکتور ${inv.number}`,
      subtitle: party,
      amount: input.invoiceTotal(inv),
      date: inv.date,
      score,
      page: 'invoices',
    });
  }

  // ─── اشخاص ───
  for (const p of input.parties) {
    if (p.archived) continue;
    const score = Math.max(
      matchScore(p.name, q),
      matchScore(p.phone, q) * 0.9,
      matchScore(p.economicCode, q) * 0.7,
      matchScore(p.nationalId, q) * 0.7,
    );
    if (score === 0) continue;

    hits.push({
      kind: 'party',
      id: p.id,
      title: p.name,
      subtitle: `${PARTY_KIND_LABEL[p.kind]}${p.phone ? ` · ${p.phone}` : ''}`,
      score,
      page: 'parties',
    });
  }

  // ─── کالاها ───
  for (const p of input.products) {
    if (p.archived) continue;
    const score = Math.max(
      matchScore(p.name, q),
      // بارکد معمولاً دقیق اسکن می‌شود، پس تطابق کامل ارزشمند است
      matchScore(p.barcode, q),
      matchScore(p.sku, q) * 0.9,
    );
    if (score === 0) continue;

    hits.push({
      kind: 'product',
      id: p.id,
      title: p.name,
      subtitle: p.barcode ? `بارکد ${p.barcode}` : p.unitMain,
      amount: p.sellPrice,
      score,
      page: 'products',
    });
  }

  // ─── چک‌ها ───
  for (const c of input.cheques) {
    const party = input.partyName(c.partyId);
    const score = Math.max(
      matchScore(c.number, q),
      matchScore(c.bankName, q) * 0.6,
      matchScore(c.sayadId, q) * 0.8,
      matchScore(party, q) * 0.5,
    );
    if (score === 0) continue;

    hits.push({
      kind: 'cheque',
      id: c.id,
      title: `چک ${c.number}`,
      subtitle: `${c.bankName}${party ? ` · ${party}` : ''}`,
      amount: c.amount,
      date: c.dueDate,
      score,
      page: 'treasury',
    });
  }

  return hits
    .sort((a, b) => (b.score - a.score) || (b.date ?? '').localeCompare(a.date ?? ''))
    .slice(0, limit);
}

export const SEARCH_KIND_LABELS: Record<SearchKind, string> = {
  invoice: 'فاکتور',
  party: 'شخص',
  product: 'کالا',
  cheque: 'چک',
};

export const SEARCH_KIND_ICONS: Record<SearchKind, string> = {
  invoice: '🧾',
  party: '👥',
  product: '📦',
  cheque: '🧷',
};

/** گروه‌بندی نتایج بر اساس نوع، برای نمایش تفکیک‌شده */
export function groupHits(hits: SearchHit[]): { kind: SearchKind; items: SearchHit[] }[] {
  const order: SearchKind[] = ['invoice', 'party', 'product', 'cheque'];
  const out: { kind: SearchKind; items: SearchHit[] }[] = [];

  for (const kind of order) {
    const items = hits.filter((h) => h.kind === kind);
    if (items.length > 0) out.push({ kind, items });
  }
  return out;
}

// ─────────────────── فیلتر وضعیت پرداخت ───────────────────

export type PaymentFilter = 'all' | 'unpaid' | 'partial' | 'paid' | 'overdue';

export const PAYMENT_FILTER_LABELS: Record<PaymentFilter, string> = {
  all: 'همه',
  unpaid: 'تسویه‌نشده',
  partial: 'پرداخت جزئی',
  paid: 'تسویه‌شده',
  overdue: 'سررسید گذشته',
};

export interface InvoiceStatusInfo {
  total: Rial;
  paid: Rial;
  remaining: Rial;
  isOverdue: boolean;
}

/**
 * فیلتر فاکتورها بر اساس وضعیت پرداخت.
 *
 * پیش‌تر فقط فیلتر نوع فاکتور وجود داشت. مغازه‌داری که می‌خواست
 * بداند کدام فاکتورها تسویه نشده‌اند، باید ستون مانده را چشمی
 * می‌گشت.
 */
export function filterByPayment(
  invoices: Invoice[],
  filter: PaymentFilter,
  info: (inv: Invoice) => InvoiceStatusInfo,
): Invoice[] {
  if (filter === 'all') return invoices;

  return invoices.filter((inv) => {
    if (inv.type === 'quote') return false;
    const s = info(inv);

    switch (filter) {
      case 'unpaid': return s.remaining > 0;
      case 'partial': return s.paid > 0 && s.remaining > 0;
      case 'paid': return s.remaining <= 0 && s.total > 0;
      case 'overdue': return s.remaining > 0 && s.isOverdue;
      default: return true;
    }
  });
}

/** خلاصهٔ وضعیت پرداخت برای نمایش بالای فهرست */
export function paymentSummary(
  invoices: Invoice[],
  info: (inv: Invoice) => InvoiceStatusInfo,
): { unpaidCount: number; unpaidAmount: Rial; overdueCount: number; overdueAmount: Rial } {
  let unpaidCount = 0, unpaidAmount = 0, overdueCount = 0, overdueAmount = 0;

  for (const inv of invoices) {
    if (inv.deletedAt || inv.type === 'quote') continue;
    const s = info(inv);
    if (s.remaining <= 0) continue;

    unpaidCount += 1;
    unpaidAmount += s.remaining;
    if (s.isOverdue) {
      overdueCount += 1;
      overdueAmount += s.remaining;
    }
  }

  return { unpaidCount, unpaidAmount, overdueCount, overdueAmount };
}
