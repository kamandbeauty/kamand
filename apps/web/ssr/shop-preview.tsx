/**
 * پیش‌نمایش «مغازه» — منوی دو سطحی و فهرست فاکتورها با فروش نقدی.
 *
 * هدف: نشان دادن چشمی اینکه مسیر رایج مغازه کوتاه است — فروش نقدی
 * بدون ساختن مشتری، و منویی که کارهای روزمره را جلو می‌آورد.
 */
import React from 'react';
import { renderToString } from 'react-dom/server';
import fs from 'node:fs';
import { Invoices } from '../src/pages/Invoices';
import {
  createEmptyDB, indexOf, paymentInfoOf, postInvoiceToDB, postOpeningBalances,
  upsertParty, upsertProduct, type DB,
} from '../src/store';
import {
  debtorsAndCreditors, formatMoney, incomeStatement, treasuryBalance, uuid,
} from '@javid/core';

function seed(): DB {
  let db = createEmptyDB('سوپرمارکت محله');
  const now = new Date().toISOString();
  const t = now.slice(0, 10);

  const items = [
    ['نوشابه خانواده', 15_000, 25_000, 120],
    ['چیپس', 12_000, 20_000, 80],
    ['شیر پرچرب', 22_000, 32_000, 45],
    ['نان تست', 18_000, 28_000, 30],
  ] as const;

  const prods = items.map(([name, buy, sell, qty]) => ({
    id: uuid(), businessId: db.business.id, kind: 'goods' as const, name,
    unitMain: 'عدد', buyPrice: buy, sellPrice: sell,
    openingQty: qty, openingCost: buy, minQty: 10, vatRate: 0,
  }));
  for (const p of prods) db = upsertProduct(db, p);
  db = postOpeningBalances(db);

  const box = db.treasuries.find((x) => x.kind === 'cash')!;

  // چند فروش نقدی به مشتری عابر — بدون هیچ «شخص»ی
  const walkIns: [number, number, number][] = [[0, 2, 1], [1, 3, 2], [2, 1, 1], [0, 4, 3]];
  walkIns.forEach(([pIdx, qty, n]) => {
    const p = prods[pIdx]!;
    db = postInvoiceToDB(db, {
      id: uuid(), businessId: db.business.id, type: 'sale',
      number: `F-${String(1000 + n).padStart(4, '0')}`,
      partyId: null, date: t, isOfficial: false, isCash: true, treasuryId: box.id,
      lines: [{ id: uuid(), productId: p.id, qty, unit: 'عدد', unitPrice: p.sellPrice, discount: 0, vatRate: 0 }],
      discount: 0, shipping: 0, status: 'open', createdAt: now, updatedAt: now,
    });
  });

  // یک نسیه به مشتری همیشگی
  const reg = {
    id: uuid(), businessId: db.business.id, kind: 'customer' as const,
    name: 'حاج آقا رحیمی', phone: '09121234567', openingBalance: 0,
  };
  db = upsertParty(db, reg);
  db = postInvoiceToDB(db, {
    id: uuid(), businessId: db.business.id, type: 'sale', number: 'F-1005',
    partyId: reg.id, date: t, isOfficial: false, isCash: false,
    lines: [{ id: uuid(), productId: prods[2]!.id, qty: 6, unit: 'عدد', unitPrice: 32_000, discount: 0, vatRate: 0 }],
    discount: 0, shipping: 0, status: 'open', createdAt: now, updatedAt: now,
  });

  return db;
}

const db = seed();
const box = db.treasuries.find((x) => x.kind === 'cash')!;
const idx = indexOf(db);
const money = (n: number) => formatMoney(Math.round(n / 10), { unit: 'تومان' });

const cashCount = db.invoices.filter((i) => i.isCash).length;
const unpaid = db.invoices.filter((i) => paymentInfoOf(db, i).remaining > 0).length;

const body = renderToString(<Invoices db={db} setDB={() => {}} />);
const css = fs.readFileSync(new URL('../src/styles.css', import.meta.url), 'utf8');

// همان ساختار منوی دو سطحی برنامه
const daily = [
  ['🧾', 'فاکتورها', true], ['📦', 'کالاها', false], ['👥', 'اشخاص', false],
  ['💳', 'صندوق و چک', false], ['📊', 'گزارش‌ها', false],
] as const;

const html = `<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8">
<title>جاوید — مغازه</title><style>${css}</style></head><body>
<div class="app">
  <aside class="sidebar">
    <div class="brand"><h1>جاوید</h1><span>${db.business.name}</span></div>
    <nav class="nav">
      <div class="nav-group">
        <button class="nav-item"><span class="ico">🏠</span>داشبورد</button>
      </div>
      <div class="nav-group">
        <div class="nav-label">کارهای روزمره</div>
        ${daily.map(([i, l, a]) => `<button class="nav-item ${a ? 'active' : ''}"><span class="ico">${i}</span>${l}</button>`).join('')}
      </div>
      <div class="nav-group">
        <button class="nav-item"><span class="ico">▸</span>بیشتر</button>
      </div>
    </nav>
  </aside>
  <div class="main">
    <header class="topbar"><h2>فاکتورها</h2><div class="spacer"></div>
      <span class="sync-pill"><span class="dot green"></span>آفلاین — همه‌چیز محلی</span>
    </header>
    <main class="content">
      <div class="card" style="margin-bottom:14px">
        <div style="display:flex;gap:24px;flex-wrap:wrap;align-items:center">
          <div><span class="small muted">پول داخل صندوق</span><br><strong>${money(treasuryBalance(db.entries, box.id))}</strong></div>
          <div><span class="small muted">فروش نقدی امروز</span><br><strong>${cashCount} فاکتور بدون ساختن مشتری</strong></div>
          <div><span class="small muted">طلب از مشتریان</span><br><strong>${money(debtorsAndCreditors(db.entries, idx, db.parties).totalDebt)}</strong></div>
          <div><span class="small muted">تسویه‌نشده</span><br><strong>${unpaid} فاکتور</strong></div>
          <div><span class="small muted">سود امروز</span><br><strong>${money(incomeStatement(db.entries, idx, {}).netProfit)}</strong></div>
        </div>
      </div>
      ${body}
    </main>
  </div>
</div></body></html>`;

fs.writeFileSync(new URL('../shop-preview.html', import.meta.url), html);
console.error('نوشته شد: apps/web/shop-preview.html —', html.length, 'کاراکتر');
