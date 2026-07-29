import React, { useMemo, useState } from 'react';
import {
  comparePeriods, customerPerformance, monthlyTrend, monthRanges,
  productPerformance, salesSummary, staleProducts, stockByProduct,
  toCSV, toPersianDigits, type Party, type Product,
} from '@javid/core';
import { type DB } from '../store';
import { Badge, Banner, Card, DateInput, Empty, Money, Search, Tabs, download } from '../ui';

const fa = (n: number) => toPersianDigits(n);
const pct = (n: number) => `${n > 0 ? '+' : ''}${fa(n)}٪`;

/**
 * تحلیل فروش.
 *
 * هشت گزارش موجود همگی حسابداری کلاسیک‌اند. این صفحه به سؤال
 * روزمرهٔ مغازه‌دار پاسخ می‌دهد: کدام کالا سود دارد، کدام مشتری
 * بیشتر می‌خرد، و روند فروش چطور است.
 */
export function Analytics({ db }: { db: DB }) {
  const [tab, setTab] = useState<'summary' | 'products' | 'customers' | 'stale'>('summary');

  const ranges = monthRanges();
  const [from, setFrom] = useState(ranges.current.from!);
  const [to, setTo] = useState(ranges.current.to!);

  const range = { from, to };
  const productMap = useMemo(() => new Map(db.products.map((p) => [p.id, p])), [db.products]);
  const partyMap = useMemo(() => new Map(db.parties.map((p) => [p.id, p])), [db.parties]);

  return (
    <>
      <div className="toolbar no-print">
        <label className="small muted">از</label>
        <div style={{ width: 130 }}><DateInput value={from} onChange={setFrom} /></div>
        <label className="small muted">تا</label>
        <div style={{ width: 130 }}><DateInput value={to} onChange={setTo} /></div>
        <button className="btn btn-sm" onClick={() => { setFrom(ranges.current.from!); setTo(ranges.current.to!); }}>
          این ماه
        </button>
        <button className="btn btn-sm" onClick={() => { setFrom(ranges.previous.from!); setTo(ranges.previous.to!); }}>
          ماه قبل
        </button>
        <div style={{ flex: 1 }} />
        <button className="btn" onClick={() => window.print()}>🖨 چاپ</button>
      </div>

      <Tabs
        active={tab}
        onChange={setTab}
        tabs={[
          { id: 'summary' as const, label: 'خلاصه و روند' },
          { id: 'products' as const, label: 'کالاها' },
          { id: 'customers' as const, label: 'مشتریان' },
          { id: 'stale' as const, label: 'کالاهای راکد' },
        ]}
      />

      {tab === 'summary' && <SummaryTab db={db} range={range} productMap={productMap} partyMap={partyMap} />}
      {tab === 'products' && <ProductsTab db={db} range={range} productMap={productMap} />}
      {tab === 'customers' && <CustomersTab db={db} range={range} partyMap={partyMap} />}
      {tab === 'stale' && <StaleTab db={db} />}
    </>
  );
}

type Ctx = {
  db: DB;
  range: { from: string; to: string };
  productMap: Map<string, Product>;
  partyMap: Map<string, Party>;
};

// ─────────── خلاصه ───────────

