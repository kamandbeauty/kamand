import type { Rial } from './money.js';
import type { ID } from './types.js';

/**
 * ═══════════════════════════════════════════════════════════════
 *  مرکز هشدار — وضعیت سلامت کسب‌وکار
 * ═══════════════════════════════════════════════════════════════
 *
 * در طول توسعه چند محافظ ساختیم: تشخیص مانده اول دورهٔ ثبت‌نشده،
 * موجودی اولیهٔ بدون سند، چک سررسید گذشته، خطای دفتر و غیره.
 *
 * ولی هرکدام فقط در صفحهٔ خودش دیده می‌شد. کاربر باید تک‌تک
 * صفحات را می‌گشت تا بفهمد مشکلی هست. این ماژول همه را یکجا
 * جمع می‌کند تا داشبورد بتواند وضعیت واقعی را نشان دهد.
 *
 * طراحی: هسته فقط **ساختار و اولویت‌بندی** را می‌داند؛ تشخیص
 * هر مورد در لایهٔ داده انجام می‌شود و اینجا فقط جمع می‌گردد.
 */

export type AlertSeverity = 'critical' | 'warning' | 'info';

export type AlertKind =
  | 'unposted_opening'
  | 'unposted_inventory'
  | 'negative_inventory'
  | 'ledger_error'
  | 'overdue_cheque'
  | 'due_soon_cheque'
  | 'low_stock'
  | 'overdue_invoice'
  | 'unsent_tax_invoice'
  | 'subscription_expiring'
  | 'no_backup';

export interface Alert {
  kind: AlertKind;
  severity: AlertSeverity;
  title: string;
  detail: string;
  /** صفحه‌ای که کاربر باید برود */
  page?: string;
  /** متن دکمهٔ اقدام */
  action?: string;
  count?: number;
  amount?: Rial;
}

const SEVERITY_RANK: Record<AlertSeverity, number> = {
  critical: 0,
  warning: 1,
  info: 2,
};

/** مرتب‌سازی: بحرانی اول، سپس بر اساس مبلغ */
export function sortAlerts(alerts: Alert[]): Alert[] {
  return [...alerts].sort((a, b) => {
    const s = SEVERITY_RANK[a.severity] - SEVERITY_RANK[b.severity];
    if (s !== 0) return s;
    return (b.amount ?? 0) - (a.amount ?? 0);
  });
}

export interface HealthSummary {
  alerts: Alert[];
  critical: number;
  warnings: number;
  /** آیا کسب‌وکار برای کار روزمره آماده است؟ */
  ready: boolean;
  message: string;
}

const fa = (n: number) => String(n).replace(/\d/g, (d) => '۰۱۲۳۴۵۶۷۸۹'[Number(d)]!);

export function summarizeHealth(alerts: Alert[]): HealthSummary {
  const sorted = sortAlerts(alerts);
  const critical = sorted.filter((a) => a.severity === 'critical').length;
  const warnings = sorted.filter((a) => a.severity === 'warning').length;

  let message: string;
  if (critical > 0) {
    message = `${fa(critical)} مورد نیازمند رسیدگی فوری`;
  } else if (warnings > 0) {
    message = `${fa(warnings)} هشدار`;
  } else {
    message = 'همه‌چیز مرتب است';
  }

  return { alerts: sorted, critical, warnings, ready: critical === 0, message };
}

// ─────────────────── سازنده‌های هشدار ───────────────────

/**
 * سازنده‌های آماده تا متن هشدارها یکدست بماند و در یک جا
 * قابل بازبینی باشد.
 */
