import React, { useMemo } from 'react';
import {
  dashboard, debtorsAndCreditors, fiscalYearRange, formatJalali,
  incomeStatement, stockByProduct, computeInvoice, INVOICE_TYPE_LABELS,
  toPersianDigits,
} from '@javid/core';
import {
  dismissSetup, healthOf, indexOf, isSetupDismissed, setupOf, type DB,
} from '../store';
import { Badge, Banner, Card, JDate, Money, Num, Stat, Empty } from '../ui';

const toFa = (n: number) => toPersianDigits(n);

export function Dashboard({ db, onNav }: { db: DB; onNav: (p: string) => void }) {
  const health = useMemo(() => healthOf(db), [db]);
  const setup = useMemo(() => setupOf(db), [db]);
  const [setupHidden, setSetupHidden] = React.useState(() => isSetupDismissed(db.business.id));
  const index = indexOf(db);
  const now = new Date();
  const today = now.toISOString().slice(0, 10);

  const monthStart = new Date(now);
  monthStart.setDate(1);
  const fy = fiscalYearRange(now, db.business.fiscalYearStartMonth);

  const overdue = db.cheques.filter(
    (c) => c.status === 'pending' && c.dueDate <= today,
  ).length;

  const d = dashboard(db.entries, index, {
    today,
    monthFrom: monthStart.toISOString().slice(0, 10),
    monthTo: today,
    overdueCheques: overdue,
  });

  const pl = incomeStatement(db.entries, index, {
    from: fy.from.toISOString().slice(0, 10),
    to: fy.to.toISOString().slice(0, 10),
  });

  const dc = debtorsAndCreditors(db.entries, index, db.parties);
  const stock = stockByProduct(db.movements, db.business.costingMethod, { allowNegative: true });

  const lowStock = db.products.filter((p) => {
    if (p.kind === 'service' || !p.minQty) return false;
    return (stock.get(p.id)?.qty ?? 0) <= p.minQty;
  });

  const recent = [...db.invoices]
    .filter((i) => !i.deletedAt)
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
    .slice(0, 6);

  const dueSoon = db.cheques
    .filter((c) => c.status === 'pending')
    .sort((a, b) => a.dueDate.localeCompare(b.dueDate))
    .slice(0, 5);

  return (
    <div style={{ display: 'grid', gap: 18 }}>
      {/* راهنمای روز اول — تا وقتی مراحل تمام نشده */}
      {!setup.finished && !setupHidden && (
        <Card
          title={`راه‌اندازی کسب‌وکار — ${toFa(setup.completed)} از ${toFa(setup.total)}`}
          action={
            <button className="btn btn-sm btn-ghost" onClick={() => {
              dismissSetup(db.business.id);
              setSetupHidden(true);
            }}>بستن راهنما</button>
          }
        >
          <div style={{
            height: 6, borderRadius: 3, background: 'var(--line)',
            marginBottom: 14, overflow: 'hidden',
          }}>
            <div style={{
              height: '100%', width: `${setup.percent}%`,
              background: 'var(--teal-500)', transition: 'width .3s',
            }} />
          </div>
          <table>
            <tbody>
              {setup.steps.map((st) => (
                <tr key={st.id}>
                  <td style={{ width: 32 }}>
                    {st.done
                      ? <span style={{ color: 'var(--green)' }}>✓</span>
                      : <span className="muted">○</span>}
                  </td>
                  <td>
                    <div className={st.done ? 'muted' : 'strong'}>{st.title}</div>
                    {!st.done && <div className="small muted">{st.detail}</div>}
                  </td>
                  <td className="end">
                    {!st.done && (
                      <button className="btn btn-sm" onClick={() => onNav(st.page)}>
                        {st.action}
                      </button>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      )}

      {/* هشدارهای کسب‌وکار */}
      {health.alerts.length > 0 && (
        <Card
          title="نیازمند رسیدگی"
          action={
            <Badge tone={health.critical > 0 ? 'red' : 'amber'}>{health.message}</Badge>
          }
        >
          <div style={{ display: 'grid', gap: 10 }}>
            {health.alerts.map((a) => (
              <Banner
                key={a.kind}
                tone={a.severity === 'critical' ? 'critical' : a.severity === 'warning' ? 'warning' : 'info'}
                title={a.title}
                action={
                  a.page ? (
                    <button className="btn btn-sm" onClick={() => onNav(a.page!)}>
                      {a.action ?? 'مشاهده'}
                    </button>
                  ) : undefined
                }
              >
                {a.detail}
                {a.amount !== undefined && a.amount > 0 && (
                  <> <strong><Money value={a.amount} /></strong></>
                )}
              </Banner>
            ))}
          </div>
        </Card>
      )}

      <div className="grid grid-4">
        <Stat label="فروش امروز" value={<Money value={d.todaySales} />} sub={formatJalali(now, 'long')} />
        <Stat label="فروش این ماه" value={<Money value={d.monthSales} />} />
        <Stat
          label="سود این ماه"
          value={<Money value={d.monthProfit} />}
          tone={d.monthProfit >= 0 ? 'pos' : 'neg'}
        />
        <Stat label="موجودی نقد و بانک" value={<Money value={d.cashBalance} />} />
      </div>

      <div className="grid grid-3">
        <Stat
          label="طلب از مشتریان"
          value={<Money value={dc.totalDebt} />}
          sub={`${toFa(dc.debtors.length)} نفر بدهکار`}
          tone="pos"
        />
        <Stat
          label="بدهی به فروشندگان"
          value={<Money value={dc.totalCredit} />}
          sub={`${toFa(dc.creditors.length)} نفر بستانکار`}
          tone="neg"
        />
        <Stat
          label={`سود ${fy.label}`}
          value={<Money value={pl.netProfit} />}
          tone={pl.netProfit >= 0 ? 'pos' : 'neg'}
        />
      </div>

      <div className="grid grid-2">
        <Card
          title="آخرین فاکتورها"
          action={<button className="btn btn-sm" onClick={() => onNav('invoices')}>همه</button>}
        >
          {recent.length === 0 ? (
            <Empty icon="🧾" text="هنوز فاکتوری ثبت نشده است" />
          ) : (
            <table>
              <thead>
                <tr>
                  <th>شماره</th>
                  <th>نوع</th>
                  <th>طرف حساب</th>
                  <th className="end">مبلغ</th>
                  <th>تاریخ</th>
                </tr>
              </thead>
              <tbody>
                {recent.map((inv) => {
                  const party = db.parties.find((p) => p.id === inv.partyId);
                  return (
                    <tr key={inv.id}>
                      <td className="num">{inv.number}</td>
                      <td className="small">{INVOICE_TYPE_LABELS[inv.type]}</td>
                      <td>{party?.name ?? <span className="muted">—</span>}</td>
                      <td className="end"><Money value={computeInvoice(inv).grandTotal} /></td>
                      <td><JDate value={inv.date} /></td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </Card>

        <div style={{ display: 'grid', gap: 18, alignContent: 'start' }}>
          <Card
            title="چک‌های نزدیک سررسید"
            action={<button className="btn btn-sm" onClick={() => onNav('cheques')}>همه</button>}
          >
            {dueSoon.length === 0 ? (
              <Empty icon="🧷" text="چکی در جریان نیست" />
            ) : (
              <table>
                <tbody>
                  {dueSoon.map((c) => {
                    const late = c.dueDate <= today;
                    return (
                      <tr key={c.id}>
                        <td>
                          <div>{c.bankName} <span className="num muted small">{c.number}</span></div>
                          <div className="small muted">
                            {c.direction === 'received' ? 'دریافتی' : 'پرداختی'}
                          </div>
                        </td>
                        <td className="end"><Money value={c.amount} /></td>
                        <td className="end">
                          <JDate value={c.dueDate} />
                          {late && <div><Badge tone="red">سررسید گذشته</Badge></div>}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            )}
          </Card>

          {lowStock.length > 0 && (
            <Card title="کالاهای رو به اتمام">
              <table>
                <tbody>
                  {lowStock.slice(0, 5).map((p) => (
                    <tr key={p.id}>
                      <td>{p.name}</td>
                      <td className="end">
                        <span className="num money-neg">{toFa(stock.get(p.id)?.qty ?? 0)}</span>
                        <span className="muted small"> {p.unitMain}</span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </Card>
          )}
        </div>
      </div>
    </div>
  );
}