function SummaryTab({ db, range, productMap, partyMap }: Ctx) {
  const s = salesSummary(db.invoices, productMap, partyMap, range);
  const ranges = monthRanges();
  const cmp = comparePeriods(db.invoices, ranges.current, ranges.previous);
  const trend = monthlyTrend(db.invoices, {}, 12);

  const maxRevenue = Math.max(...trend.map((t) => t.revenue), 1);

  return (
    <>
      <div className="grid grid-4" style={{ marginBottom: 18 }}>
        <div className="card stat">
          <div className="label">فروش دوره</div>
          <div className="value"><Money value={s.revenue} /></div>
        </div>
        <div className={`card stat ${s.profit >= 0 ? 'pos' : 'neg'}`}>
          <div className="label">سود دوره</div>
          <div className="value"><Money value={s.profit} /></div>
          <div className="sub">حاشیه: <span className="num">{fa(s.margin)}٪</span></div>
        </div>
        <div className="card stat">
          <div className="label">تعداد فاکتور</div>
          <div className="value"><span className="num">{fa(s.invoiceCount)}</span></div>
        </div>
        <div className="card stat">
          <div className="label">میانگین هر فاکتور</div>
          <div className="value"><Money value={s.averageInvoice} /></div>
        </div>
      </div>

      <Card title="مقایسه با ماه قبل">
        <table>
          <thead>
            <tr><th></th><th className="end">این ماه</th><th className="end">ماه قبل</th><th className="end">تغییر</th></tr>
          </thead>
          <tbody>
            <tr>
              <td>فروش</td>
              <td className="end"><Money value={cmp.current.revenue} /></td>
              <td className="end muted"><Money value={cmp.previous.revenue} /></td>
              <td className="end">
                <Badge tone={cmp.revenueChange >= 0 ? 'green' : 'red'}>{pct(cmp.revenueChange)}</Badge>
              </td>
            </tr>
            <tr>
              <td>سود</td>
              <td className="end"><Money value={cmp.current.profit} /></td>
              <td className="end muted"><Money value={cmp.previous.profit} /></td>
              <td className="end">
                <Badge tone={cmp.profitChange >= 0 ? 'green' : 'red'}>{pct(cmp.profitChange)}</Badge>
              </td>
            </tr>
            <tr>
              <td>تعداد فاکتور</td>
              <td className="end num">{fa(cmp.current.count)}</td>
              <td className="end num muted">{fa(cmp.previous.count)}</td>
              <td className="end">
                <Badge tone={cmp.countChange >= 0 ? 'green' : 'red'}>{pct(cmp.countChange)}</Badge>
              </td>
            </tr>
          </tbody>
        </table>
      </Card>

      <Card title="روند ۱۲ ماه اخیر">
        {trend.every((t) => t.revenue === 0) ? (
          <Empty icon="📈" text="هنوز فروشی ثبت نشده است" />
        ) : (
          <table>
            <thead>
              <tr><th>ماه</th><th style={{ width: '40%' }}>فروش</th><th className="end">مبلغ</th><th className="end">سود</th></tr>
            </thead>
            <tbody>
              {trend.map((t) => (
                <tr key={`${t.jy}-${t.jm}`}>
                  <td className="small">{t.label}</td>
                  <td>
                    {/* نمودار میله‌ای ساده، بدون کتابخانهٔ خارجی */}
                    <div style={{
                      height: 8, borderRadius: 4, background: 'var(--teal-500)',
                      width: `${Math.max(2, (t.revenue / maxRevenue) * 100)}%`,
                      opacity: t.revenue > 0 ? 1 : 0.15,
                    }} />
                  </td>
                  <td className="end"><Money value={t.revenue} /></td>
                  <td className={`end ${t.profit >= 0 ? 'money-pos' : 'money-neg'}`}>
                    <Money value={t.profit} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>

      {(s.topProduct || s.topCustomer) && (
        <div className="grid grid-2">
          {s.topProduct && (
            <Card title="پرسودترین کالا">
              <div style={{ fontSize: 17, fontWeight: 600 }}>{s.topProduct.name}</div>
              <div className="small muted">سود دوره: <Money value={s.topProduct.profit} /></div>
            </Card>
          )}
          {s.topCustomer && (
            <Card title="پرفروش‌ترین مشتری">
              <div style={{ fontSize: 17, fontWeight: 600 }}>{s.topCustomer.name}</div>
              <div className="small muted">خرید دوره: <Money value={s.topCustomer.revenue} /></div>
            </Card>
          )}
        </div>
      )}
    </>
  );
}

// ─────────── کالاها ───────────

function ProductsTab({ db, range, productMap }: Omit<Ctx, 'partyMap'>) {
  const [q, setQ] = useState('');
  const rows = productPerformance(db.invoices, productMap, range)
    .filter((r) => !q.trim() || r.name.toLowerCase().includes(q.trim().toLowerCase()));

  return (
    <>
      <div className="toolbar no-print">
        <Search value={q} onChange={setQ} placeholder="جستجوی کالا…" />
        <div style={{ flex: 1 }} />
        <button className="btn" onClick={() => download('عملکرد-کالاها.csv', toCSV(rows, [
          { key: 'name', header: 'کالا', value: (r) => r.name },
          { key: 'qty', header: 'تعداد', value: (r) => r.qty },
          { key: 'revenue', header: 'فروش', value: (r) => r.revenue },
          { key: 'cogs', header: 'بهای تمام‌شده', value: (r) => r.cogs },
          { key: 'profit', header: 'سود', value: (r) => r.profit },
          { key: 'margin', header: 'حاشیه٪', value: (r) => r.margin },
        ]), 'text/csv;charset=utf-8')}>⬇ خروجی</button>
      </div>

      <Card>
        {rows.length === 0 ? (
          <Empty icon="📦" text="در این بازه فروشی ثبت نشده است" />
        ) : (
          <table>
            <thead>
              <tr>
                <th>کالا</th>
                <th className="end">تعداد</th>
                <th className="end">فروش</th>
                <th className="end">بهای تمام‌شده</th>
                <th className="end">سود</th>
                <th className="end">حاشیه</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.productId}>
                  <td className="strong">{r.name}</td>
                  <td className="end num">{fa(r.qty)}</td>
                  <td className="end"><Money value={r.revenue} /></td>
                  <td className="end muted"><Money value={r.cogs} /></td>
                  <td className={`end ${r.profit >= 0 ? 'money-pos' : 'money-neg'}`}>
                    <Money value={r.profit} />
                  </td>
                  <td className="end">
                    <Badge tone={r.margin >= 30 ? 'green' : r.margin >= 10 ? 'amber' : 'red'}>
                      {fa(r.margin)}٪
                    </Badge>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
    </>
  );
}

// ─────────── مشتریان ───────────

function CustomersTab({ db, range, partyMap }: Omit<Ctx, 'productMap'>) {
  const rows = customerPerformance(db.invoices, partyMap, range);

  return (
    <>
      <div className="toolbar no-print">
        <div style={{ flex: 1 }} />
        <button className="btn" onClick={() => download('عملکرد-مشتریان.csv', toCSV(rows, [
          { key: 'name', header: 'مشتری', value: (r) => r.name },
          { key: 'revenue', header: 'خرید', value: (r) => r.revenue },
          { key: 'profit', header: 'سود', value: (r) => r.profit },
          { key: 'count', header: 'تعداد فاکتور', value: (r) => r.invoiceCount },
        ]), 'text/csv;charset=utf-8')}>⬇ خروجی</button>
      </div>

      <Card>
        {rows.length === 0 ? (
          <Empty icon="👥" text="در این بازه خریدی ثبت نشده است" />
        ) : (
          <table>
            <thead>
              <tr>
                <th>مشتری</th>
                <th className="end">مبلغ خرید</th>
                <th className="end">سود ما</th>
                <th className="end">تعداد فاکتور</th>
                <th className="end">میانگین</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.partyId}>
                  <td className="strong">{r.name}</td>
                  <td className="end"><Money value={r.revenue} /></td>
                  <td className={`end ${r.profit >= 0 ? 'money-pos' : 'money-neg'}`}>
                    <Money value={r.profit} />
                  </td>
                  <td className="end num">{fa(r.invoiceCount)}</td>
                  <td className="end"><Money value={r.averageInvoice} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
    </>
  );
}

// ─────────── راکد ───────────

function StaleTab({ db }: { db: DB }) {
  const [minDays, setMinDays] = useState(60);
  const stock = useMemo(
    () => stockByProduct(db.movements, db.business.costingMethod, { allowNegative: true }),
    [db.movements, db.business.costingMethod],
  );

  const rows = staleProducts(db.invoices, db.products, stock, { minDays });
  const total = rows.reduce((s, r) => s + r.value, 0);

  return (
    <>
      <Banner tone="info">
        کالاهایی که موجودی دارند ولی مدتی فروش نرفته‌اند — سرمایه‌ای
        که در انبار خوابیده است.
      </Banner>

      <div className="toolbar no-print">
        <label className="small muted">راکد بیش از</label>
        <select
          className="select"
          style={{ maxWidth: 130 }}
          value={minDays}
          onChange={(e) => setMinDays(Number(e.target.value))}
        >
          <option value={30}>۳۰ روز</option>
          <option value={60}>۶۰ روز</option>
          <option value={90}>۹۰ روز</option>
          <option value={180}>۶ ماه</option>
        </select>
        <div style={{ flex: 1 }} />
        {rows.length > 0 && (
          <Badge tone="amber">سرمایهٔ خوابیده: <Money value={total} /></Badge>
        )}
      </div>

      <Card>
        {rows.length === 0 ? (
          <Empty icon="✅" text="کالای راکدی وجود ندارد" />
        ) : (
          <table>
            <thead>
              <tr>
                <th>کالا</th>
                <th className="end">موجودی</th>
                <th className="end">ارزش</th>
                <th className="end">آخرین فروش</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.productId}>
                  <td>{r.name}</td>
                  <td className="end num">{fa(r.qty)}</td>
                  <td className="end"><Money value={r.value} /></td>
                  <td className="end">
                    {r.daysSinceSold === null ? (
                      <Badge tone="red">هرگز</Badge>
                    ) : (
                      <span className="num muted">{fa(r.daysSinceSold)} روز پیش</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
    </>
  );
}