export const alerts = {
  unpostedOpening(count: number): Alert {
    return {
      kind: 'unposted_opening',
      severity: 'critical',
      title: 'مانده اول دوره ثبت نشده',
      detail:
        `${fa(count)} مورد مانده اول دوره وارد کرده‌اید که هنوز به دفتر نرفته است. ` +
        'تا ثبت سند افتتاحیه، این مبالغ در گزارش‌ها دیده نمی‌شوند.',
      page: 'ledger',
      action: 'ثبت سند افتتاحیه',
      count,
    };
  },

  unpostedInventory(count: number, value: Rial): Alert {
    return {
      kind: 'unposted_inventory',
      severity: 'critical',
      title: 'موجودی اولیه در دفتر نیست',
      detail:
        `${fa(count)} کالا با موجودی اولیه دارید که سند حسابداری‌شان ثبت نشده. ` +
        'بدون آن حساب موجودی کالا منفی می‌شود.',
      page: 'ledger',
      action: 'ثبت سند افتتاحیه',
      count,
      amount: value,
    };
  },

  negativeInventory(value: Rial): Alert {
    return {
      kind: 'negative_inventory',
      severity: 'warning',
      title: 'ارزش موجودی کالا منفی است',
      detail:
        'احتمالاً فروش بیش از موجودی ثبت شده یا موجودی اولیه سند ندارد. ' +
        'با انبارگردانی می‌توانید موجودی را با واقعیت هماهنگ کنید.',
      page: 'products',
      action: 'انبارگردانی',
      amount: Math.abs(value),
    };
  },

  ledgerError(count: number): Alert {
    return {
      kind: 'ledger_error',
      severity: 'critical',
      title: 'خطای جدی در دفتر',
      detail:
        `${fa(count)} خطا در اسناد حسابداری یافت شد. تا رفع آن‌ها ` +
        'بستن سال مالی ممکن نیست و گزارش‌ها قابل اتکا نیستند.',
      page: 'yearend',
      action: 'بررسی سلامت دفتر',
      count,
    };
  },

  overdueCheque(count: number, amount: Rial): Alert {
    return {
      kind: 'overdue_cheque',
      severity: 'critical',
      title: 'چک سررسید گذشته',
      detail: `${fa(count)} چک از سررسید گذشته و هنوز تعیین وضعیت نشده است.`,
      page: 'treasury',
      action: 'مشاهدهٔ چک‌ها',
      count,
      amount,
    };
  },

  dueSoonCheque(count: number, amount: Rial): Alert {
    return {
      kind: 'due_soon_cheque',
      severity: 'warning',
      title: 'چک نزدیک سررسید',
      detail: `${fa(count)} چک تا یک هفتهٔ آینده سررسید می‌شود.`,
      page: 'treasury',
      action: 'مشاهدهٔ چک‌ها',
      count,
      amount,
    };
  },

  lowStock(count: number): Alert {
    return {
      kind: 'low_stock',
      severity: 'warning',
      title: 'کالاهای رو به اتمام',
      detail: `${fa(count)} کالا به حداقل موجودی رسیده یا از آن کمتر است.`,
      page: 'products',
      action: 'مشاهدهٔ کالاها',
      count,
    };
  },

  overdueInvoice(count: number, amount: Rial): Alert {
    return {
      kind: 'overdue_invoice',
      severity: 'warning',
      title: 'فاکتور سررسید گذشته',
      detail: `${fa(count)} فاکتور از تاریخ سررسید گذشته و هنوز تسویه نشده است.`,
      page: 'invoices',
      action: 'مشاهدهٔ فاکتورها',
      count,
      amount,
    };
  },

  unsentTaxInvoice(count: number): Alert {
    return {
      kind: 'unsent_tax_invoice',
      severity: 'warning',
      title: 'صورتحساب ارسال‌نشده',
      detail:
        `${fa(count)} فاکتور رسمی هنوز به سامانهٔ مؤدیان ارسال نشده است.`,
      page: 'tax',
      action: 'سامانهٔ مؤدیان',
      count,
    };
  },

  subscriptionExpiring(days: number): Alert {
    return {
      kind: 'subscription_expiring',
      severity: days <= 3 ? 'critical' : 'warning',
      title: 'اشتراک رو به پایان',
      detail:
        `${fa(days)} روز تا پایان اشتراک باقی مانده است. ` +
        'پس از آن همچنان می‌توانید اطلاعات را ببینید و خروجی بگیرید.',
      page: 'settings',
      action: 'تمدید اشتراک',
      count: days,
    };
  },

  noBackup(days: number): Alert {
    return {
      kind: 'no_backup',
      severity: 'info',
      title: 'مدتی است پشتیبان نگرفته‌اید',
      detail:
        `${fa(days)} روز از آخرین دریافت پشتیبان می‌گذرد. ` +
        'دریافت فایل پشتیبان همیشه رایگان و بدون محدودیت است.',
      page: 'settings',
      action: 'دریافت پشتیبان',
      count: days,
    };
  },
};

