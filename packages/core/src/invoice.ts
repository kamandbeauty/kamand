import { addMoney, allocate, bankersRound, mulMoney, percentOf, type Rial } from './money.js';
import type { ID, Invoice, InvoiceLine, InvoiceType } from './types.js';

/** محاسبات فاکتور — مستقل از رابط کاربری و قابل تست */

export interface LineTotals {
  gross: Rial;
  discount: Rial;
  /** سهم این سطر از تخفیف کلی فاکتور */
  allocatedDiscount: Rial;
  net: Rial;
  vat: Rial;
  total: Rial;
}

export interface InvoiceTotals {
  lines: LineTotals[];
  subtotal: Rial;
  lineDiscount: Rial;
  invoiceDiscount: Rial;
  totalDiscount: Rial;
  net: Rial;
  vat: Rial;
  shipping: Rial;
  grandTotal: Rial;
}

export function lineGross(line: InvoiceLine): Rial {
  return mulMoney(line.unitPrice, line.qty);
}

/**
 * محاسبهٔ کامل فاکتور.
 * تخفیف کلی به نسبت مبلغ خالص هر سطر بین سطرها سرشکن می‌شود
 * تا مالیات هر سطر درست محاسبه شود و ریالی گم نشود.
 */
export function computeInvoice(invoice: Pick<Invoice, 'lines' | 'discount' | 'shipping'>): InvoiceTotals {
  const grosses = invoice.lines.map(lineGross);
  const netsBeforeInvoiceDiscount = invoice.lines.map((l, i) =>
    Math.max(0, (grosses[i] ?? 0) - l.discount),
  );

  const subtotal = addMoney(...grosses);
  const lineDiscount = addMoney(...invoice.lines.map((l) => l.discount));
  const baseTotal = addMoney(...netsBeforeInvoiceDiscount);

  // تخفیف کلی نمی‌تواند از مبلغ فاکتور بیشتر باشد
  const invoiceDiscount = Math.min(invoice.discount, baseTotal);

  const allocated =
    invoiceDiscount > 0 && baseTotal > 0
      ? allocate(invoiceDiscount, netsBeforeInvoiceDiscount)
      : invoice.lines.map(() => 0);

  const lines: LineTotals[] = invoice.lines.map((l, i) => {
    const gross = grosses[i] ?? 0;
    const allocatedDiscount = allocated[i] ?? 0;
    const net = Math.max(0, (netsBeforeInvoiceDiscount[i] ?? 0) - allocatedDiscount);
    const vat = percentOf(net, l.vatRate);
    return {
      gross,
      discount: l.discount,
      allocatedDiscount,
      net,
      vat,
      total: addMoney(net, vat),
    };
  });

  const net = addMoney(...lines.map((l) => l.net));
  const vat = addMoney(...lines.map((l) => l.vat));
  const shipping = invoice.shipping;

  return {
    lines,
    subtotal,
    lineDiscount,
    invoiceDiscount,
    totalDiscount: addMoney(lineDiscount, invoiceDiscount),
    net,
    vat,
    shipping,
    grandTotal: addMoney(net, vat, shipping),
  };
}

/** سود فاکتور = خالص فروش منهای بهای تمام‌شده */
export function invoiceProfit(invoice: Invoice): Rial {
  const t = computeInvoice(invoice);
  const cogs = addMoney(...invoice.lines.map((l) => l.cogs ?? 0));
  return t.net - cogs;
}

/** آیا این نوع فاکتور کالا را از انبار خارج می‌کند؟ */
export function isOutbound(type: InvoiceType): boolean {
  return type === 'sale' || type === 'waste' || type === 'purchase_return';
}

export function isInbound(type: InvoiceType): boolean {
  return type === 'purchase' || type === 'sale_return';
}

/** فاکتورهایی که روی انبار اثر دارند (پیش‌فاکتور ندارد) */
export function affectsStock(type: InvoiceType): boolean {
  return type !== 'quote';
}

export function affectsLedger(type: InvoiceType): boolean {
  return type !== 'quote';
}

export const INVOICE_TYPE_LABELS: Record<InvoiceType, string> = {
  quote: 'پیش‌فاکتور',
  sale: 'فاکتور فروش',
  purchase: 'فاکتور خرید',
  sale_return: 'برگشت از فروش',
  purchase_return: 'برگشت از خرید',
  waste: 'ضایعات',
};

