import { addMoney, bankersRound, type Rial } from './money.js';
import { computeInvoice, lineGross } from './invoice.js';
import { dateToJalali, JALALI_MONTHS, jalaliToDate, jalaliMonthLength } from './jalali.js';
import type { ID, Invoice, Party, Product } from './types.js';

/**
 * ═══════════════════════════════════════════════════════════════
 *  تحلیل فروش
 * ═══════════════════════════════════════════════════════════════
 *
 * هشت گزارش موجود همگی حسابداری کلاسیک‌اند: ترازنامه، تراز آزمایشی،
 * دفتر روزنامه و مانند آن. هیچ‌کدام به سؤال روزمرهٔ مغازه‌دار پاسخ
 * نمی‌دهد:
 *
 *   «کدام کالا برایم سود دارد؟»
 *   «کدام مشتری بیشتر می‌خرد؟»
 *   «فروشم نسبت به ماه قبل چطور است؟»
 *
 * این ماژول از خودِ فاکتورها محاسبه می‌کند، نه از دفتر — چون
 * بهای تمام‌شده روی ردیف فاکتور ذخیره شده و تفکیک کالا فقط آنجاست.
 */

export interface DateRange {
  from?: string;
  to?: string;
}

function inRange(date: string, r: DateRange): boolean {
  if (r.from && date < r.from) return false;
  if (r.to && date > r.to) return false;
  return true;
}

/** فاکتورهای مؤثر بر فروش (پیش‌فاکتور و باطل‌شده کنار می‌روند) */
function salesInvoices(invoices: Invoice[], range: DateRange): Invoice[] {
  return invoices.filter(
    (i) =>
      !i.deletedAt &&
      i.status !== 'void' &&
      (i.type === 'sale' || i.type === 'sale_return') &&
      inRange(i.date, range),
  );
}

// ─────────────────── سود به تفکیک کالا ───────────────────

export interface ProductPerformance {
  productId: ID;
  name: string;
  /** تعداد فروخته‌شده منهای برگشتی */
  qty: number;
  revenue: Rial;
  cogs: Rial;
  profit: Rial;
  /** حاشیهٔ سود بر حسب درصد */
  margin: number;
  invoiceCount: number;
}

/**
 * عملکرد هر کالا.
 *
 * برگشت از فروش با علامت منفی لحاظ می‌شود تا سود واقعی به‌دست آید،
 * نه سود ناخالص پیش از برگشت.
 */
export function productPerformance(
  invoices: Invoice[],
  products: Map<ID, Product>,
  range: DateRange = {},
): ProductPerformance[] {
  const acc = new Map<ID, { qty: number; revenue: Rial; cogs: Rial; invoices: Set<ID> }>();

  for (const inv of salesInvoices(invoices, range)) {
    const sign = inv.type === 'sale_return' ? -1 : 1;
    const totals = computeInvoice(inv);

    inv.lines.forEach((line, i) => {
      const cur = acc.get(line.productId) ?? {
        qty: 0, revenue: 0, cogs: 0, invoices: new Set<ID>(),
      };
      cur.qty += sign * line.qty;
      cur.revenue += sign * (totals.lines[i]?.net ?? 0);
      cur.cogs += sign * (line.cogs ?? 0);
      cur.invoices.add(inv.id);
      acc.set(line.productId, cur);
    });
  }

  const out: ProductPerformance[] = [];
  for (const [productId, v] of acc) {
    const profit = v.revenue - v.cogs;
    out.push({
      productId,
      name: products.get(productId)?.name ?? 'کالای حذف‌شده',
      qty: v.qty,
      revenue: bankersRound(v.revenue),
      cogs: bankersRound(v.cogs),
      profit: bankersRound(profit),
      margin: v.revenue !== 0 ? bankersRound((profit / v.revenue) * 1000) / 10 : 0,
      invoiceCount: v.invoices.size,
    });
  }

  return out.sort((a, b) => b.profit - a.profit);
}

// ─────────────────── عملکرد مشتریان ───────────────────

export interface CustomerPerformance {
  partyId: ID;
  name: string;
  revenue: Rial;
  profit: Rial;
  invoiceCount: number;
  /** میانگین مبلغ هر فاکتور */
  averageInvoice: Rial;
  lastPurchase?: string;
}

