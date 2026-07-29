/** بررسی رندر — همهٔ صفحات با داده‌های واقعی رندر می‌شوند تا خطای زمان اجرا گرفته شود */
import React from 'react';
import { renderToString } from 'react-dom/server';
import { Dashboard } from '../src/pages/Dashboard';
import { Invoices } from '../src/pages/Invoices';
import { Parties } from '../src/pages/Parties';
import { Products } from '../src/pages/Products';
import { Reports } from '../src/pages/Reports';
import { Treasury } from '../src/pages/Treasury';
import { Settings } from '../src/pages/Settings';
import { Tax } from '../src/pages/Tax';
import { Account } from '../src/pages/Account';
import { Audit } from '../src/pages/Audit';
import { YearEnd } from '../src/pages/YearEnd';
import { Ledger } from '../src/pages/Ledger';
import { closedYears, closeYear, closingPreviewFor, integrityOf, hasOpeningEntry, postManualEntry, postOpeningBalances, validateManualEntry, voidManualEntry, indexOf, createEmptyDB, issueElectronicInvoice, lockPeriod, postInvoiceToDB, postTransactionToDB, taxReadiness, updateTaxProfile, upsertParty, upsertProduct, type DB } from '../src/store';
import { uuid, type Invoice } from '@javid/core';

function seed(): DB {
  let db = createEmptyDB('فروشگاه آزمون');

  const cust = { id: uuid(), businessId: db.business.id, kind: 'customer' as const, name: 'مشتری الف', phone: '09120000000', economicCode: '411222333444', openingBalance: 0 };
  const vend = { id: uuid(), businessId: db.business.id, kind: 'vendor' as const, name: 'تأمین‌کننده ب', openingBalance: 0 };
  db = upsertParty(db, cust);
  db = upsertParty(db, vend);

  const prod = {
    id: uuid(), businessId: db.business.id, kind: 'goods' as const, name: 'کالای نمونه',
    barcode: '6260000000001', unitMain: 'عدد', buyPrice: 100_000, sellPrice: 150_000,
    openingQty: 50, openingCost: 100_000, minQty: 5, vatRate: 10,
    taxCode: '2710000000001',
  };
  db = upsertProduct(db, prod);

  const now = new Date().toISOString();
  const sale: Invoice = {
    id: uuid(), businessId: db.business.id, type: 'sale', number: 'F-0001',
    partyId: cust.id, date: now.slice(0, 10), isOfficial: true,
    lines: [{ id: uuid(), productId: prod.id, qty: 3, unit: 'عدد', unitPrice: 150_000, discount: 0, vatRate: 10 }],
    discount: 0, shipping: 0, status: 'open', createdAt: now, updatedAt: now,
  };
  db = postInvoiceToDB(db, sale);

  db = updateTaxProfile(db, { memoryId: 'A1D2E3', sellerTin: '411111111111', sellerType: 2, lastSerial: 0 });
  db = issueElectronicInvoice(db, db.invoices[db.invoices.length - 1]!).db;

  db = postTransactionToDB(db, {
    id: uuid(), businessId: db.business.id, kind: 'receive',
    treasuryId: db.treasuries[0]!.id, partyId: cust.id, amount: 200_000,
    date: now.slice(0, 10), method: 'cash', createdAt: now,
  });

  return db;
}

const db = seed();
const noop = () => {};

const pages: [string, React.ReactElement][] = [
  ['داشبورد', <Dashboard db={db} onNav={noop} />],
  ['فاکتورها', <Invoices db={db} setDB={noop} canWrite />],
  ['اشخاص', <Parties db={db} setDB={noop} canWrite />],
  ['کالاها', <Products db={db} setDB={noop} canWrite />],
  ['خزانه', <Treasury db={db} setDB={noop} canWrite />],
  ['گزارش‌ها', <Reports db={db} />],
  ['سامانهٔ مؤدیان', <Tax db={db} setDB={noop} canWrite />],
  ['ممیزی و دوره', <Audit db={db} setDB={noop} />],
  ['دفتر و اسناد', <Ledger db={db} setDB={noop} />],
  ['بستن سال', <YearEnd db={db} setDB={noop} />],
  ['حساب و همگام‌سازی', <Account db={db} setDB={noop} />],
  ['تنظیمات', <Settings db={db} setDB={noop} />],
  ['حالت فقط-خواندنی', <Invoices db={db} setDB={noop} canWrite={false} />],
];

let failed = 0;
for (const [name, el] of pages) {
  try {
    const html = renderToString(el);
    if (html.length < 100) throw new Error('خروجی خیلی کوتاه است');
    console.log(`✅ ${name} — ${html.length} کاراکتر`);
  } catch (e) {
    failed++;
    console.log(`❌ ${name} — ${(e as Error).message}`);
    console.log((e as Error).stack?.split('\n').slice(1, 5).join('\n'));
  }
}

