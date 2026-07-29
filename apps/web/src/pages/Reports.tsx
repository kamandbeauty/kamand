import React, { useState } from 'react';
import {
  accountOverview, balanceSheet, capitalStatement, debtorsAndCreditors,
  fiscalYearRange, incomeStatement, journal, stockByProduct, toCSV,
  trialBalance, toPersianDigits, type AccountOverviewNode,
} from '@javid/core';

const fa = (n: number) => toPersianDigits(n);
import { indexOf, type DB } from '../store';
import { Badge, Banner, Card, DateInput, Empty, JDate, Money, Tabs, download } from '../ui';

type ReportId =
  | 'income' | 'balance' | 'trial' | 'debtors'
  | 'stock' | 'journal' | 'overview' | 'capital';

const REPORTS: { id: ReportId; label: string }[] = [
  { id: 'income', label: 'سود و زیان' },
  { id: 'balance', label: 'ترازنامه' },
  { id: 'trial', label: 'تراز آزمایشی' },
  { id: 'debtors', label: 'بدهکاران و بستانکاران' },
  { id: 'stock', label: 'موجودی کالا' },
  { id: 'journal', label: 'دفتر روزنامه' },
  { id: 'overview', label: 'مرور حساب‌ها' },
  { id: 'capital', label: 'صورتحساب سرمایه' },
];

export function Reports({ db }: { db: DB }) {
  const [report, setReport] = useState<ReportId>('income');
  const fy = fiscalYearRange(new Date(), db.business.fiscalYearStartMonth);
  const [from, setFrom] = useState(fy.from.toISOString().slice(0, 10));
  const [to, setTo] = useState(new Date().toISOString().slice(0, 10));

  const index = indexOf(db);
  const filter = { from, to };

  return (
    <>
      <div className="toolbar no-print">
        <label className="small muted">از تاریخ</label>
        <div style={{ width: 130 }}><DateInput value={from} onChange={setFrom} /></div>
        <label className="small muted">تا تاریخ</label>
        <div style={{ width: 130 }}><DateInput value={to} onChange={setTo} /></div>
        <button className="btn btn-sm" onClick={() => {
          setFrom(fy.from.toISOString().slice(0, 10));
          setTo(new Date().toISOString().slice(0, 10));
        }}>{fy.label}</button>
        <div style={{ flex: 1 }} />
        <button className="btn" onClick={() => window.print()}>🖨 چاپ</button>
      </div>

      <Tabs active={report} onChange={setReport} tabs={REPORTS} />

      <div className="print-only" style={{ marginBottom: 12 }}>
        <div style={{ fontSize: 16, fontWeight: 700 }}>{db.business.name}</div>
        <div className="small">
          {REPORTS.find((r) => r.id === report)?.label} — از <JDate value={from} /> تا <JDate value={to} />
        </div>
      </div>

      {report === 'income' && <IncomeReport db={db} index={index} filter={filter} />}
      {report === 'balance' && <BalanceReport db={db} index={index} filter={filter} />}
      {report === 'trial' && <TrialReport db={db} index={index} filter={filter} />}
      {report === 'debtors' && <DebtorsReport db={db} index={index} filter={filter} />}
      {report === 'stock' && <StockReport db={db} />}
      {report === 'journal' && <JournalReport db={db} index={index} filter={filter} />}
      {report === 'overview' && <OverviewReport db={db} index={index} filter={filter} />}
      {report === 'capital' && <CapitalReport db={db} index={index} filter={filter} />}
    </>
  );
}

type Ctx = { db: DB; index: ReturnType<typeof indexOf>; filter: { from: string; to: string } };

