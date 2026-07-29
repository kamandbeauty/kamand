/** تولید یک صفحهٔ HTML ایستا از داشبورد برای بازبینی چشمی */
import React from 'react';
import { renderToString } from 'react-dom/server';
import fs from 'node:fs';
import { Dashboard } from '../src/pages/Dashboard';
import { createEmptyDB, postInvoiceToDB, postTransactionToDB, upsertParty, upsertProduct, type DB } from '../src/store';
import { uuid, type Invoice } from '@javid/core';

function seed(): DB {
  let db = createEmptyDB('بوتیک ونک');
  const now = new Date().toISOString();
  const d = (off: number) => { const x = new Date(); x.setDate(x.getDate() - off); return x.toISOString().slice(0,10); };

  const names = ['آقای رضایی', 'خانم موسوی', 'فروشگاه پارس', 'آقای کریمی'];
  const parties = names.map((name, i) => ({
    id: uuid(), businessId: db.business.id,
    kind: (i === 2 ? 'vendor' : 'customer') as 'vendor' | 'customer',
    name, phone: `0912${String(1000000 + i * 137).slice(0,7)}`, openingBalance: 0,
  }));
  for (const p of parties) db = upsertParty(db, p);

  const goods = [
    ['پیراهن مردانه', 850_000, 1_450_000, 24, 5],
    ['شلوار جین', 1_200_000, 1_980_000, 12, 4],
    ['کفش چرم', 2_400_000, 3_850_000, 3, 4],
    ['کیف دستی', 1_650_000, 2_600_000, 8, 3],
  ] as const;

  const prods = goods.map(([name, buy, sell, qty, min]) => ({
    id: uuid(), businessId: db.business.id, kind: 'goods' as const, name,
    unitMain: 'عدد', buyPrice: buy, sellPrice: sell,
    openingQty: qty, openingCost: buy, minQty: min, vatRate: 10,
  }));
  for (const p of prods) db = upsertProduct(db, p);

  const sales: [number, number, number, number][] = [
    [0, 0, 2, 0], [0, 1, 1, 1], [1, 2, 1, 2], [3, 3, 2, 0], [5, 0, 3, 1], [8, 1, 1, 3],
  ];
  sales.forEach(([dayOff, pIdx, qty, partyIdx], i) => {
    const p = prods[pIdx]!;
    const inv: Invoice = {
      id: uuid(), businessId: db.business.id, type: 'sale',
      number: `F-${String(1001 + i)}`, partyId: parties[partyIdx]!.id,
      date: d(dayOff), isOfficial: i % 2 === 0,
      lines: [{ id: uuid(), productId: p.id, qty, unit: 'عدد', unitPrice: p.sellPrice, discount: 0, vatRate: i % 2 === 0 ? 10 : 0 }],
      discount: 0, shipping: 0, status: 'open', createdAt: now, updatedAt: now,
    };
    db = postInvoiceToDB(db, inv);
  });

  db = postTransactionToDB(db, {
    id: uuid(), businessId: db.business.id, kind: 'receive',
    treasuryId: db.treasuries[0]!.id, partyId: parties[0]!.id,
    amount: 4_500_000, date: d(1), method: 'cash', createdAt: now,
  });

  db.cheques.push({
    id: uuid(), businessId: db.business.id, direction: 'received',
    number: '412857', bankName: 'ملت', amount: 8_500_000,
    dueDate: d(-4), partyId: parties[1]!.id, status: 'pending', createdAt: now,
  }, {
    id: uuid(), businessId: db.business.id, direction: 'issued',
    number: '990112', bankName: 'صادرات', amount: 12_000_000,
    dueDate: d(2), partyId: parties[2]!.id, status: 'pending', createdAt: now,
  });

  return db;
}

const db = seed();
const body = renderToString(<Dashboard db={db} onNav={() => {}} />);
const css = fs.readFileSync(new URL('../src/styles.css', import.meta.url), 'utf8');

const nav = [
  ['🏠','داشبورد',true],['🧾','فاکتورها',false],['👥','اشخاص',false],
  ['📦','کالاها',false],['💳','خزانه و چک',false],['📊','گزارش‌ها',false],['⚙️','تنظیمات',false],
] as const;

const html = `<!doctype html><html lang="fa" dir="rtl"><head><meta charset="utf-8">
<title>جاوید — داشبورد</title><style>${css}</style></head><body>
<div class="app">
  <aside class="sidebar">
    <div class="brand"><h1>جاوید</h1><span>${db.business.name}</span></div>
    <nav class="nav">
      <div class="nav-group">
        ${nav.map(([i,l,a]) => `<button class="nav-item ${a?'active':''}"><span class="ico">${i}</span>${l}</button>`).join('')}
      </div>
    </nav>
  </aside>
  <div class="main">
    <header class="topbar"><h2>داشبورد</h2><div class="spacer"></div>
      <span class="sync-pill"><span class="dot green"></span>همگام</span>
    </header>
    <main class="content">${body}</main>
  </div>
</div></body></html>`;

fs.writeFileSync(new URL('../preview.html', import.meta.url), html);
console.log('نوشته شد: apps/web/preview.html —', html.length, 'کاراکتر');