// بررسی محتوای کلیدی داشبورد
const dash = renderToString(<Dashboard db={db} onNav={noop} />);
const checks: [string, boolean][] = [
  ['نمایش فروش امروز', dash.includes('فروش امروز')],
  ['نمایش سود', dash.includes('سود')],
  ['نام مشتری', dash.includes('مشتری الف')],
  ['شمارهٔ فاکتور', dash.includes('F-0001')],
  ['ارقام فارسی', /[۰-۹]/.test(dash)],
];
for (const [k, v] of checks) {
  console.log(v ? `✅ ${k}` : `❌ ${k}`);
  if (!v) failed++;
}

// حالت فقط-خواندنی نباید دکمهٔ ثبت نشان دهد
const ro = renderToString(<Invoices db={db} setDB={noop} canWrite={false} />);
const roOk = !ro.includes('+ فاکتور فروش');
console.log(roOk ? '✅ قفل نوشتن در حالت فقط-خواندنی' : '❌ دکمهٔ ثبت در حالت فقط-خواندنی دیده می‌شود');
if (!roOk) failed++;

// اما خروجی گرفتن باید باز بماند
const roParties = renderToString(<Parties db={db} setDB={noop} canWrite={false} />);
const expOk = roParties.includes('خروجی');
console.log(expOk ? '✅ خروجی گرفتن در حالت فقط-خواندنی آزاد است' : '❌ خروجی قفل شده');
if (!expOk) failed++;

// بررسی سامانهٔ مؤدیان
const taxHtml = renderToString(<Tax db={db} setDB={noop} canWrite />);
const sub = db.taxSubmissions[0];
const taxChecks: [string, boolean][] = [
  ['صورتحساب الکترونیکی صادر شد', !!sub],
  ['شمارهٔ مالیاتی ۲۲ کاراکتری', sub?.taxId.length === 22],
  ['شمارهٔ مالیاتی در صفحه دیده می‌شود', !!sub && taxHtml.includes(sub.taxId)],
  ['سریال افزایش یافت', db.taxProfile.lastSerial === 1],
  ['بدون هشدار پیکربندی', !taxHtml.includes('هنوز پیکربندی نشده')],
];
for (const [k, v] of taxChecks) {
  console.log(v ? `✅ ${k}` : `❌ ${k}`);
  if (!v) failed++;
}

// بررسی ردّ ممیزی و قفل دوره در جریان واقعی ثبت
{
  const auditChecks: [string, boolean][] = [
    ['ردّ ممیزی هنگام ثبت پر می‌شود', db.auditLogs.length > 0],
    ['ثبت فاکتور رویداد ایجاد دارد', db.auditLogs.some((l) => l.entity === 'invoice' && l.action === 'create')],
    ['ثبت شخص رویداد دارد', db.auditLogs.some((l) => l.entity === 'party')],
    ['هر رویداد کاربر و زمان دارد', db.auditLogs.every((l) => !!l.userId && !!l.at)],
  ];
  for (const [k, v] of auditChecks) {
    console.log(v ? `✅ ${k}` : `❌ ${k}`);
    if (!v) failed++;
  }

  // قفل دوره باید واقعاً جلوی ثبت را بگیرد
  const locked = lockPeriod(db, new Date().toISOString().slice(0, 10), 'آزمون');
  let blocked = false;
  try {
    postInvoiceToDB(locked, {
      ...db.invoices[0]!,
      id: uuid(),
      number: 'F-BLOCKED',
    });
  } catch (e) {
    blocked = (e as Error).name === 'PeriodLockedError';
  }
  console.log(blocked ? '✅ قفل دوره جلوی ثبت را می‌گیرد' : '❌ قفل دوره کار نمی‌کند');
  if (!blocked) failed++;

  // خارج از دورهٔ قفل باید آزاد باشد
  let allowed = false;
  try {
    const future = new Date(); future.setFullYear(future.getFullYear() + 1);
    postInvoiceToDB(locked, {
      ...db.invoices[0]!,
      id: uuid(),
      number: 'F-FUTURE',
      date: future.toISOString().slice(0, 10),
    });
    allowed = true;
  } catch { /* نباید رخ دهد */ }
  console.log(allowed ? '✅ خارج دورهٔ قفل ثبت آزاد است' : '❌ قفل بیش از حد سخت‌گیر است');
  if (!allowed) failed++;
}