function IncomeReport({ db, index, filter }: Ctx) {
  const r = incomeStatement(db.entries, index, filter);
  return (
    <Card>
      <table>
        <tbody>
          <tr><td>فروش</td><td className="end"><Money value={r.revenue} /></td></tr>
          {r.salesReturns > 0 && (
            <tr><td className="muted">برگشت از فروش</td><td className="end money-neg">(<Money value={r.salesReturns} />)</td></tr>
          )}
          <tr className="report-total">
            <td>فروش خالص</td><td className="end"><Money value={r.netRevenue} /></td>
          </tr>
          <tr><td>بهای تمام‌شدهٔ کالای فروش‌رفته</td><td className="end money-neg">(<Money value={r.cogs} />)</td></tr>
          <tr className="report-total">
            <td>سود ناخالص</td>
            <td className="end"><Money value={r.grossProfit} sign /></td>
          </tr>

          <tr><td colSpan={2} style={{ paddingTop: 18, fontWeight: 600 }}>هزینه‌های عملیاتی</td></tr>
          {r.expenses.length === 0 && (
            <tr><td className="muted" style={{ paddingInlineStart: 24 }}>هزینه‌ای ثبت نشده</td><td className="end">—</td></tr>
          )}
          {r.expenses.map((e) => (
            <tr key={e.code}>
              <td style={{ paddingInlineStart: 24 }}>{e.name}</td>
              <td className="end"><Money value={e.amount} /></td>
            </tr>
          ))}
          <tr><td>جمع هزینه‌ها</td><td className="end money-neg">(<Money value={r.totalExpenses} />)</td></tr>
          {r.otherIncome > 0 && (
            <tr><td>درآمدهای متفرقه</td><td className="end money-pos"><Money value={r.otherIncome} /></td></tr>
          )}

          <tr className="report-total" style={{ fontSize: 16 }}>
            <td>{r.netProfit >= 0 ? 'سود خالص' : 'زیان خالص'}</td>
            <td className="end"><Money value={r.netProfit} sign /></td>
          </tr>
        </tbody>
      </table>
    </Card>
  );
}

function BalanceReport({ db, index, filter }: Ctx) {
  const r = balanceSheet(db.entries, index, filter);
  const Section = ({ title, items, total }: { title: string; items: { code: string; name: string; amount: number }[]; total: number }) => (
    <table style={{ marginBottom: 8 }}>
      <thead><tr><th colSpan={2}>{title}</th></tr></thead>
      <tbody>
        {items.length === 0 && <tr><td className="muted">—</td><td className="end">۰</td></tr>}
        {items.map((i) => (
          <tr key={i.code}><td>{i.name}</td><td className="end"><Money value={i.amount} /></td></tr>
        ))}
        <tr className="report-total"><td>جمع</td><td className="end"><Money value={total} /></td></tr>
      </tbody>
    </table>
  );

  return (
    <>
      {!r.balanced && (
        <Banner tone="critical" title="ترازنامه متوازن نیست">
          این نشانهٔ خطای داده است. لطفاً با پشتیبانی تماس بگیرید.
        </Banner>
      )}
      <div className="grid grid-2">
        <Card title="دارایی‌ها">
          <Section title="" items={r.assets.items} total={r.assets.total} />
        </Card>
        <div style={{ display: 'grid', gap: 16, alignContent: 'start' }}>
          <Card title="بدهی‌ها">
            <Section title="" items={r.liabilities.items} total={r.liabilities.total} />
          </Card>
          <Card title="حقوق صاحبان سرمایه">
            <table>
              <tbody>
                {r.equity.items.map((i) => (
                  <tr key={i.code}><td>{i.name}</td><td className="end"><Money value={i.amount} /></td></tr>
                ))}
                <tr><td>سود (زیان) دوره</td><td className="end"><Money value={r.netProfit} sign /></td></tr>
                <tr className="report-total"><td>جمع</td><td className="end"><Money value={r.equity.total} /></td></tr>
              </tbody>
            </table>
          </Card>
        </div>
      </div>
      <Card className="no-print">
        <div style={{ display: 'flex', gap: 20, alignItems: 'center', marginTop: 4 }}>
          <div>جمع دارایی‌ها: <strong><Money value={r.assets.total} /></strong></div>
          <div>جمع بدهی‌ها و سرمایه: <strong><Money value={r.totalLiabilitiesAndEquity} /></strong></div>
          <Badge tone={r.balanced ? 'green' : 'red'}>{r.balanced ? '✓ متوازن' : '✕ نامتوازن'}</Badge>
        </div>
      </Card>
    </>
  );
}

