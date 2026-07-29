import React, { useMemo, useState } from 'react';
import {
  computeInvoice, INVOICE_SUBJECTS, isValidMemoryId, MEMORY_ID_ALPHABET, SUBJECT_LABELS,
  SUBMISSION_LABELS, TAX_API_BASE, TAX_SPEC_VERSION, taxQuarter, toCSV,
  toPersianDigits, validateTaxId, validateTransportConfig, vatReport,
  type TaxProfile,
} from '@javid/core';
import {
  canCorrect, correctionsOf, issueCorrection, issueElectronicInvoice,
  submissionFor, taxReadiness, updateTaxProfile, type DB,
} from '../store';
import {
  Badge, Banner, Card, DateInput, Empty, Field, JDate,
  Modal, Money, Search, Tabs, download,
} from '../ui';

const fa = (n: number) => toPersianDigits(n);

const STATUS_TONE = {
  draft: 'gray', queued: 'amber', sent: 'blue',
  accepted: 'green', rejected: 'red', cancelled: 'gray',
} as const;

export function Tax({ db, setDB, canWrite }: {
  db: DB;
  setDB: (d: DB) => void;
  canWrite: boolean;
}) {
  const [tab, setTab] = useState<'invoices' | 'report' | 'settings'>('invoices');
  const configured = isValidMemoryId(db.taxProfile.memoryId) && !!db.taxProfile.sellerTin.trim();

  return (
    <>
      {!configured && (
        <Banner tone="warning" title="سامانهٔ مؤدیان هنوز پیکربندی نشده است">
          برای صدور صورتحساب الکترونیکی، شناسهٔ یکتای حافظهٔ مالیاتی و شمارهٔ اقتصادی
          را در زبانهٔ «تنظیمات مالیاتی» وارد کنید.
        </Banner>
      )}

      <Tabs
        active={tab}
        onChange={setTab}
        tabs={[
          { id: 'invoices' as const, label: 'صورتحساب‌ها' },
          { id: 'report' as const, label: 'گزارش دوره' },
          { id: 'settings' as const, label: 'تنظیمات مالیاتی' },
        ]}
      />

      {tab === 'invoices' && <TaxInvoices db={db} setDB={setDB} canWrite={canWrite && configured} />}
      {tab === 'report' && <VatReport db={db} />}
      {tab === 'settings' && <TaxSettings db={db} setDB={setDB} canWrite={canWrite} />}
    </>
  );
}

// ─────────── فهرست صورتحساب‌ها ───────────

