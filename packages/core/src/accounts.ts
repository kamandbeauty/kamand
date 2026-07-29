import type { Account, AccountType, ID } from './types.js';

/**
 * کدینگ استاندارد حساب‌ها برای کسب‌وکارهای کوچک ایرانی.
 * کد سه‌رقمی گروه + دو رقم تفصیل، قابل توسعه توسط کاربر.
 */

export const SYSTEM_ACCOUNTS = {
  CASH: '1010',
  BANK: '1020',
  PETTY_CASH: '1030',
  RECEIVABLE: '1110',
  CHEQUE_RECEIVED: '1120',
  INVENTORY: '1210',
  VAT_CREDIT: '1310',

  PAYABLE: '2010',
  CHEQUE_ISSUED: '2020',
  VAT_PAYABLE: '2110',

  CAPITAL: '3010',
  DRAWINGS: '3020',
  RETAINED: '3030',
  /**
   * حساب واسط تراز اختتامیه/افتتاحیه.
   * سند اختتامیه همهٔ حساب‌های دائمی را در این حساب می‌بندد و سند
   * افتتاحیهٔ سال بعد آن‌ها را از همین حساب باز می‌کند. چون این دو
   * یکدیگر را خنثی می‌کنند، مانده‌اش همیشه باید صفر باشد.
   */
  CLOSING_SUMMARY: '3900',

  SALES: '4010',
  SALES_RETURN: '4020',
  SALES_DISCOUNT: '4030',
  OTHER_INCOME: '4900',

  COGS: '5010',
  PURCHASE_RETURN: '5020',
  WASTE: '5030',
  SHIPPING_EXPENSE: '5110',
  BANK_FEE: '5120',
  BAD_DEBT: '5130',
  OTHER_EXPENSE: '5900',
} as const;

interface Seed {
  code: string;
  name: string;
  type: AccountType;
  parent?: string;
}

const SEED: Seed[] = [
  { code: '1000', name: 'دارایی‌ها', type: 'asset' },
  { code: '1010', name: 'صندوق', type: 'asset', parent: '1000' },
  { code: '1020', name: 'بانک', type: 'asset', parent: '1000' },
  { code: '1030', name: 'تنخواه‌گردان', type: 'asset', parent: '1000' },
  { code: '1110', name: 'حساب‌های دریافتنی (بدهکاران)', type: 'asset', parent: '1000' },
  { code: '1120', name: 'اسناد دریافتنی (چک‌های دریافتی)', type: 'asset', parent: '1000' },
  { code: '1210', name: 'موجودی کالا', type: 'asset', parent: '1000' },
  { code: '1310', name: 'مالیات بر ارزش افزودهٔ خرید', type: 'asset', parent: '1000' },

  { code: '2000', name: 'بدهی‌ها', type: 'liability' },
  { code: '2010', name: 'حساب‌های پرداختنی (بستانکاران)', type: 'liability', parent: '2000' },
  { code: '2020', name: 'اسناد پرداختنی (چک‌های پرداختی)', type: 'liability', parent: '2000' },
  { code: '2110', name: 'مالیات بر ارزش افزودهٔ فروش', type: 'liability', parent: '2000' },

  { code: '3000', name: 'سرمایه', type: 'equity' },
  { code: '3010', name: 'سرمایهٔ اولیه', type: 'equity', parent: '3000' },
  { code: '3020', name: 'برداشت شخصی', type: 'equity', parent: '3000' },
  { code: '3030', name: 'سود انباشته', type: 'equity', parent: '3000' },
  { code: '3900', name: 'تراز اختتامیه و افتتاحیه', type: 'equity', parent: '3000' },

  { code: '4000', name: 'درآمدها', type: 'income' },
  { code: '4010', name: 'فروش', type: 'income', parent: '4000' },
  { code: '4020', name: 'برگشت از فروش', type: 'income', parent: '4000' },
  { code: '4030', name: 'تخفیفات فروش', type: 'income', parent: '4000' },
  { code: '4900', name: 'درآمدهای متفرقه', type: 'income', parent: '4000' },

  { code: '5000', name: 'هزینه‌ها', type: 'expense' },
  { code: '5010', name: 'بهای تمام‌شدهٔ کالای فروش‌رفته', type: 'expense', parent: '5000' },
  { code: '5020', name: 'برگشت از خرید', type: 'expense', parent: '5000' },
  { code: '5030', name: 'ضایعات', type: 'expense', parent: '5000' },
  { code: '5110', name: 'هزینهٔ حمل', type: 'expense', parent: '5000' },
  { code: '5120', name: 'کارمزد بانکی', type: 'expense', parent: '5000' },
  { code: '5130', name: 'مطالبات سوخت‌شده', type: 'expense', parent: '5000' },
  { code: '5900', name: 'هزینه‌های متفرقه', type: 'expense', parent: '5000' },
];

export function createChartOfAccounts(businessId: ID, idGen: () => ID): Account[] {
  const byCode = new Map<string, ID>();
  const out: Account[] = [];
  for (const s of SEED) {
    const id = idGen();
    byCode.set(s.code, id);
    out.push({
      id,
      businessId,
      code: s.code,
      name: s.name,
      type: s.type,
      parentId: s.parent ? byCode.get(s.parent) ?? null : null,
      isSystem: true,
    });
  }
  return out;
}

/** نگاشت کد حساب به شناسه، برای استفاده در موتور سند */
export class AccountIndex {
  private byCode = new Map<string, Account>();
  private byId = new Map<ID, Account>();

  constructor(accounts: Account[]) {
    for (const a of accounts) {
      this.byCode.set(a.code, a);
      this.byId.set(a.id, a);
    }
  }

  id(code: string): ID {
    const a = this.byCode.get(code);
    if (!a) throw new Error(`حساب با کد ${code} یافت نشد`);
    return a.id;
  }

  get(id: ID): Account | undefined {
    return this.byId.get(id);
  }

  byCodeOrNull(code: string): Account | undefined {
    return this.byCode.get(code);
  }

  all(): Account[] {
    return [...this.byId.values()];
  }

  children(parentId: ID | null): Account[] {
    return this.all().filter((a) => (a.parentId ?? null) === parentId);
  }
}
