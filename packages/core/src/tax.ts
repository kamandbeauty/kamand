import { addMoney, bankersRound, type Rial } from './money.js';
import { computeInvoice } from './invoice.js';
import { dateToJalali, jalaliMonthLength, jalaliToDate } from './jalali.js';
import type { Business, ID, Invoice, Party, Product } from './types.js';

/**
 * ═══════════════════════════════════════════════════════════════
 *  سامانهٔ مؤدیان و پایانه‌های فروشگاهی
 * ═══════════════════════════════════════════════════════════════
 *
 * این ماژول بزرگ‌ترین شکاف کارکردی رقبای موبایلی را پر می‌کند:
 * آن‌ها «فاکتور رسمی» صادر می‌کنند ولی از نظر مالیاتی رسمی نیست،
 * چون شمارهٔ منحصربه‌فرد مالیاتی ندارد و به سامانه ارسال نمی‌شود.
 *
 * ⚠️ نکتهٔ نگهداری: الگوها و اقلام اطلاعاتی صورتحساب الکترونیکی
 * توسط سازمان امور مالیاتی بروزرسانی می‌شوند. به همین دلیل این ماژول
 * «نسخه‌پذیر» طراحی شده و شمارهٔ نسخهٔ دستورالعمل در خروجی درج می‌شود.
 * پیش از استفادهٔ عملیاتی، آخرین دستورالعمل را از intamedia.ir بررسی کنید.
 */

export const TAX_SPEC_VERSION = '7.x';

// ─────────────────────── الگوریتم Verhoeff ───────────────────────

/**
 * جدول ضرب گروه دووجهی D5 — پایهٔ الگوریتم Verhoeff.
 * این الگوریتم تقریباً همهٔ خطاهای تک‌رقمی و جابه‌جایی ارقام مجاور را می‌گیرد.
 */