export function customerPerformance(
  invoices: Invoice[],
  parties: Map<ID, Party>,
  range: DateRange = {},
): CustomerPerformance[] {
  const acc = new Map<ID, { revenue: Rial; cogs: Rial; count: number; last: string }>();

  for (const inv of salesInvoices(invoices, range)) {
    if (!inv.partyId) continue;
    const sign = inv.type === 'sale_return' ? -1 : 1;
    const totals = computeInvoice(inv);
    const cogs = addMoney(...inv.lines.map((l) => l.cogs ?? 0));

    const cur = acc.get(inv.partyId) ?? { revenue: 0, cogs: 0, count: 0, last: '' };
    cur.revenue += sign * totals.net;
    cur.cogs += sign * cogs;
    if (inv.type === 'sale') cur.count += 1;
    if (inv.date > cur.last) cur.last = inv.date;
    acc.set(inv.partyId, cur);
  }

  const out: CustomerPerformance[] = [];
  for (const [partyId, v] of acc) {
    out.push({
      partyId,
      name: parties.get(partyId)?.name ?? 'شخص حذف‌شده',
      revenue: bankersRound(v.revenue),
      profit: bankersRound(v.revenue - v.cogs),
      invoiceCount: v.count,
      averageInvoice: v.count > 0 ? bankersRound(v.revenue / v.count) : 0,
      lastPurchase: v.last || undefined,
    });
  }

  return out.sort((a, b) => b.revenue - a.revenue);
}

// ─────────────────── روند ماهانه ───────────────────

export interface MonthlyPoint {
  jy: number;
  jm: number;
  label: string;
  revenue: Rial;
  cogs: Rial;
  profit: Rial;
  invoiceCount: number;
}

/**
 * روند فروش ماه‌به‌ماه بر اساس تقویم شمسی.
 * ماه‌های بدون فروش هم با صفر می‌آیند تا نمودار پیوسته بماند.
 */
export function monthlyTrend(
  invoices: Invoice[],
  range: DateRange = {},
  monthsBack = 12,
): MonthlyPoint[] {
  const buckets = new Map<string, MonthlyPoint>();

  // ساخت سطل‌های خالی از ماه جاری به عقب
  const now = new Date();
  const cur = dateToJalali(now);
  let jy = cur.jy;
  let jm = cur.jm;

  const order: string[] = [];
  for (let i = 0; i < monthsBack; i++) {
    const key = `${jy}-${jm}`;
    order.unshift(key);
    buckets.set(key, {
      jy, jm,
      label: `${JALALI_MONTHS[jm - 1]} ${String(jy).replace(/\d/g, (d) => '۰۱۲۳۴۵۶۷۸۹'[Number(d)]!)}`,
      revenue: 0, cogs: 0, profit: 0, invoiceCount: 0,
    });
    jm -= 1;
    if (jm === 0) { jm = 12; jy -= 1; }
  }

  for (const inv of salesInvoices(invoices, range)) {
    const j = dateToJalali(new Date(inv.date));
    const key = `${j.jy}-${j.jm}`;
    const bucket = buckets.get(key);
    if (!bucket) continue;

    const sign = inv.type === 'sale_return' ? -1 : 1;
    const totals = computeInvoice(inv);
    const cogs = addMoney(...inv.lines.map((l) => l.cogs ?? 0));

    bucket.revenue += sign * totals.net;
    bucket.cogs += sign * cogs;
    bucket.profit = bucket.revenue - bucket.cogs;
    if (inv.type === 'sale') bucket.invoiceCount += 1;
  }

  return order.map((k) => buckets.get(k)!);
}

/** مقایسهٔ دو دوره — رشد یا افت */
export interface PeriodComparison {
  current: { revenue: Rial; profit: Rial; count: number };
  previous: { revenue: Rial; profit: Rial; count: number };
  revenueChange: number;
  profitChange: number;
  countChange: number;
}

function summarize(invoices: Invoice[], range: DateRange) {
  let revenue = 0, cogs = 0, count = 0;
  for (const inv of salesInvoices(invoices, range)) {
    const sign = inv.type === 'sale_return' ? -1 : 1;
    revenue += sign * computeInvoice(inv).net;
    cogs += sign * addMoney(...inv.lines.map((l) => l.cogs ?? 0));
    if (inv.type === 'sale') count += 1;
  }
  return { revenue: bankersRound(revenue), profit: bankersRound(revenue - cogs), count };
}

