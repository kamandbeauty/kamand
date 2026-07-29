import React, { useMemo, useState } from 'react';
import {
  currentFiscalYear, integritySummary, toPersianDigits,
  type IntegrityIssue,
} from '@javid/core';
import { can, closedYears, closeYear, closingPreviewFor, integrityOf, type DB } from '../store';
import { Badge, Banner, Card, Empty, JDate, Modal, Money } from '../ui';

const fa = (n: number) => toPersianDigits(n);

/**
 * بستن سال مالی و بررسی سلامت دفتر.
 *
 * بستن سال عملیات پایانی هر دورهٔ حسابداری است: حساب‌های موقت صفر
 * می‌شوند، سود به سرمایه منتقل می‌گردد و دورهٔ بعد با مانده‌های
 * دائمی شروع می‌شود. بدون آن، سود سال گذشته با امسال قاطی می‌شود.
 */
export function YearEnd({ db, setDB }: { db: DB; setDB: (d: DB) => void }) {
  const thisYear = currentFiscalYear(new Date(), db.business.fiscalYearStartMonth);
  const [year, setYear] = useState(thisYear - 1);
  const [distribute, setDistribute] = useState(false);
  const [confirm, setConfirm] = useState(false);
  const [done, setDone] = useState<string | null>(null);
  const [error, setError] = useState('');

  const closed = closedYears(db);
  const { bounds, preview } = useMemo(
    () => closingPreviewFor(db, year),
    [db, year],
  );

  const issues = useMemo(() => integrityOf(db), [db]);
  const health = integritySummary(issues);
  const mayClose = can(db, 'period.lock');

  // چند سال اخیر برای انتخاب
  const years = Array.from({ length: 5 }, (_, i) => thisYear - i);

  function doClose() {
    try {
      setDB(closeYear(db, year, distribute));
      setDone(bounds.label);
      setConfirm(false);
      setError('');
    } catch (e) {
      setError((e as Error).message);
      setConfirm(false);
    }
  }

  return (
    <div style={{ display: 'grid', gap: 18, maxWidth: 860 }}>
      {done && (
        <Banner tone="success" title={`${done} بسته شد`}>
          حساب‌های موقت صفر شدند، سود به سرمایه منتقل شد و دورهٔ بعد با
          مانده‌های دائمی آغاز گردید. دوره خودکار قفل شد.
        </Banner>
      )}
      {error && <Banner tone="critical" title="بستن سال ناموفق بود">{error}</Banner>}

      <IntegrityCard issues={issues} health={health} />

      <Card title="انتخاب سال مالی">
        <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
          {years.map((y) => {
            const isClosed = closed.includes(y);
            return (
              <button
                key={y}
                className={`btn ${y === year ? 'btn-primary' : ''}`}
                onClick={() => { setYear(y); setDone(null); setError(''); }}
              >
                {fa(y)}
                {isClosed && ' ✓'}
              </button>
            );
          })}
        </div>
        <div className="small muted" style={{ marginTop: 10 }}>
          بازه: <JDate value={bounds.from} style="long" /> تا <JDate value={bounds.to} style="long" />
        </div>
      </Card>

      {preview.issues.length > 0 && (
        <Banner tone={preview.canClose ? 'warning' : 'critical'} title="پیش از بستن سال">
          <ul style={{ paddingInlineStart: 18, margin: 0 }}>
            {preview.issues.map((i, k) => <li key={k}>{i}</li>)}
          </ul>
        </Banner>
      )}

      <div className="grid grid-3">
        <div className="card stat">
          <div className="label">درآمد دوره</div>
          <div className="value"><Money value={preview.revenue} /></div>
        </div>
        <div className="card stat">
          <div className="label">هزینهٔ دوره</div>
          <div className="value"><Money value={preview.expenses} /></div>
        </div>
        <div className={`card stat ${preview.netProfit >= 0 ? 'pos' : 'neg'}`}>
          <div className="label">{preview.netProfit >= 0 ? 'سود خالص' : 'زیان خالص'}</div>
          <div className="value"><Money value={Math.abs(preview.netProfit)} /></div>
        </div>
      </div>

      <Card title={`حساب‌هایی که صفر می‌شوند (${fa(preview.temporaryAccounts.length)})`}>
        {preview.temporaryAccounts.length === 0 ? (
          <Empty icon="📗" text="حساب موقتی با مانده وجود ندارد" />
        ) : (
          <table>
            <thead>
              <tr><th>کد</th><th>نام حساب</th><th className="end">مانده</th></tr>
            </thead>
            <tbody>
              {preview.temporaryAccounts.map((a) => (
                <tr key={a.code}>
                  <td className="num muted small">{a.code}</td>
                  <td>{a.name}</td>
                  <td className="end"><Money value={a.balance} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>

      {preview.shareholderSplit.length > 0 && (
        <Card title="تسهیم سود بین سهامداران">
          <table style={{ marginBottom: 12 }}>
            <thead>
              <tr><th>سهامدار</th><th className="end">درصد</th><th className="end">سهم</th></tr>
            </thead>
            <tbody>
              {preview.shareholderSplit.map((s) => (
                <tr key={s.partyId}>
                  <td>{s.name}</td>
                  <td className="end num">{fa(s.percent)}٪</td>
                  <td className="end"><Money value={s.amount} /></td>
                </tr>
              ))}
              {preview.retained !== 0 && (
                <tr>
                  <td className="muted">باقی‌مانده در سود انباشته</td>
                  <td></td>
                  <td className="end"><Money value={preview.retained} /></td>
                </tr>
              )}
            </tbody>
          </table>
          <label style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <input
              type="checkbox"
              checked={distribute}
              onChange={(e) => setDistribute(e.target.checked)}
            />
            <span>سود بین سهامداران تسهیم شود</span>
          </label>
        </Card>
      )}

      <Card title="بستن سال">
        <p className="small muted" style={{ marginBottom: 12 }}>
          با بستن سال، سه سند ثبت می‌شود: <strong>اختتامیه</strong> (صفر کردن
          حساب‌های موقت)، در صورت انتخاب <strong>تسهیم سود</strong>، و
          <strong> افتتاحیهٔ سال بعد</strong>. سپس دوره خودکار قفل می‌گردد.
        </p>
        {!mayClose ? (
          <Banner tone="info">نقش شما اجازهٔ بستن سال مالی را ندارد.</Banner>
        ) : (
          <button
            className="btn btn-primary"
            disabled={!preview.canClose || !health.ok}
            onClick={() => setConfirm(true)}
            title={!health.ok ? 'ابتدا خطاهای دفتر را برطرف کنید' : ''}
          >
            🔒 بستن {bounds.label}
          </button>
        )}
        {!health.ok && mayClose && (
          <div className="small" style={{ color: 'var(--red)', marginTop: 8 }}>
            تا زمانی که دفتر خطای جدی دارد، بستن سال ممکن نیست.
          </div>
        )}
      </Card>

      {confirm && (
        <Modal
          title={`بستن ${bounds.label}`}
          onClose={() => setConfirm(false)}
          footer={
            <>
              <button className="btn btn-primary" onClick={doClose}>تأیید و بستن سال</button>
              <button className="btn" onClick={() => setConfirm(false)}>انصراف</button>
            </>
          }
        >
          <Banner tone="warning" title="این عملیات دوره را قفل می‌کند">
            پس از بستن سال، اسناد این دوره قابل ویرایش نخواهند بود. در صورت
            نیاز می‌توانید از بخش «ممیزی و دوره» قفل را با ذکر دلیل باز کنید.
          </Banner>
          <table>
            <tbody>
              <tr><td>سال مالی</td><td className="end strong">{bounds.label}</td></tr>
              <tr><td>سود دوره</td><td className="end"><Money value={preview.netProfit} sign /></td></tr>
              <tr>
                <td>حساب‌های صفرشونده</td>
                <td className="end num">{fa(preview.temporaryAccounts.length)}</td>
              </tr>
              <tr>
                <td>تسهیم سود</td>
                <td className="end">{distribute ? 'بله' : 'خیر'}</td>
              </tr>
            </tbody>
          </table>
        </Modal>
      )}
    </div>
  );
}

function IntegrityCard({
  issues, health,
}: {
  issues: IntegrityIssue[];
  health: ReturnType<typeof integritySummary>;
}) {
  const [open, setOpen] = useState(false);

  return (
    <Card
      title="سلامت دفتر"
      action={
        <Badge tone={health.ok ? (health.warnings > 0 ? 'amber' : 'green') : 'red'}>
          {health.message}
        </Badge>
      }
    >
      {issues.length === 0 ? (
        <div className="small muted">
          همهٔ اسناد متوازن‌اند، شناسه‌ای تکراری نیست و همهٔ ارجاع‌ها معتبرند.
        </div>
      ) : (
        <>
          <div style={{ display: 'flex', gap: 16, marginBottom: 10 }}>
            <span className="small">خطای جدی: <strong className="num">{fa(health.errors)}</strong></span>
            <span className="small">هشدار: <strong className="num">{fa(health.warnings)}</strong></span>
            <button className="btn btn-sm btn-ghost" onClick={() => setOpen((v) => !v)}>
              {open ? 'بستن' : 'مشاهدهٔ جزئیات'}
            </button>
          </div>
          {open && (
            <table>
              <tbody>
                {issues.slice(0, 50).map((i, k) => (
                  <tr key={k}>
                    <td style={{ width: 80 }}>
                      <Badge tone={i.severity === 'error' ? 'red' : 'amber'}>
                        {i.severity === 'error' ? 'خطا' : 'هشدار'}
                      </Badge>
                    </td>
                    <td className="small">{i.message}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </>
      )}
    </Card>
  );
}