// ─────────────────── راه‌اندازی اولیه ───────────────────

export interface SetupStep {
  id: string;
  title: string;
  detail: string;
  done: boolean;
  page: string;
  action: string;
}

export interface SetupProgress {
  steps: SetupStep[];
  completed: number;
  total: number;
  percent: number;
  /** آیا کاربر مراحل ضروری را رد کرده؟ */
  finished: boolean;
}

/**
 * راهنمای گام‌به‌گام روز اول.
 *
 * مغازه‌داری که تازه برنامه را باز می‌کند با صفحهٔ خالی روبه‌رو
 * می‌شود و نمی‌داند از کجا شروع کند. این فهرست ترتیب درست را
 * نشان می‌دهد — و مهم‌تر، ترتیبی که از تله‌های شناخته‌شده
 * جلوگیری می‌کند (مثل ثبت فاکتور پیش از سند افتتاحیه).
 */
export function setupProgress(state: {
  hasBusinessInfo: boolean;
  hasProducts: boolean;
  hasParties: boolean;
  hasOpeningEntry: boolean;
  hasInvoice: boolean;
  needsOpening: boolean;
}): SetupProgress {
  const steps: SetupStep[] = [
    {
      id: 'business',
      title: 'مشخصات کسب‌وکار',
      detail: 'نام، آدرس و تلفن روی فاکتورهای چاپی نمایش داده می‌شود',
      done: state.hasBusinessInfo,
      page: 'settings',
      action: 'تکمیل مشخصات',
    },
    {
      id: 'products',
      title: 'تعریف کالاها',
      detail: 'کالاها و خدمات خود را با قیمت خرید و فروش وارد کنید',
      done: state.hasProducts,
      page: 'products',
      action: 'افزودن کالا',
    },
    {
      id: 'parties',
      title: 'تعریف مشتریان و فروشندگان',
      detail: 'اگر بدهکاری یا طلب قبلی دارید، در «مانده اول دوره» وارد کنید',
      done: state.hasParties,
      page: 'parties',
      action: 'افزودن شخص',
    },
    {
      id: 'opening',
      title: 'ثبت مانده‌های اول دوره',
      detail: 'تا این سند ثبت نشود، موجودی و بدهکاری‌های قبلی در گزارش‌ها نمی‌آید',
      done: state.hasOpeningEntry || !state.needsOpening,
      page: 'ledger',
      action: 'ثبت سند افتتاحیه',
    },
    {
      id: 'invoice',
      title: 'ثبت اولین فاکتور',
      detail: 'حالا می‌توانید فروش روزانه را ثبت کنید',
      done: state.hasInvoice,
      page: 'invoices',
      action: 'ثبت فاکتور',
    },
  ];

  const completed = steps.filter((s) => s.done).length;
  return {
    steps,
    completed,
    total: steps.length,
    percent: Math.round((completed / steps.length) * 100),
    finished: completed === steps.length,
  };
}

/** آیا راهنما باید نمایش داده شود؟ */
export function shouldShowSetup(progress: SetupProgress, dismissed: boolean): boolean {
  return !dismissed && !progress.finished;
}