function percentChange(now: number, before: number): number {
  if (before === 0) return now === 0 ? 0 : 100;
  return bankersRound(((now - before) / Math.abs(before)) * 1000) / 10;
}

export function comparePeriods(
  invoices: Invoice[],
  current: DateRange,
  previous: DateRange,
): PeriodComparison {
  const c = summarize(invoices, current);
  const p = summarize(invoices, previous);
  return {
    current: c,
    previous: p,
    revenueChange: percentChange(c.revenue, p.revenue),
    profitChange: percentChange(c.profit, p.profit),
    countChange: percentChange(c.count, p.count),
  };
}

/** بازهٔ ماه شمسی جاری و ماه قبل */
export function monthRanges(date = new Date()): { current: DateRange; previous: DateRange } {
  const j = dateToJalali(date);

  const start = (jy: number, jm: number) => jalaliToDate({ jy, jm, jd: 1 }).toISOString().slice(0, 10);
  const end = (jy: number, jm: number) =>
    jalaliToDate({ jy, jm, jd: jalaliMonthLength(jy, jm) }).toISOString().slice(0, 10);

  const pjm = j.jm === 1 ? 12 : j.jm - 1;
  const pjy = j.jm === 1 ? j.jy - 1 : j.jy;

  return {
    current: { from: start(j.jy, j.jm), to: end(j.jy, j.jm) },
    previous: { from: start(pjy, pjm), to: end(pjy, pjm) },
  };
}

// ─────────────────── کالاهای راکد ───────────────────

export interface StaleProduct {
  productId: ID;
  name: string;
  qty: number;
  value: Rial;
  lastSold?: string;
  daysSinceSold: number | null;
}

/**
 * کالاهایی که موجودی دارند ولی مدتی فروش نرفته‌اند.
 * سرمایهٔ خوابیده‌ای که مغازه‌دار معمولاً از آن بی‌خبر است.
 */
export function staleProducts(
  invoices: Invoice[],
  products: Product[],
  stock: Map<ID, { qty: number; value: Rial }>,
  opts: { today?: Date; minDays?: number } = {},
): StaleProduct[] {
  const today = opts.today ?? new Date();
  const minDays = opts.minDays ?? 60;

  const lastSold = new Map<ID, string>();
  for (const inv of invoices) {
    if (inv.deletedAt || inv.type !== 'sale') continue;
    for (const l of inv.lines) {
      const prev = lastSold.get(l.productId);
      if (!prev || inv.date > prev) lastSold.set(l.productId, inv.date);
    }
  }

  const out: StaleProduct[] = [];
  for (const p of products) {
    if (p.kind !== 'goods' || p.archived) continue;
    const s = stock.get(p.id);
    if (!s || s.qty <= 0) continue;

    const last = lastSold.get(p.id);
    const days = last
      ? Math.floor((today.getTime() - new Date(last).getTime()) / 86_400_000)
      : null;

    if (days !== null && days < minDays) continue;

    out.push({
      productId: p.id,
      name: p.name,
      qty: s.qty,
      value: s.value,
      lastSold: last,
      daysSinceSold: days,
    });
  }

  return out.sort((a, b) => b.value - a.value);
}

// ─────────────────── خلاصه ───────────────────

export interface SalesSummary {
  revenue: Rial;
  profit: Rial;
  margin: number;
  invoiceCount: number;
  averageInvoice: Rial;
  topProduct?: { name: string; profit: Rial };
  topCustomer?: { name: string; revenue: Rial };
}

export function salesSummary(
  invoices: Invoice[],
  products: Map<ID, Product>,
  parties: Map<ID, Party>,
  range: DateRange = {},
): SalesSummary {
  const s = summarize(invoices, range);
  const byProduct = productPerformance(invoices, products, range);
  const byCustomer = customerPerformance(invoices, parties, range);

  return {
    revenue: s.revenue,
    profit: s.profit,
    margin: s.revenue !== 0 ? bankersRound((s.profit / s.revenue) * 1000) / 10 : 0,
    invoiceCount: s.count,
    averageInvoice: s.count > 0 ? bankersRound(s.revenue / s.count) : 0,
    topProduct: byProduct[0] ? { name: byProduct[0].name, profit: byProduct[0].profit } : undefined,
    topCustomer: byCustomer[0] ? { name: byCustomer[0].name, revenue: byCustomer[0].revenue } : undefined,
  };
}