function TaxInvoices({ db, setDB, canWrite }: { db: DB; setDB: (d: DB) => void; canWrite: boolean }) {
  const [q, setQ] = useState('');
  const [detail, setDetail] = useState<string | null>(null);
  const [error, setError] = useState<string[] | null>(null);

  const rows = useMemo(() => {
    const term = q.trim().toLowerCase();
    return db.invoices
      .filter((i) => !i.deletedAt && i.isOfficial && i.type === 'sale')
      .filter((i) => {
        if (!term) return true;
        const party = db.parties.find((p) => p.id === i.partyId);
        return i.number.toLowerCase().includes(term) || (party?.name.toLowerCase().includes(term) ?? false);
      })
      .sort((a, b) => b.date.localeCompare(a.date));
  }, [db.invoices, db.parties, q]);

  function issue(invoiceId: string) {
    const inv = db.invoices.find((i) => i.id === invoiceId);
    if (!inv) return;
    const issues = taxReadiness(db, inv);
    if (issues.length > 0) return setError(issues);
    try {
      const { db: next } = issueElectronicInvoice(db, inv);
      setDB(next);
      setError(null);
    } catch (e) {
      setError([(e as Error).message]);
    }
  }

  const pending = rows.filter((i) => !submissionFor(db, i.id)).length;

  return (
    <>
      <div className="toolbar no-print">
        <Search value={q} onChange={setQ} placeholder="جستجوی شماره یا خریدار…" />
        <div style={{ flex: 1 }} />
        {pending > 0 && <Badge tone="amber">{fa(pending)} صورتحساب ارسال‌نشده</Badge>}
      </div>

      {error && (
        <Banner tone="critical" title="صورتحساب قابل صدور نیست" action={
          <button className="btn btn-sm" onClick={() => setError(null)}>بستن</button>
        }>
          <ul style={{ paddingInlineStart: 18, margin: 0 }}>
            {error.map((e, i) => <li key={i}>{e}</li>)}
          </ul>
        </Banner>
      )}

      <Card>
        {rows.length === 0 ? (
          <Empty
            icon="🧾"
            text="فاکتور رسمی‌ای برای ارسال به سامانه وجود ندارد"
          />
        ) : (
          <table>
            <thead>
              <tr>
                <th>شماره فاکتور</th>
                <th>خریدار</th>
                <th>تاریخ</th>
                <th className="end">مبلغ کل</th>
                <th>شمارهٔ مالیاتی</th>
                <th className="center">وضعیت</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {rows.map((inv) => {
                const sub = submissionFor(db, inv.id);
                const issues = taxReadiness(db, inv);
                const total = computeInvoice(inv).grandTotal;
                return (
                  <tr key={inv.id}>
                    <td className="num strong">{inv.number}</td>
                    <td>{db.parties.find((p) => p.id === inv.partyId)?.name ?? <span className="muted">—</span>}</td>
                    <td><JDate value={inv.date} /></td>
                    <td className="end"><Money value={total} /></td>
                    <td className="num small" style={{ direction: 'ltr', textAlign: 'start' }}>
                      {sub ? sub.taxId : <span className="muted">—</span>}
                    </td>
                    <td className="center">
                      {sub ? (
                        <Badge tone={STATUS_TONE[sub.status]}>{SUBMISSION_LABELS[sub.status]}</Badge>
                      ) : issues.length > 0 ? (
                        <Badge tone="red">ناقص</Badge>
                      ) : (
                        <Badge tone="gray">صادر نشده</Badge>
                      )}
                    </td>
                    <td className="end no-print">
                      {sub ? (
                        <button className="btn btn-sm btn-ghost" onClick={() => setDetail(sub.id)}>جزئیات</button>
                      ) : canWrite ? (
                        <button
                          className="btn btn-sm"
                          onClick={() => issue(inv.id)}
                          disabled={issues.length > 0}
                          title={issues.join('؛ ')}
                        >صدور</button>
                      ) : null}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </Card>

      {detail && (
        <SubmissionDetail
          db={db}
          id={detail}
          onClose={() => setDetail(null)}
          onCorrect={canWrite ? (subject) => {
            try {
              const r = issueCorrection(db, detail, subject);
              setDB(r.db);
              setDetail(r.submission.id);
              setError(null);
            } catch (e) {
              setError([(e as Error).message]);
              setDetail(null);
            }
          } : undefined}
        />
      )}
    </>
  );
}

function SubmissionDetail({ db, id, onClose, onCorrect }: {
  db: DB;
  id: string;
  onClose: () => void;
  onCorrect?: (subject: 2 | 3 | 4) => void;
}) {
  const sub = db.taxSubmissions.find((s) => s.id === id);
  if (!sub) return null;
  const inv = db.invoices.find((i) => i.id === sub.invoiceId);
  const valid = validateTaxId(sub.taxId);
  const correctable = canCorrect(db, id);
  const corrections = correctionsOf(db, id);

  return (
    <Modal
      title="جزئیات صورتحساب الکترونیکی"
      onClose={onClose}
      footer={
        <>
          {onCorrect && correctable.ok && (
            <>
              <button className="btn" onClick={() => onCorrect(INVOICE_SUBJECTS.CORRECTIVE)}>
                صدور اصلاحیه
              </button>
              <button className="btn btn-danger" onClick={() => onCorrect(INVOICE_SUBJECTS.CANCELLING)}>
                ابطال
              </button>
            </>
          )}
          <button className="btn" onClick={onClose}>بستن</button>
        </>
      }
    >
      <table>
        <tbody>
          <tr>
            <td>شمارهٔ منحصربه‌فرد مالیاتی</td>
            <td className="end num" style={{ direction: 'ltr' }}>{sub.taxId}</td>
          </tr>
          <tr>
            <td>رقم کنترلی</td>
            <td className="end">
              <Badge tone={valid ? 'green' : 'red'}>{valid ? '✓ معتبر' : '✕ نامعتبر'}</Badge>
            </td>
          </tr>
          <tr><td>شمارهٔ فاکتور</td><td className="end num">{inv?.number ?? '—'}</td></tr>
          <tr><td>موضوع</td><td className="end">{SUBJECT_LABELS[sub.subject]}</td></tr>
          <tr><td>نوع</td><td className="end">صورتحساب نوع {sub.subjectType === 1 ? 'اول' : 'دوم'}</td></tr>
          <tr><td>سریال</td><td className="end num">{fa(sub.serial)}</td></tr>
          <tr>
            <td>وضعیت</td>
            <td className="end"><Badge tone={STATUS_TONE[sub.status]}>{SUBMISSION_LABELS[sub.status]}</Badge></td>
          </tr>
          <tr><td>تاریخ صدور</td><td className="end"><JDate value={sub.createdAt} style="long" /></td></tr>
          {sub.referencedTaxId && (
            <tr>
              <td>ارجاع به</td>
              <td className="end num" style={{ direction: 'ltr' }}>{sub.referencedTaxId}</td>
            </tr>
          )}
        </tbody>
      </table>

      {!correctable.ok && sub.status !== 'queued' && (
        <Banner tone="info">{correctable.reason}</Banner>
      )}

      {corrections.length > 0 && (
        <>
          <div className="small strong" style={{ marginTop: 14, marginBottom: 8 }}>
            صورتحساب‌های مرتبط
          </div>
          <table>
            <tbody>
              {corrections.map((c) => (
                <tr key={c.id}>
                  <td className="small">{SUBJECT_LABELS[c.subject]}</td>
                  <td className="num small" style={{ direction: 'ltr' }}>{c.taxId}</td>
                  <td className="end">
                    <Badge tone={STATUS_TONE[c.status]}>{SUBMISSION_LABELS[c.status]}</Badge>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}

      {sub.status === 'queued' && (
        <Banner tone="info">
          صورتحساب ساخته و در صف ارسال قرار گرفته است. ارسال به سامانهٔ مؤدیان
          هنگام برقراری اتصال انجام می‌شود.
        </Banner>
      )}

      {sub.errors && sub.errors.length > 0 && (
        <Banner tone="critical" title="خطاهای سامانه">
          <ul style={{ paddingInlineStart: 18, margin: 0 }}>
            {sub.errors.map((e, i) => <li key={i}><span className="num">{e.code}</span> — {e.message}</li>)}
          </ul>
        </Banner>
      )}
    </Modal>
  );
}

// ─────────── گزارش دوره ───────────

function VatReport({ db }: { db: DB }) {
  const q = taxQuarter(new Date());
  const [from, setFrom] = useState(q.from.toISOString().slice(0, 10));
  const [to, setTo] = useState(q.to.toISOString().slice(0, 10));

  const r = vatReport(db.invoices, db.taxSubmissions, { from, to, label: q.label });

  return (
    <>
      <div className="toolbar no-print">
        <label className="small muted">از</label>
        <div style={{ width: 130 }}><DateInput value={from} onChange={setFrom} /></div>
        <label className="small muted">تا</label>
        <div style={{ width: 130 }}><DateInput value={to} onChange={setTo} /></div>
        <button className="btn btn-sm" onClick={() => {
          setFrom(q.from.toISOString().slice(0, 10));
          setTo(q.to.toISOString().slice(0, 10));
        }}>{q.label}</button>
        <div style={{ flex: 1 }} />
        <button className="btn" onClick={() => {
          download('گزارش-ارزش-افزوده.csv', toCSV([r], [
            { key: 'salesNet', header: 'فروش خالص', value: (x) => x.salesNet },
            { key: 'salesVat', header: 'مالیات فروش', value: (x) => x.salesVat },
            { key: 'purchaseNet', header: 'خرید خالص', value: (x) => x.purchaseNet },
            { key: 'purchaseVat', header: 'اعتبار خرید', value: (x) => x.purchaseVat },
            { key: 'payable', header: 'قابل پرداخت', value: (x) => x.payable },
          ]), 'text/csv;charset=utf-8');
        }}>⬇ خروجی</button>
        <button className="btn" onClick={() => window.print()}>🖨 چاپ</button>
      </div>

      <div className="grid grid-3" style={{ marginBottom: 18 }}>
        <div className="card stat">
          <div className="label">مالیات فروش</div>
          <div className="value"><Money value={r.salesVat} /></div>
        </div>
        <div className="card stat">
          <div className="label">اعتبار مالیاتی خرید</div>
          <div className="value"><Money value={r.purchaseVat} /></div>
        </div>
        <div className={`card stat ${r.payable >= 0 ? 'neg' : 'pos'}`}>
          <div className="label">{r.payable >= 0 ? 'مالیات قابل پرداخت' : 'اعتبار قابل انتقال'}</div>
          <div className="value"><Money value={Math.abs(r.payable)} /></div>
        </div>
      </div>

      <Card title="جزئیات دوره">
        <table>
          <tbody>
            <tr><td>فروش خالص (رسمی)</td><td className="end"><Money value={r.salesNet} /></td></tr>
            <tr><td>مالیات بر ارزش افزودهٔ فروش</td><td className="end"><Money value={r.salesVat} /></td></tr>
            <tr><td>خرید خالص (رسمی)</td><td className="end"><Money value={r.purchaseNet} /></td></tr>
            <tr><td>مالیات بر ارزش افزودهٔ خرید</td><td className="end"><Money value={r.purchaseVat} /></td></tr>
            <tr className="report-total">
              <td>{r.payable >= 0 ? 'مالیات قابل پرداخت' : 'اعتبار قابل انتقال به دوره بعد'}</td>
              <td className="end"><Money value={Math.abs(r.payable)} /></td>
            </tr>
          </tbody>
        </table>
      </Card>

      <Card title="وضعیت ارسال">
        <table>
          <tbody>
            <tr><td>فاکتورهای فروش رسمی</td><td className="end num strong">{fa(r.invoiceCount)}</td></tr>
            <tr><td>ارسال‌شده به سامانه</td><td className="end num money-pos">{fa(r.submittedCount)}</td></tr>
            <tr>
              <td>در انتظار ارسال</td>
              <td className="end num" style={{ color: r.pendingCount > 0 ? 'var(--red)' : undefined }}>
                {fa(r.pendingCount)}
              </td>
            </tr>
          </tbody>
        </table>
        {r.pendingCount > 0 && (
          <Banner tone="warning">
            {fa(r.pendingCount)} فاکتور رسمی هنوز به سامانهٔ مؤدیان ارسال نشده است.
          </Banner>
        )}
      </Card>
    </>
  );
}

// ─────────── تنظیمات ───────────

function TaxSettings({ db, setDB, canWrite }: { db: DB; setDB: (d: DB) => void; canWrite: boolean }) {
  const [p, setP] = useState<TaxProfile>(db.taxProfile);
  const [saved, setSaved] = useState(false);
  const memoryOk = !p.memoryId || isValidMemoryId(p.memoryId);

  const missingCodes = db.products.filter((x) => !x.taxCode?.trim() && !x.archived);

  return (
    <div style={{ display: 'grid', gap: 18, maxWidth: 780 }}>
      <Card title="حافظهٔ مالیاتی" action={saved && <Badge tone="green">✓ ذخیره شد</Badge>}>
        <Field
          label="شناسهٔ یکتای حافظهٔ مالیاتی"
          hint="۶ کاراکتر، از کارپوشهٔ سامانهٔ مؤدیان دریافت می‌شود. حروف I, J, L, Q, V و رقم ۰ مجاز نیستند."
        >
          <input
            className="input num-input"
            style={{ direction: 'ltr', textAlign: 'start', letterSpacing: 2 }}
            maxLength={6}
            value={p.memoryId}
            aria-invalid={!memoryOk}
            onChange={(e) => {
              const v = e.target.value.toUpperCase();
              setP({ ...p, memoryId: [...v].filter((c) => MEMORY_ID_ALPHABET.includes(c)).join('') });
              setSaved(false);
            }}
            disabled={!canWrite}
          />
        </Field>
        {p.memoryId && !memoryOk && (
          <div className="small" style={{ color: 'var(--red)', marginTop: -8, marginBottom: 10 }}>
            شناسه باید دقیقاً ۶ کاراکتر باشد
          </div>
        )}

        <div className="row">
          <Field label="شمارهٔ اقتصادی فروشنده">
            <input
              className="input num-input"
              value={p.sellerTin}
              onChange={(e) => { setP({ ...p, sellerTin: e.target.value }); setSaved(false); }}
              disabled={!canWrite}
            />
          </Field>
          <Field label="نوع شخص">
            <select
              className="select"
              value={p.sellerType}
              onChange={(e) => { setP({ ...p, sellerType: Number(e.target.value) }); setSaved(false); }}
              disabled={!canWrite}
            >
              <option value={1}>حقیقی</option>
              <option value={2}>حقوقی</option>
              <option value={3}>مشارکت مدنی</option>
              <option value={4}>غیرایرانی</option>
            </select>
          </Field>
        </div>

        <table style={{ marginBottom: 14 }}>
          <tbody>
            <tr>
              <td>آخرین سریال مصرف‌شده</td>
              <td className="end num strong">{fa(p.lastSerial)}</td>
            </tr>
            <tr>
              <td>نسخهٔ دستورالعمل</td>
              <td className="end num">{TAX_SPEC_VERSION}</td>
            </tr>
          </tbody>
        </table>

        {canWrite && (
          <button
            className="btn btn-primary"
            disabled={!memoryOk}
            onClick={() => { setDB(updateTaxProfile(db, p)); setSaved(true); }}
          >ذخیرهٔ تنظیمات</button>
        )}
      </Card>

      {missingCodes.length > 0 && (
        <Card title="کالاهای بدون شناسهٔ مالیاتی">
          <Banner tone="warning">
            {fa(missingCodes.length)} کالا شناسهٔ کالا/خدمت ندارند و در صورتحساب
            الکترونیکی قابل استفاده نیستند. شناسه‌ها را از سامانهٔ مؤدیان دریافت
            و در بخش «کالاها» ثبت کنید.
          </Banner>
          <table>
            <tbody>
              {missingCodes.slice(0, 10).map((x) => (
                <tr key={x.id}><td>{x.name}</td><td className="end"><Badge tone="red">بدون شناسه</Badge></td></tr>
              ))}
            </tbody>
          </table>
        </Card>
      )}

      <Card title="ارسال به سامانه">
        <p className="small" style={{ marginBottom: 12 }}>
          صدور صورتحساب الکترونیکی و تولید شمارهٔ مالیاتی در جاوید کامل انجام
          می‌شود. برای <strong>ارسال واقعی</strong> به سامانه، سه مورد زیر لازم است
          که باید از مراجع رسمی دریافت شوند:
        </p>
        <table style={{ marginBottom: 12 }}>
          <tbody>
            <tr>
              <td>گواهی امضای دیجیتال</td>
              <td className="end small muted">از مرکز میانی معتبر (rca.gov.ir)</td>
            </tr>
            <tr>
              <td>کلید عمومی سازمان</td>
              <td className="end small muted">متد GET_SERVER_INFORMATION</td>
            </tr>
            <tr>
              <td>نام کاربری و رمز کارپوشه</td>
              <td className="end small muted">از کارپوشهٔ سامانهٔ مؤدیان</td>
            </tr>
          </tbody>
        </table>
        <Banner tone="info">
          لایهٔ فنی ارسال — نرمال‌سازی، امضای RSA-۲۰۴۸، رمزگذاری AES-GCM و
          استعلام وضعیت — پیاده و آزمون شده است. پس از دریافت گواهی، فقط
          کافی است آن را در سرور بارگذاری کنید.
        </Banner>
        <div className="small muted">
          نشانی سامانه: <span className="num" style={{ direction: 'ltr' }}>{TAX_API_BASE}</span>
        </div>
      </Card>

      <Card title="دربارهٔ سامانهٔ مؤدیان">
        <p className="small" style={{ marginBottom: 10 }}>
          طبق قانون پایانه‌های فروشگاهی، مؤدیان مشمول باید صورتحساب الکترونیکی
          دارای شمارهٔ منحصربه‌فرد مالیاتی صادر و به سامانه ارسال کنند.
        </p>
        <p className="small muted">
          شمارهٔ منحصربه‌فرد مالیاتی ۲۲ کاراکتری است و از چهار بخش تشکیل می‌شود:
          شناسهٔ حافظه (۶)، تاریخ ثبت (۵)، سریال صورتحساب (۱۰) و رقم کنترلی (۱)
          که با الگوریتم Verhoeff تولید می‌شود.
        </p>
        <Banner tone="info">
          الگوها و اقلام اطلاعاتی صورتحساب توسط سازمان امور مالیاتی بروزرسانی
          می‌شوند. پیش از بهره‌برداری عملیاتی، آخرین دستورالعمل را از
          intamedia.ir بررسی کنید.
        </Banner>
      </Card>
    </div>
  );
}
