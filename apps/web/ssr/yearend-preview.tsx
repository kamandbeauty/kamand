/**
 * پیش‌نمایش چرخهٔ بستن سال — گزارش‌ها پیش و پس از بستن کنار هم.
 *
 * هدف: نشان دادن چشمی اینکه پس از بستن سال مالی، طلب مشتریان و
 * ترازنامه دست‌نخورده می‌مانند و سود همان سال هنوز گزارش می‌شود.
 */
import React from 'react';
import { renderToString } from 'react-dom/server';
import fs from 'node:fs';
import { Reports } from '../src/pages/Reports';
import {
  closeYear, createEmptyDB, indexOf, postInvoiceToDB, postOpeningBalances,
  upsertParty, upsertProduct, type DB,
} from '../src/store';
import {
  balanceOf, currentFiscalYear, debtorsAndCreditors, fiscalYearBounds,
  formatMoney, incomeStatement, SYSTEM_ACCOUNTS as A, toPersianDigits, uuid,
  type Invoice,
} from '@javid/core';

const lastYear = new Date();
lastYear.setFullYear(lastYear.getFullYear() - 1);

function seed(): { db: DB; jy: number } {
  let db = createEmptyDB('پوشاک آفتاب');
  const now = new Date().toISOString();

  const customers = ['آقای نیک‌پور', 'خانم صادقی', 'بوتیک آرا'].map((name, i) => ({
    id: uuid(), businessId: db.business.id, kind: 'customer' as const,
    name, phone: `0912${String(3000000 + i * 421).slice(0, 7)}`, openingBalance: 0,
  }));
  for (const p of customers) db = upsertParty(db, p);

  const goods = [
    ['مانتو اداری', 1_400_000, 2_300_000, 30],
    ['روسری ابریشم', 620_000, 1_050_000, 40],
    ['پالتو زمستانی', 3_100_000, 4_900_000, 15],
  ] as const;

  const prods = goods.map(([name, buy, sell, qty]) => ({
    id: uuid(), businessId: db.business.id, kind: 'goods' as const, name,
    unitMain: 'عدد', buyPrice: buy, sellPrice: sell,
    openingQty: qty, openingCost: buy, minQty: 3, vatRate: 0,
  }));
  for (const p of prods) db = upsertProduct(db, p);
  db = postOpeningBalances(db);

  // فروش‌های نسیهٔ سال گذشته — همان‌هایی که نباید در انتقال گم شوند
  const ly = (m: number) => {
    const x = new Date(lastYear);
    x.setMonth(x.getMonth() - m);
    return x.toISOString().slice(0, 10);
  };

  const sales: [number, number, number, number][] = [
    [2, 0, 4, 0], [4, 1, 6, 1], [6, 2, 2, 2], [8, 0, 3, 1],
  ];
  sales.forEach(([monthOff, pIdx, qty, cIdx], i) => {
    const p = prods[pIdx]!;
    const inv: Invoice = {
      id: uuid(), businessId: db.business.id, type: 'sale',
      number: `F-${String(2001 + i)}`, partyId: customers[cIdx]!.id,
      date: ly(monthOff), isOfficial: false,
      lines: [{ id: uuid(), productId: p.id, qty, unit: 'عدد', unitPrice: p.sellPrice, discount: 0, vatRate: 0 }],
      discount: 0, shipping: 0, status: 'open', createdAt: now, updatedAt: now,
    };
    db = postInvoiceToDB(db, inv);
  });

  return { db, jy: currentFiscalYear(lastYear, db.business.fiscalYearStartMonth) };
}

const { db: before, jy } = seed();
const after = closeYear(before, jy, false);
const bounds = fiscalYearBounds(jy, before.business.fiscalYearStartMonth);

const fa = (n: number) => toPersianDigits(n);
// از قالب‌بندی خود هسته استفاده می‌شود تا جداکنندهٔ هزارگان درست بیفتد
const money = (n: number) => formatMoney(Math.round(n / 10), { unit: 'تومان' });

function figures(db: DB) {
  const idx = indexOf(db);
  return {
    debt: debtorsAndCreditors(db.entries, idx, db.parties).totalDebt,
    profit: incomeStatement(db.entries, idx, bounds).netProfit,
    receivable: balanceOf(db.entries, idx.id(A.RECEIVABLE)),
    summary: balanceOf(db.entries, idx.id(A.CLOSING_SUMMARY)),
    entries: db.entries.filter((e) => !e.deletedAt).length,
  };
}

const f1 = figures(before);
const f2 = figures(after);

const rows: [string, number, number][] = [
  ['طلب از مشتریان', f1.debt, f2.debt],
  ['مانده حساب دریافتنی', f1.receivable, f2.receivable],
  [`سود ${bounds.label}`, f1.profit, f2.profit],
];

const css = fs.readFileSync(new URL('../src/styles.css', import.meta.url), 'utf8');
const body = renderToString(<Reports db={after} />);

const compare = rows.map(([label, a, b]) => {
  const same = a === b;
  return `<tr>
    <td>${label}</td>
    <td class="end">${money(a)}</td>
    <td class="end">${money(b)}</td>
    <td class="end">${same
      ? '<span class="badge green">✓ بدون تغییر</span>'
      : `<span class="badge red">✕ ${money(b - a)} اختلاف</span>`}</td>
  </tr>`;
}).join('');

const html = `<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8">
<title>جاوید — بستن سال مالی</title><style>${css}
.wrap{padding:24px;max-width:1100px;margin:0 auto}
.note{background:var(--surface,#fff);border:1px solid var(--border,#e3e6ea);border-radius:12px;padding:16px;margin-bottom:18px}
</style></head><body>
<div class="wrap">
  <h2 style="margin-bottom:4px">چرخهٔ بستن سال مالی — ${bounds.label}</h2>
  <p class="small muted" style="margin-bottom:18px">
    ${fa(f2.entries - f1.entries)} سند تازه ثبت شد: اختتامیه، بستن حساب‌های دائمی و افتتاحیهٔ سال بعد.
  </p>

  <div class="note">
    <table>
      <thead><tr><th>شاخص</th><th class="end">پیش از بستن</th><th class="end">پس از بستن</th><th class="end">نتیجه</th></tr></thead>
      <tbody>${compare}</tbody>
    </table>
    <div class="small muted" style="margin-top:10px">
      حساب واسط تراز اختتامیه: <strong>${money(f2.summary)}</strong> — بستن و بازکردن یکدیگر را خنثی کرده‌اند.
    </div>
  </div>

  <div class="note">${body}</div>
</div></body></html>`;

fs.writeFileSync(new URL('../yearend-preview.html', import.meta.url), html);
console.error('نوشته شد: apps/web/yearend-preview.html —', html.length, 'کاراکتر');