// بستن سال مالی در جریان واقعی
{
  const { currentFiscalYear, balanceSheet, incomeStatement } = await import('@javid/core');
  const { indexOf } = await import('../src/store');

  // دفتر باید سالم باشد
  const health = integrityOf(db);
  const errs = health.filter((i) => i.severity === 'error');
  console.log(errs.length === 0 ? '✅ دفتر بدون خطای جدی است' : `❌ ${errs.length} خطای دفتر`);
  if (errs.length > 0) failed++;

  // سال گذشته را می‌بندیم (سال جاری هنوز تمام نشده)
  const thisYear = currentFiscalYear(new Date(), db.business.fiscalYearStartMonth);
  const target = thisYear - 1;

  const { preview } = closingPreviewFor(db, target);
  // دورهٔ گذشته داده ندارد، پس نباید قابل بستن باشد
  console.log(!preview.canClose ? '✅ سال بدون تراکنش بسته نمی‌شود' : '❌ سال خالی بسته شد');
  if (preview.canClose) failed++;

  // حالا سال جاری با داده — باید به‌خاطر تمام‌نشدن رد شود
  const { preview: cur } = closingPreviewFor(db, thisYear);
  const rejectsFuture = !cur.canClose && cur.issues.some((i) => i.includes('تمام نشده'));
  console.log(rejectsFuture ? '✅ سال تمام‌نشده بسته نمی‌شود' : '❌ سال جاری بسته شد');
  if (!rejectsFuture) failed++;

  console.log(closedYears(db).length === 0 ? '✅ هنوز سالی بسته نشده' : '❌ سال ناخواسته بسته شد');
}

// مانده اول دوره باید واقعاً به دفتر برود
{
  const { debtorsAndCreditors, balanceSheet } = await import('@javid/core');

  let d2 = createEmptyDB('آزمون افتتاحیه');
  const pid = uuid();
  d2 = upsertParty(d2, {
    id: pid, businessId: d2.business.id, kind: 'customer',
    name: 'بدهکار قبلی', openingBalance: 5_000_000,
  });

  const beforePost = debtorsAndCreditors(d2.entries, indexOf(d2), d2.parties).totalDebt;
  d2 = postOpeningBalances(d2);
  const afterPost = debtorsAndCreditors(d2.entries, indexOf(d2), d2.parties).totalDebt;

  const checks: [string, boolean][] = [
    ['پیش از ثبت، مانده در دفتر نیست', beforePost === 0],
    ['پس از ثبت، مانده در گزارش دیده می‌شود', afterPost === 5_000_000],
    ['سند افتتاحیه ثبت شد', hasOpeningEntry(d2)],
    ['ترازنامه پس از افتتاحیه متوازن است', balanceSheet(d2.entries, indexOf(d2)).balanced],
  ];

  // ثبت مجدد نباید مبلغ را دو برابر کند
  d2 = postOpeningBalances(d2);
  const twice = debtorsAndCreditors(d2.entries, indexOf(d2), d2.parties).totalDebt;
  checks.push(['ثبت مجدد مبلغ را دو برابر نمی‌کند', twice === 5_000_000]);

  for (const [k, v] of checks) {
    console.log(v ? `✅ ${k}` : `❌ ${k}`);
    if (!v) failed++;
  }
}

// سند دستی
{
  const { balanceSheet } = await import('@javid/core');
  const idx = indexOf(db);
  const cash = idx.all().find((a) => a.code === '1010')!;
  const capital = idx.all().find((a) => a.code === '3010')!;

  // نامتوازن باید رد شود
  const bad = validateManualEntry({
    date: '2026-07-29', description: 'تست',
    lines: [
      { accountId: cash.id, debit: 1000, credit: 0 },
      { accountId: capital.id, debit: 0, credit: 900 },
    ],
  });
  console.log(bad.length > 0 ? '✅ سند دستی نامتوازن رد می‌شود' : '❌ سند نامتوازن پذیرفته شد');
  if (bad.length === 0) failed++;

  // متوازن باید ثبت شود
  let d3 = postManualEntry(db, {
    date: '2026-07-29', description: 'آوردهٔ نقدی مالک',
    lines: [
      { accountId: cash.id, debit: 2_000_000, credit: 0 },
      { accountId: capital.id, debit: 0, credit: 2_000_000 },
    ],
  });
  const added = d3.entries.find((e) => e.sourceType === 'manual');
  console.log(added ? '✅ سند دستی ثبت شد' : '❌ سند دستی ثبت نشد');
  if (!added) failed++;

  const bal = balanceSheet(d3.entries, indexOf(d3)).balanced;
  console.log(bal ? '✅ ترازنامه پس از سند دستی متوازن است' : '❌ سند دستی ترازنامه را شکست');
  if (!bal) failed++;

  // حذف نرم
  d3 = voidManualEntry(d3, added!.id);
  const gone = d3.entries.find((e) => e.id === added!.id)?.deletedAt;
  console.log(gone ? '✅ حذف سند دستی نرم است' : '❌ حذف نرم کار نکرد');
  if (!gone) failed++;

  // سند خودکار نباید حذف شود
  const auto = db.entries.find((e) => e.sourceType === 'invoice')!;
  let blocked = false;
  try { voidManualEntry(db, auto.id); } catch { blocked = true; }
  console.log(blocked ? '✅ سند خودکار قابل حذف نیست' : '❌ سند خودکار حذف شد');
  if (!blocked) failed++;
}

console.log(failed === 0 ? '\n🟢 همهٔ صفحات سالم رندر شدند' : `\n🔴 ${failed} مورد ناموفق`);
process.exit(failed === 0 ? 0 : 1);