function TrialReport({ db, index, filter }: Ctx) {
  const r = trialBalance(db.entries, index, filter);
  return (
    <Card>
      {r.rows.length === 0 ? <Empty icon="📊" text="سندی در این بازه ثبت نشده است" /> : (
        <table>
          <thead>
            <tr><th>کد</th><th>نام حساب</th><th className="end">بدهکار</th><th className="end">بستانکار</th></tr>
          </thead>
          <tbody>
            {r.rows.map((row) => (
              <tr key={row.code}>
                <td className="num muted">{row.code}</td>
                <td>{row.name}</td>
                <td className="end">{row.debit ? <Money value={row.debit} /> : '—'}</td>
                <td className="end">{row.credit ? <Money value={row.credit} /> : '—'}</td>
              </tr>
            ))}
            <tr className="report-total">
              <td colSpan={2}>جمع</td>
              <td className="end"><Money value={r.totalDebit} /></td>
              <td className="end"><Money value={r.totalCredit} /></td>
            </tr>
          </tbody>
        </table>
      )}
      <div style={{ marginTop: 12 }}>
        <Badge tone={r.balanced ? 'green' : 'red'}>{r.balanced ? '✓ تراز است' : '✕ تراز نیست'}</Badge>
      </div>
    </Card>
  );
}

function DebtorsReport({ db, index, filter }: Ctx) {
  const r = debtorsAndCreditors(db.entries, index, db.parties, filter);
  return (
    <div className="grid grid-2">
      <Card title={`بدهکاران (${fa(r.debtors.length)})`}>
        {r.debtors.length === 0 ? <Empty icon="✅" text="بدهکاری وجود ندارد" /> : (
          <table>
            <tbody>
              {r.debtors.map((d) => (
                <tr key={d.partyId}>
                  <td>{d.name}<div className="small muted num">{d.phone}</div></td>
                  <td className="end money-pos"><Money value={d.balance} /></td>
                </tr>
              ))}
              <tr className="report-total"><td>جمع</td><td className="end"><Money value={r.totalDebt} /></td></tr>
            </tbody>
          </table>
        )}
      </Card>
      <Card title={`بستانکاران (${fa(r.creditors.length)})`}>
        {r.creditors.length === 0 ? <Empty icon="✅" text="بستانکاری وجود ندارد" /> : (
          <table>
            <tbody>
              {r.creditors.map((c) => (
                <tr key={c.partyId}>
                  <td>{c.name}<div className="small muted num">{c.phone}</div></td>
                  <td className="end money-neg"><Money value={Math.abs(c.balance)} /></td>
                </tr>
              ))}
              <tr className="report-total"><td>جمع</td><td className="end"><Money value={r.totalCredit} /></td></tr>
            </tbody>
          </table>
        )}
      </Card>
    </div>
  );
}

function StockReport({ db }: { db: DB }) {
  const stock = stockByProduct(db.movements, db.business.costingMethod, { allowNegative: true });
  const goods = db.products.filter((p) => p.kind === 'goods' && !p.archived);
  const total = goods.reduce((s, p) => s + (stock.get(p.id)?.value ?? 0), 0);

  return (
    <Card
      action={
        <button className="btn btn-sm" onClick={() => {
          download('موجودی-کالا.csv', toCSV(goods, [
            { key: 'name', header: 'نام', value: (p) => p.name },
            { key: 'qty', header: 'موجودی', value: (p) => stock.get(p.id)?.qty ?? 0 },
            { key: 'unit', header: 'واحد', value: (p) => p.unitMain },
            { key: 'value', header: 'ارزش', value: (p) => stock.get(p.id)?.value ?? 0 },
          ]), 'text/csv;charset=utf-8');
        }}>⬇ خروجی</button>
      }
    >
      {goods.length === 0 ? <Empty icon="📦" text="کالایی ثبت نشده است" /> : (
        <table>
          <thead>
            <tr><th>نام کالا</th><th className="end">موجودی</th><th>واحد</th><th className="end">ارزش</th></tr>
          </thead>
          <tbody>
            {goods.map((p) => {
              const s = stock.get(p.id);
              return (
                <tr key={p.id}>
                  <td>{p.name}</td>
                  <td className={`end num ${(s?.qty ?? 0) < 0 ? 'money-neg' : ''}`}>{fa(s?.qty ?? 0)}</td>
                  <td className="small muted">{p.unitMain}</td>
                  <td className="end"><Money value={s?.value ?? 0} /></td>
                </tr>
              );
            })}
            <tr className="report-total">
              <td colSpan={3}>ارزش کل موجودی</td>
              <td className="end"><Money value={total} /></td>
            </tr>
          </tbody>
        </table>
      )}
    </Card>
  );
}

