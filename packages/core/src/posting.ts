import { addMoney, type Rial } from './money.js';
import { EntryBuilder } from './ledger.js';
import { SYSTEM_ACCOUNTS as A, type AccountIndex } from './accounts.js';
import { computeInvoice, isInbound, isOutbound, INVOICE_TYPE_LABELS } from './invoice.js';
import type {
  Cheque,
  ID,
  Invoice,
  JournalEntry,
  StockMovement,
  Transaction,
  Treasury,
} from './types.js';

/**
 * لایهٔ ثبت: تبدیل رویدادهای کسب‌وکار به سند حسابداری متوازن.
 * هیچ‌جای دیگری از برنامه نباید مستقیماً سند بسازد.
 */

export interface PostingContext {
  index: AccountIndex;
  businessId: ID;
  idGen: () => ID;
  now: string;
  /** حساب خزانه‌ها بر اساس نوع */
  treasuryAccount: (t: Treasury) => ID;
}

function treasuryCode(t: Treasury): string {
  return t.kind === 'bank' ? A.BANK : t.kind === 'petty_cash' ? A.PETTY_CASH : A.CASH;
}

export function defaultTreasuryAccount(index: AccountIndex) {
  return (t: Treasury): ID => index.id(treasuryCode(t));
}

/**
 * سند فاکتور.
 *
 * فروش:  بدهکار دریافتنی / بستانکار فروش + مالیات
 *        بدهکار بهای تمام‌شده / بستانکار موجودی کالا
 * خرید:  بدهکار موجودی کالا + مالیات خرید / بستانکار پرداختنی
 */
export function postInvoice(
  invoice: Invoice,
  cogsTotal: Rial,
  ctx: PostingContext,
): JournalEntry | null {
  if (invoice.type === 'quote' || invoice.status === 'void') return null;

  const { index } = ctx;
  const t = computeInvoice(invoice);
  const desc = `${INVOICE_TYPE_LABELS[invoice.type]} شمارهٔ ${invoice.number}`;
  const b = new EntryBuilder(ctx.businessId, invoice.date, desc, 'invoice', invoice.id);
  const party = invoice.partyId ?? null;

  switch (invoice.type) {
    case 'sale': {
      b.debit(index.id(A.RECEIVABLE), addMoney(t.net, t.vat, t.shipping), { partyId: party });
      b.credit(index.id(A.SALES), t.net);
      b.credit(index.id(A.VAT_PAYABLE), t.vat);
      b.credit(index.id(A.OTHER_INCOME), t.shipping);
      if (cogsTotal > 0) {
        b.debit(index.id(A.COGS), cogsTotal);
        b.credit(index.id(A.INVENTORY), cogsTotal);
      }
      break;
    }

    case 'purchase': {
      b.debit(index.id(A.INVENTORY), t.net);
      b.debit(index.id(A.VAT_CREDIT), t.vat);
      b.debit(index.id(A.SHIPPING_EXPENSE), t.shipping);
      b.credit(index.id(A.PAYABLE), addMoney(t.net, t.vat, t.shipping), { partyId: party });
      break;
    }

    case 'sale_return': {
      b.debit(index.id(A.SALES_RETURN), t.net);
      b.debit(index.id(A.VAT_PAYABLE), t.vat);
      b.credit(index.id(A.RECEIVABLE), addMoney(t.net, t.vat), { partyId: party });
      if (cogsTotal > 0) {
        b.debit(index.id(A.INVENTORY), cogsTotal);
        b.credit(index.id(A.COGS), cogsTotal);
      }
      break;
    }

    case 'purchase_return': {
      b.debit(index.id(A.PAYABLE), addMoney(t.net, t.vat), { partyId: party });
      b.credit(index.id(A.PURCHASE_RETURN), t.net);
      b.credit(index.id(A.VAT_CREDIT), t.vat);
      break;
    }

    case 'waste': {
      if (cogsTotal > 0) {
        b.debit(index.id(A.WASTE), cogsTotal);
        b.credit(index.id(A.INVENTORY), cogsTotal);
      }
      break;
    }
  }

  if (b.isEmpty()) return null;
  return b.build(ctx.idGen(), ctx.now);
}

/** حرکات انبار ناشی از فاکتور */
export function stockMovementsFor(
  invoice: Invoice,
  ctx: { businessId: ID; idGen: () => ID },
  costOf: (line: Invoice['lines'][number]) => Rial,
): StockMovement[] {
  if (invoice.type === 'quote' || invoice.status === 'void') return [];
  const sign = isOutbound(invoice.type) ? -1 : isInbound(invoice.type) ? 1 : 0;
  if (sign === 0) return [];

  return invoice.lines.map((l) => ({
    id: ctx.idGen(),
    businessId: ctx.businessId,
    productId: l.productId,
    qty: sign * l.qty,
    unitCost: costOf(l),
    date: invoice.date,
    sourceType: 'invoice' as const,
    sourceId: invoice.id,
  }));
}

/**
 * سند تراکنش خزانه.
 * دریافت: بدهکار صندوق/بانک / بستانکار دریافتنی
 * پرداخت: بدهکار پرداختنی / بستانکار صندوق/بانک
 */
