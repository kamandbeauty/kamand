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
import { createEmptyDB, issueElectronicInvoice, postInvoiceToDB, postTransactionToDB, taxReadiness, updateTaxProfile, upsertParty, upsertProduct, type DB } from '../src/store';
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

console.log(failed === 0 ? '\n🟢 همهٔ صفحات سالم رندر شدند' : `\n🔴 ${failed} مورد ناموفق`);
process.exit(failed === 0 ? 0 : 1);