/** شمارهٔ بعدی فاکتور برای هر نوع، به تفکیک سال مالی */
export function nextInvoiceNumber(existing: string[], prefix: string): string {
  let max = 0;
  const re = new RegExp(`^${prefix}-(\\d+)$`);
  for (const n of existing) {
    const m = n.match(re);
    if (m) max = Math.max(max, Number(m[1]));
  }
  return `${prefix}-${String(max + 1).padStart(4, '0')}`;
}

/** اعتبارسنجی فاکتور پیش از ثبت */
export function validateInvoice(invoice: Invoice): string[] {
  const errors: string[] = [];
  if (invoice.lines.length === 0) errors.push('فاکتور باید حداقل یک ردیف داشته باشد');

  invoice.lines.forEach((l, i) => {
    const n = i + 1;
    if (l.qty <= 0) errors.push(`ردیف ${n}: مقدار باید بزرگ‌تر از صفر باشد`);
    if (l.unitPrice < 0) errors.push(`ردیف ${n}: قیمت واحد نمی‌تواند منفی باشد`);
    if (l.discount < 0) errors.push(`ردیف ${n}: تخفیف نمی‌تواند منفی باشد`);
    if (l.discount > lineGross(l)) errors.push(`ردیف ${n}: تخفیف از مبلغ ردیف بیشتر است`);
    if (l.vatRate < 0 || l.vatRate > 100) errors.push(`ردیف ${n}: نرخ مالیات نامعتبر است`);
  });

  if (invoice.discount < 0) errors.push('تخفیف کلی نمی‌تواند منفی باشد');
  if (invoice.shipping < 0) errors.push('هزینهٔ حمل نمی‌تواند منفی باشد');

  const needsParty: InvoiceType[] = ['sale', 'purchase', 'sale_return', 'purchase_return'];
  if (needsParty.includes(invoice.type) && !invoice.partyId) {
    errors.push('انتخاب طرف حساب الزامی است');
  }

  if (invoice.isOfficial) {
    if (!invoice.partyId) errors.push('فاکتور رسمی بدون طرف حساب مجاز نیست');
    const totals = computeInvoice(invoice);
    if (totals.grandTotal <= 0) errors.push('مبلغ فاکتور رسمی باید بزرگ‌تر از صفر باشد');
  }

  return errors;
}

/** وضعیت پرداخت بر اساس مبلغ تسویه‌شده */
export function paymentStatus(grandTotal: Rial, paid: Rial): Invoice['status'] {
  if (paid <= 0) return 'open';
  if (paid >= grandTotal) return 'paid';
  return 'partial';
}

/** تبدیل پیش‌فاکتور به فاکتور فروش */
export function quoteToSale(quote: Invoice, id: ID, number: string, now: string): Invoice {
  if (quote.type !== 'quote') throw new Error('فقط پیش‌فاکتور قابل تبدیل است');
  return {
    ...quote,
    id,
    type: 'sale',
    number,
    status: 'open',
    createdAt: now,
    updatedAt: now,
    lines: quote.lines.map((l) => ({ ...l })),
  };
}

/** تولید فاکتور برگشتی از روی فاکتور اصلی */
export function createReturn(
  source: Invoice,
  id: ID,
  number: string,
  now: string,
  lineQtys?: Map<ID, number>,
): Invoice {
  const type: InvoiceType =
    source.type === 'sale' ? 'sale_return' : source.type === 'purchase' ? 'purchase_return' : 'sale_return';

  const lines = source.lines
    .map((l) => {
      const qty = lineQtys ? lineQtys.get(l.id) ?? 0 : l.qty;
      if (qty <= 0) return null;
      // بهای تمام‌شده به نسبت مقدار برگشتی از فاکتور اصلی می‌آید،
      // تا کالا با همان بهایی که خارج شده بود به انبار بازگردد.
      const line: InvoiceLine = { ...l, qty };
      if (l.cogs !== undefined && l.qty > 0) {
        line.cogs = bankersRound((l.cogs * qty) / l.qty);
      }
      return line;
    })
    .filter((l): l is InvoiceLine => l !== null);

  if (lines.length === 0) throw new Error('هیچ ردیفی برای برگشت انتخاب نشده است');

  return {
    ...source,
    id,
    type,
    number,
    lines,
    discount: 0,
    shipping: 0,
    status: 'open',
    sourceInvoiceId: source.id,
    note: `برگشت از فاکتور ${source.number}`,
    createdAt: now,
    updatedAt: now,
  };
}