function JournalReport({ db, index, filter }: Ctx) {
  const rows = journal(db.entries, index, filter);
  return (
    <Card>
      {rows.length === 0 ? <Empty icon="📖" text="سندی در این بازه ثبت نشده است" /> : (
        <table>
          <thead>
            <tr><th>تاریخ</th><th>شرح</th><th>حساب</th><th className="end">بدهکار</th><th className="end">بستانکار</th></tr>
          </thead>
          <tbody>
            {rows.map((e) =>
              e.lines.map((l, li) => (
                <tr key={`${e.entryId}-${li}`}>
                  {li === 0 ? (
                    <>
                      <td rowSpan={e.lines.length}><JDate value={e.date} /></td>
                      <td rowSpan={e.lines.length}>{e.description}</td>
                    </>
                  ) : null}
                  <td className="small"><span className="num muted">{l.code}</span> {l.name}</td>
                  <td className="end">{l.debit ? <Money value={l.debit} /> : '—'}</td>
                  <td className="end">{l.credit ? <Money value={l.credit} /> : '—'}</td>
                </tr>
              )),
            )}
          </tbody>
        </table>
      )}
    </Card>
  );
}

function OverviewReport({ db, index, filter }: Ctx) {
  const tree = accountOverview(db.entries, index, filter);
  const render = (nodes: AccountOverviewNode[], depth = 0): React.ReactNode =>
    nodes
      .filter((n) => n.debit !== 0 || n.credit !== 0)
      .map((n) => (
        <React.Fragment key={n.accountId}>
          <tr>
            <td>
              <span className="tree-indent" style={{ width: depth * 18 }} />
              <span className="num muted small">{n.code}</span> <span style={{ fontWeight: depth === 0 ? 600 : 400 }}>{n.name}</span>
            </td>
            <td className="end"><Money value={n.debit} /></td>
            <td className="end"><Money value={n.credit} /></td>
            <td className="end strong"><Money value={n.balance} sign /></td>
          </tr>
          {render(n.children, depth + 1)}
        </React.Fragment>
      ));

  return (
    <Card>
      <table>
        <thead>
          <tr><th>حساب</th><th className="end">گردش بدهکار</th><th className="end">گردش بستانکار</th><th className="end">مانده</th></tr>
        </thead>
        <tbody>{render(tree)}</tbody>
      </table>
    </Card>
  );
}

function CapitalReport({ db, index, filter }: Ctx) {
  const r = capitalStatement(db.entries, index, filter);
  return (
    <Card>
      <table>
        <tbody>
          <tr><td>سرمایهٔ اول دوره</td><td className="end"><Money value={r.opening} /></td></tr>
          <tr><td>سود (زیان) دوره</td><td className="end"><Money value={r.netProfit} sign /></td></tr>
          {r.drawings > 0 && <tr><td>برداشت شخصی</td><td className="end money-neg">(<Money value={r.drawings} />)</td></tr>}
          <tr className="report-total"><td>سرمایهٔ پایان دوره</td><td className="end"><Money value={r.closing} sign /></td></tr>
        </tbody>
      </table>
    </Card>
  );
}