export function postTransaction(
  tx: Transaction,
  treasury: Treasury,
  toTreasury: Treasury | null,
  ctx: PostingContext,
): JournalEntry | null {
  if (tx.deletedAt) return null;
  const { index } = ctx;
  const from = ctx.treasuryAccount(treasury);
  const party = tx.partyId ?? null;
  const desc = tx.description ?? labelForTransaction(tx.kind);
  const b = new EntryBuilder(ctx.businessId, tx.date, desc, 'transaction', tx.id);

  switch (tx.kind) {
    case 'receive':
      b.debit(from, tx.amount);
      b.credit(index.id(A.RECEIVABLE), tx.amount, { partyId: party });
      break;

    case 'pay':
      b.debit(index.id(A.PAYABLE), tx.amount, { partyId: party });
      b.credit(from, tx.amount);
      break;

    case 'transfer': {
      if (!toTreasury) throw new Error('مقصد انتقال مشخص نیست');
      b.debit(ctx.treasuryAccount(toTreasury), tx.amount);
      b.credit(from, tx.amount);
      break;
    }

    case 'expense':
      b.debit(tx.accountId ?? index.id(A.OTHER_EXPENSE), tx.amount, { partyId: party });
      b.credit(from, tx.amount);
      break;

    case 'income':
      b.debit(from, tx.amount);
      b.credit(tx.accountId ?? index.id(A.OTHER_INCOME), tx.amount, { partyId: party });
      break;
  }

  if (b.isEmpty()) return null;
  return b.build(ctx.idGen(), ctx.now);
}

function labelForTransaction(kind: Transaction['kind']): string {
  const map: Record<Transaction['kind'], string> = {
    receive: 'دریافت وجه',
    pay: 'پرداخت وجه',
    transfer: 'انتقال بین حساب‌ها',
    expense: 'ثبت هزینه',
    income: 'ثبت درآمد',
  };
  return map[kind];
}

/**
 * سند چک بر اساس تغییر وضعیت.
 * دریافت چک: بدهکار اسناد دریافتنی / بستانکار حساب دریافتنی
 * وصول چک:  بدهکار بانک / بستانکار اسناد دریافتنی
 * برگشت چک: عکس ثبت دریافت
 */
export function postCheque(
  cheque: Cheque,
  event: 'register' | 'cash' | 'bounce',
  treasury: Treasury | null,
  ctx: PostingContext,
): JournalEntry | null {
  const { index } = ctx;
  const party = cheque.partyId ?? null;
  const received = cheque.direction === 'received';
  const noteAccount = index.id(received ? A.CHEQUE_RECEIVED : A.CHEQUE_ISSUED);
  const partyAccount = index.id(received ? A.RECEIVABLE : A.PAYABLE);
  const date = event === 'register' ? cheque.createdAt.slice(0, 10) : cheque.dueDate;

  const label = received ? 'چک دریافتی' : 'چک پرداختی';
  const eventLabel = { register: 'ثبت', cash: 'وصول', bounce: 'برگشت' }[event];
  const b = new EntryBuilder(
    ctx.businessId,
    date,
    `${eventLabel} ${label} شمارهٔ ${cheque.number}`,
    'cheque',
    cheque.id,
  );

  if (event === 'register') {
    if (received) {
      b.debit(noteAccount, cheque.amount);
      b.credit(partyAccount, cheque.amount, { partyId: party });
    } else {
      b.debit(partyAccount, cheque.amount, { partyId: party });
      b.credit(noteAccount, cheque.amount);
    }
  } else if (event === 'cash') {
    if (!treasury) throw new Error('حساب خزانه برای وصول چک مشخص نیست');
    const treasuryAcc = ctx.treasuryAccount(treasury);
    if (received) {
      b.debit(treasuryAcc, cheque.amount);
      b.credit(noteAccount, cheque.amount);
    } else {
      b.debit(noteAccount, cheque.amount);
      b.credit(treasuryAcc, cheque.amount);
    }
  } else {
    // برگشت: معکوس ثبت اولیه
    if (received) {
      b.debit(partyAccount, cheque.amount, { partyId: party });
      b.credit(noteAccount, cheque.amount);
    } else {
      b.debit(noteAccount, cheque.amount);
      b.credit(partyAccount, cheque.amount, { partyId: party });
    }
  }

  if (b.isEmpty()) return null;
  return b.build(ctx.idGen(), ctx.now);
}

/** سند افتتاحیه: مانده‌های اول دوره */
export function postOpening(
  input: {
    date: string;
    parties: { id: ID; balance: Rial }[];
    treasuries: { treasury: Treasury; balance: Rial }[];
    inventoryValue: Rial;
  },
  ctx: PostingContext,
): JournalEntry | null {
  const { index } = ctx;
  const b = new EntryBuilder(ctx.businessId, input.date, 'سند افتتاحیه', 'opening', null);

  let debitTotal = 0;
  let creditTotal = 0;

  for (const { treasury, balance } of input.treasuries) {
    if (balance === 0) continue;
    b.debit(ctx.treasuryAccount(treasury), balance);
    debitTotal += balance;
  }

  if (input.inventoryValue > 0) {
    b.debit(index.id(A.INVENTORY), input.inventoryValue);
    debitTotal += input.inventoryValue;
  }

  for (const p of input.parties) {
    if (p.balance === 0) continue;
    if (p.balance > 0) {
      b.debit(index.id(A.RECEIVABLE), p.balance, { partyId: p.id });
      debitTotal += p.balance;
    } else {
      b.credit(index.id(A.PAYABLE), -p.balance, { partyId: p.id });
      creditTotal += -p.balance;
    }
  }

  // اختلاف به حساب سرمایه می‌رود تا سند متوازن شود
  const diff = debitTotal - creditTotal;
  if (diff > 0) b.credit(index.id(A.CAPITAL), diff);
  else if (diff < 0) b.debit(index.id(A.CAPITAL), -diff);

  if (b.isEmpty()) return null;
  return b.build(ctx.idGen(), ctx.now);
}