const D5_MULT: readonly (readonly number[])[] = [
  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
  [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
  [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
  [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
  [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
  [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
  [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
  [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
  [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
  [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
];

const D5_PERM: readonly (readonly number[])[] = [
  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
  [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
  [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
  [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
  [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
  [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
  [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
  [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
];

const D5_INV: readonly number[] = [0, 4, 3, 2, 1, 5, 6, 7, 8, 9];

/**
 * محاسبهٔ رقم کنترلی Verhoeff.
 * ورودی می‌تواند شامل حروف باشد (مثل شناسهٔ حافظه)؛ در آن صورت
 * کد نویسهٔ هر حرف به ارقام تبدیل و در محاسبه لحاظ می‌شود.
 */
export function verhoeffCheckDigit(input: string): number {
  const digits = toDigitStream(input);
  let c = 0;
  const reversed = [...digits].reverse();
  for (let i = 0; i < reversed.length; i++) {
    const p = D5_PERM[(i + 1) % 8]![reversed[i]!]!;
    c = D5_MULT[c]![p]!;
  }
  return D5_INV[c]!;
}

export function verhoeffValidate(input: string): boolean {
  const digits = toDigitStream(input);
  let c = 0;
  const reversed = [...digits].reverse();
  for (let i = 0; i < reversed.length; i++) {
    const p = D5_PERM[i % 8]![reversed[i]!]!;
    c = D5_MULT[c]![p]!;
  }
  return c === 0;
}

/** تبدیل رشتهٔ الفبا-عددی به جریان ارقام برای محاسبهٔ رقم کنترلی */
function toDigitStream(input: string): number[] {
  const out: number[] = [];
  for (const ch of input.toUpperCase()) {
    if (ch >= '0' && ch <= '9') {
      out.push(Number(ch));
    } else {
      // هر حرف با کد نویسه‌اش به ارقام تجزیه می‌شود
      for (const d of String(ch.charCodeAt(0))) out.push(Number(d));
    }
  }
  return out;
}

// ─────────────────── شناسهٔ یکتای حافظهٔ مالیاتی ───────────────────

/**
 * کاراکترهای مجاز در شناسهٔ حافظهٔ مالیاتی.
 * حروف I, J, L, Q, V و رقم ۰ به دلیل شباهت بصری ممنوع‌اند.
 */
export const MEMORY_ID_ALPHABET = 'ADEFGHKMNOPRTWXYZ123456789';

export function isValidMemoryId(id: string): boolean {
  if (id.length !== 6) return false;
  const up = id.toUpperCase();
  return [...up].every((c) => MEMORY_ID_ALPHABET.includes(c));
}

// ─────────────────── شمارهٔ منحصربه‌فرد مالیاتی ───────────────────

/**
 * ساختار ۲۲ کاراکتری شمارهٔ منحصربه‌فرد مالیاتی:
 *
 *   [۶ کاراکتر] شناسهٔ یکتای حافظهٔ مالیاتی
 *   [۵ کاراکتر] تاریخ ثبت — تعداد روز از ۱۹۷۰/۰۱/۰۱ به مبنای ۱۶
 *   [۱۰ کاراکتر] سریال داخلی صورتحساب به مبنای ۱۶
 *   [۱ کاراکتر] رقم کنترلی Verhoeff
 */
export interface TaxIdParts {
  memoryId: string;
  daysSinceEpoch: number;
  serial: number;
  checkDigit: number;
}

const MS_PER_DAY = 86_400_000;

export function daysSinceEpoch(date: Date): number {
  return Math.floor(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()) / MS_PER_DAY,
  );
}

export class TaxIdError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'TaxIdError';
  }
}

/** تولید شمارهٔ منحصربه‌فرد مالیاتی */
export function generateTaxId(memoryId: string, date: Date, serial: number): string {
  const mem = memoryId.toUpperCase();
  if (!isValidMemoryId(mem)) {
    throw new TaxIdError('شناسهٔ حافظهٔ مالیاتی باید ۶ کاراکتر از حروف و ارقام مجاز باشد');
  }
  if (!Number.isInteger(serial) || serial < 0) {
    throw new TaxIdError('سریال صورتحساب باید عدد صحیح نامنفی باشد');
  }

  const days = daysSinceEpoch(date);
  if (days < 0) throw new TaxIdError('تاریخ صورتحساب نامعتبر است');

  const daysHex = days.toString(16).toUpperCase().padStart(5, '0');
  if (daysHex.length > 5) throw new TaxIdError('تاریخ صورتحساب خارج از محدودهٔ مجاز است');

  const serialHex = serial.toString(16).toUpperCase().padStart(10, '0');
  if (serialHex.length > 10) throw new TaxIdError('سریال صورتحساب خارج از محدودهٔ مجاز است');

  const body = `${mem}${daysHex}${serialHex}`;
  return `${body}${verhoeffCheckDigit(body)}`;
}

/** تجزیهٔ شمارهٔ مالیاتی به مؤلفه‌هایش */
export function parseTaxId(taxId: string): TaxIdParts {
  if (taxId.length !== 22) throw new TaxIdError('شمارهٔ مالیاتی باید دقیقاً ۲۲ کاراکتر باشد');
  const up = taxId.toUpperCase();
  return {
    memoryId: up.slice(0, 6),
    daysSinceEpoch: parseInt(up.slice(6, 11), 16),
    serial: parseInt(up.slice(11, 21), 16),
    checkDigit: Number(up.slice(21)),
  };
}

export function validateTaxId(taxId: string): boolean {
  if (taxId.length !== 22) return false;
  const up = taxId.toUpperCase();
  const body = up.slice(0, 21);
  const check = Number(up.slice(21));
  if (!Number.isInteger(check)) return false;
  if (!isValidMemoryId(up.slice(0, 6))) return false;
  if (!/^[0-9A-F]{15}$/.test(up.slice(6, 21))) return false;
  return verhoeffCheckDigit(body) === check;
}

/** تاریخ ثبت را از شمارهٔ مالیاتی بازیابی می‌کند */
export function taxIdDate(taxId: string): Date {
  return new Date(parseTaxId(taxId).daysSinceEpoch * MS_PER_DAY);
}

// ─────────────────── صورتحساب الکترونیکی ───────────────────

/** نوع صورتحساب: اول = B2B با اطلاعات خریدار، دوم = خرده‌فروشی */
export type InvoiceSubjectType = 1 | 2 | 3;

/** الگوهای صورتحساب نوع اول */
export const INVOICE_PATTERNS = {
  SALE: 1,
  CURRENCY: 2,
  GOLD: 3,
  CONTRACTOR: 4,
  UTILITY: 5,
  AIRLINE: 6,
  EXPORT: 7,
} as const;

export type InvoicePattern = (typeof INVOICE_PATTERNS)[keyof typeof INVOICE_PATTERNS];

/** موضوع صورتحساب: اصلی، اصلاحی، ابطالی، برگشت از فروش */
export const INVOICE_SUBJECTS = {
  ORIGINAL: 1,
  CORRECTIVE: 2,
  CANCELLING: 3,
  RETURN: 4,
} as const;

export type InvoiceSubject = (typeof INVOICE_SUBJECTS)[keyof typeof INVOICE_SUBJECTS];

export const SUBJECT_LABELS: Record<InvoiceSubject, string> = {
  1: 'صورتحساب اصلی',
  2: 'صورتحساب اصلاحی',
  3: 'صورتحساب ابطالی',
  4: 'برگشت از فروش',
};

export type SubmissionStatus =
  | 'draft'
  | 'queued'
  | 'sent'
  | 'accepted'
  | 'rejected'
  | 'cancelled';

export const SUBMISSION_LABELS: Record<SubmissionStatus, string> = {
  draft: 'پیش‌نویس',
  queued: 'در صف ارسال',
  sent: 'ارسال شده',
  accepted: 'پذیرفته شده',
  rejected: 'رد شده',
  cancelled: 'ابطال شده',
};

/** رکورد ارسال یک صورتحساب به سامانه */
export interface TaxSubmission {
  id: ID;
  businessId: ID;
  invoiceId: ID;
  taxId: string;
  serial: number;
  subject: InvoiceSubject;
  pattern: InvoicePattern;
  subjectType: InvoiceSubjectType;
  status: SubmissionStatus;
  referenceNumber?: string;
  confirmationNumber?: string;
  errors?: { code: string; message: string }[];
  /** شمارهٔ مالیاتی صورتحساب مرجع در اصلاحیه/ابطالیه */
  referencedTaxId?: string | null;
  submittedAt?: string | null;
  respondedAt?: string | null;
  createdAt: string;
}

/**
 * بستهٔ اقلام اطلاعاتی صورتحساب مطابق ساختار سامانه.
 * نام فیلدها عمداً مطابق مستندات سازمان است تا نگاشت ساده بماند.
 */
export interface ElectronicInvoice {
  /** سربرگ */
  header: {
    taxid: string;
    indatim: number;
    indati2m: number;
    inty: InvoiceSubjectType;
    inno: string;
    irtaxid?: string | null;
    inp: InvoicePattern;
    ins: InvoiceSubject;
    tins: string;
    tob: number;
    bid?: string | null;
    tinb?: string | null;
    sbc?: string | null;
    bpc?: string | null;
    tprdis: Rial;
    tdis: Rial;
    tadis: Rial;
    tvam: Rial;
    tbill: Rial;
    setm: number;
    cap: Rial;
    insp: Rial;
  };
  /** اقلام */
  body: {
    sstid: string;
    sstt: string;
    am: number;
    mu: string;
    fee: Rial;
    prdis: Rial;
    dis: Rial;
    adis: Rial;
    vra: number;
    vam: Rial;
    tsstam: Rial;
  }[];
  /** فراداده — بخشی از استاندارد نیست، برای ردیابی داخلی */
  meta: {
    specVersion: string;
    generatedAt: string;
  };
}

export interface TaxProfile {
  /** شناسهٔ یکتای حافظهٔ مالیاتی از کارپوشه */
  memoryId: string;
  /** شمارهٔ اقتصادی فروشنده */
  sellerTin: string;
  /** نوع شخص: ۱ حقیقی، ۲ حقوقی، ۳ مشارکت مدنی، ۴ غیرایرانی */
  sellerType: number;
  /** آخرین سریال مصرف‌شده */
  lastSerial: number;
}

export class TaxValidationError extends Error {
  readonly issues: string[];
  constructor(issues: string[]) {
    super(issues.join('؛ '));
    this.name = 'TaxValidationError';
    this.issues = issues;
  }
}

/**
 * اعتبارسنجی پیش از ارسال.
 * هدف: خطاها را پیش از رسیدن به سامانه بگیریم، چون رد شدن صورتحساب
 * در سامانه هزینهٔ اصلاح دارد.
 */
export function validateForTaxSystem(
  invoice: Invoice,
  buyer: Party | null,
  products: Map<ID, Product>,
  profile: TaxProfile,
  subjectType: InvoiceSubjectType = 1,
): string[] {
  const issues: string[] = [];

  if (!isValidMemoryId(profile.memoryId)) {
    issues.push('شناسهٔ یکتای حافظهٔ مالیاتی تنظیم نشده یا نامعتبر است');
  }
  if (!profile.sellerTin?.trim()) {
    issues.push('شمارهٔ اقتصادی فروشنده ثبت نشده است');
  }
  if (invoice.lines.length === 0) {
    issues.push('صورتحساب باید حداقل یک قلم داشته باشد');
  }

  // صورتحساب نوع اول نیازمند اطلاعات کامل خریدار است
  if (subjectType === 1) {
    if (!buyer) {
      issues.push('صورتحساب نوع اول بدون اطلاعات خریدار مجاز نیست');
    } else {
      const id = buyer.economicCode?.trim() || buyer.nationalId?.trim();
      if (!id) issues.push(`شمارهٔ اقتصادی یا شناسهٔ ملی «${buyer.name}» ثبت نشده است`);
    }
  }

  invoice.lines.forEach((l, i) => {
    const p = products.get(l.productId);
    const n = i + 1;
    if (!p) {
      issues.push(`ردیف ${n}: کالا یافت نشد`);
      return;
    }
    if (!p.taxCode?.trim()) {
      issues.push(`ردیف ${n}: شناسهٔ کالا/خدمت «${p.name}» ثبت نشده است`);
    }
    if (l.qty <= 0) issues.push(`ردیف ${n}: مقدار باید بزرگ‌تر از صفر باشد`);
    if (l.vatRate < 0 || l.vatRate > 100) issues.push(`ردیف ${n}: نرخ مالیات نامعتبر است`);
  });

  const totals = computeInvoice(invoice);
  if (totals.grandTotal <= 0) {
    issues.push('مبلغ صورتحساب باید بزرگ‌تر از صفر باشد');
  }

  return issues;
}

/**
 * ساخت صورتحساب الکترونیکی از فاکتور داخلی.
 * تاریخ‌ها به مهر زمانی یونیکس (میلی‌ثانیه) تبدیل می‌شوند.
 */
export function buildElectronicInvoice(input: {
  invoice: Invoice;
  business: Business;
  buyer: Party | null;
  products: Map<ID, Product>;
  profile: TaxProfile;
  serial: number;
  subject?: InvoiceSubject;
  pattern?: InvoicePattern;
  subjectType?: InvoiceSubjectType;
  referencedTaxId?: string | null;
  issuedAt?: Date;
}): ElectronicInvoice {
  const {
    invoice, buyer, products, profile, serial,
    subject = INVOICE_SUBJECTS.ORIGINAL,
    pattern = INVOICE_PATTERNS.SALE,
    subjectType = 1,
    referencedTaxId = null,
  } = input;

  const issues = validateForTaxSystem(invoice, buyer, products, profile, subjectType);
  if (issues.length > 0) throw new TaxValidationError(issues);

  const issuedAt = input.issuedAt ?? new Date(invoice.date);
  const taxId = generateTaxId(profile.memoryId, issuedAt, serial);
  const totals = computeInvoice(invoice);
  const stamp = issuedAt.getTime();

  const body = invoice.lines.map((l, i) => {
    const p = products.get(l.productId)!;
    const t = totals.lines[i]!;
    return {
      sstid: p.taxCode!.trim(),
      sstt: p.name,
      am: l.qty,
      mu: l.unit,
      fee: l.unitPrice,
      prdis: t.gross,
      dis: addMoney(t.discount, t.allocatedDiscount),
      adis: t.net,
      vra: l.vatRate,
      vam: t.vat,
      tsstam: t.total,
    };
  });

  const buyerId = buyer?.economicCode?.trim() || buyer?.nationalId?.trim() || null;

  return {
    header: {
      taxid: taxId,
      indatim: stamp,
      indati2m: stamp,
      inty: subjectType,
      inno: invoice.number,
      irtaxid: referencedTaxId,
      inp: pattern,
      ins: subject,
      tins: profile.sellerTin.trim(),
      tob: profile.sellerType,
      bid: buyerId,
      tinb: buyerId,
      sbc: null,
      bpc: null,
      tprdis: totals.subtotal,
      tdis: totals.totalDiscount,
      tadis: totals.net,
      tvam: totals.vat,
      tbill: addMoney(totals.grandTotal),
      setm: 1,
      cap: 0,
      insp: totals.grandTotal,
    },
    body,
    meta: {
      specVersion: TAX_SPEC_VERSION,
      generatedAt: new Date().toISOString(),
    },
  };
}

/** صحت‌سنجی جمع‌های صورتحساب — سامانه این‌ها را کنترل می‌کند */
export function verifyTotals(doc: ElectronicInvoice): string[] {
  const issues: string[] = [];
  const sumVat = addMoney(...doc.body.map((b) => b.vam));
  const sumNet = addMoney(...doc.body.map((b) => b.adis));

  if (sumVat !== doc.header.tvam) {
    issues.push(`جمع مالیات اقلام (${sumVat}) با سربرگ (${doc.header.tvam}) نمی‌خواند`);
  }
  if (sumNet !== doc.header.tadis) {
    issues.push(`جمع خالص اقلام (${sumNet}) با سربرگ (${doc.header.tadis}) نمی‌خواند`);
  }
  if (!validateTaxId(doc.header.taxid)) {
    issues.push('رقم کنترلی شمارهٔ مالیاتی نامعتبر است');
  }
  return issues;
}

/**
 * ساخت صورتحساب اصلاحی یا ابطالی.
 * سامانه الزام می‌کند که به شمارهٔ مالیاتی صورتحساب اصلی ارجاع داده شود.
 */
export function buildCorrection(
  original: TaxSubmission,
  subject: Extract<InvoiceSubject, 2 | 3 | 4>,
  input: Omit<Parameters<typeof buildElectronicInvoice>[0], 'subject' | 'referencedTaxId'>,
): ElectronicInvoice {
  if (original.status !== 'accepted') {
    throw new TaxValidationError(['فقط صورتحساب پذیرفته‌شده قابل اصلاح یا ابطال است']);
  }
  return buildElectronicInvoice({ ...input, subject, referencedTaxId: original.taxId });
}

/** سریال بعدی برای حافظهٔ مالیاتی */
export function nextSerial(profile: TaxProfile): number {
  return profile.lastSerial + 1;
}

// ─────────────────── گزارش مالیاتی دوره ───────────────────

export interface VatPeriodReport {
  from: string;
  to: string;
  label: string;
  salesNet: Rial;
  salesVat: Rial;
  purchaseNet: Rial;
  purchaseVat: Rial;
  /** مالیات قابل پرداخت = مالیات فروش منهای اعتبار خرید */
  payable: Rial;
  invoiceCount: number;
  submittedCount: number;
  pendingCount: number;
}

/** فصل مالیاتی (سه‌ماهه) شمسی که تاریخ داده‌شده در آن است */
export function taxQuarter(date: Date): { quarter: number; from: Date; to: Date; label: string } {
  const j = dateToJalali(date);
  const quarter = Math.ceil(j.jm / 3);
  const startMonth = (quarter - 1) * 3 + 1;
  const endMonth = startMonth + 2;

  // بازه را با ابزار جلالی می‌سازیم تا طول ماه‌ها درست باشد
  const from = jalaliToDate({ jy: j.jy, jm: startMonth, jd: 1 });
  const to = jalaliToDate({ jy: j.jy, jm: endMonth, jd: jalaliMonthLength(j.jy, endMonth) });
  to.setHours(23, 59, 59, 999);

  const names = ['بهار', 'تابستان', 'پاییز', 'زمستان'];
  const faYear = String(j.jy).replace(/\d/g, (d) => '۰۱۲۳۴۵۶۷۸۹'[Number(d)]!);
  return { quarter, from, to, label: `${names[quarter - 1]} ${faYear}` };
}

export function vatReport(
  invoices: Invoice[],
  submissions: TaxSubmission[],
  range: { from: string; to: string; label?: string },
): VatPeriodReport {
  const inRange = (d: string) => d >= range.from && d <= range.to;
  const official = invoices.filter((i) => !i.deletedAt && i.isOfficial && inRange(i.date));

  let salesNet = 0, salesVat = 0, purchaseNet = 0, purchaseVat = 0;

  for (const inv of official) {
    const t = computeInvoice(inv);
    switch (inv.type) {
      case 'sale':
        salesNet += t.net; salesVat += t.vat; break;
      case 'sale_return':
        salesNet -= t.net; salesVat -= t.vat; break;
      case 'purchase':
        purchaseNet += t.net; purchaseVat += t.vat; break;
      case 'purchase_return':
        purchaseNet -= t.net; purchaseVat -= t.vat; break;
    }
  }

  const ids = new Set(official.map((i) => i.id));
  const relevant = submissions.filter((s) => ids.has(s.invoiceId));
  const submitted = relevant.filter((s) => s.status === 'accepted' || s.status === 'sent').length;

  const sellCount = official.filter((i) => i.type === 'sale').length;

  return {
    from: range.from,
    to: range.to,
    label: range.label ?? '',
    salesNet: bankersRound(salesNet),
    salesVat: bankersRound(salesVat),
    purchaseNet: bankersRound(purchaseNet),
    purchaseVat: bankersRound(purchaseVat),
    payable: bankersRound(salesVat - purchaseVat),
    invoiceCount: sellCount,
    submittedCount: submitted,
    pendingCount: Math.max(0, sellCount - submitted),
  };
}
