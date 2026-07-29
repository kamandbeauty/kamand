import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  computeInvoice, INVOICE_TYPE_LABELS, invoiceProfit, nextInvoiceNumber,
  paymentStatus, uuid, validateInvoice, formatMoney, moneyToWords, toPersianDigits,
  ACTION_LABELS, filterByPayment, paymentSummary,
  PAYMENT_FILTER_LABELS, type PaymentFilter,
  type Invoice, type InvoiceLine, type InvoiceType,
} from '@javid/core';
import {
  convertQuote, createReturnFor, invoiceTotal, isFullyReturned, paidOf,
  invoiceEditability, paymentInfoOf, postInvoiceToDB, recordHistory,
  recordInvoicePayment, returnedQtyOf, settlementOf, stockOf, voidInvoice, type DB,
} from '../store';
import { availableMethods, METHOD_LABELS, printReceipt, receiptFor, type PrintMethod } from '../printer';
import { attachHardwareScanner } from '../barcode';
import {
  Badge, Banner, Card, DateInput, Empty, Field, JDate, Modal,
  Money, MoneyInput, NumberInput, Search, Tabs,
} from '../ui';

const STATUS_TONE = {
  draft: 'gray', open: 'blue', partial: 'amber', paid: 'green', void: 'gray',
} as const;
const STATUS_LABEL = {
  draft: 'پیش‌نویس', open: 'باز', partial: 'پرداخت جزئی', paid: 'تسویه', void: 'باطل',
} as const;

export function Invoices({ db, setDB, canWrite }: {
  db: DB;
  setDB: (d: DB) => void;
  canWrite: boolean;
}) {
  const [tab, setTab] = useState<'all' | InvoiceType>('all');
  const [payFilter, setPayFilter] = useState<PaymentFilter>('all');
  const [q, setQ] = useState('');
  const [editing, setEditing] = useState<Invoice | null>(null);
  const [viewing, setViewing] = useState<Invoice | null>(null);
  const [returning, setReturning] = useState<Invoice | null>(null);
  const [settling, setSettling] = useState<Invoice | null>(null);
  const [deleting, setDeleting] = useState<Invoice | null>(null);
  const [notice, setNotice] = useState('');
  const [error, setError] = useState('');

  function convert(id: string) {
    try {
      const r = convertQuote(db, id);
      setDB(r.db);
      setNotice('پیش‌فاکتور به فاکتور فروش تبدیل شد');
      setError('');
    } catch (e) {
      setError((e as Error).message);
    }
  }

  const info = useMemo(() => (inv: Invoice) => paymentInfoOf(db, inv), [db]);
  const summary = useMemo(() => paymentSummary(db.invoices, info), [db.invoices, info]);

  const list = useMemo(() => {
    const term = q.trim().toLowerCase();
    const byPayment = filterByPayment(
      db.invoices.filter((i) => !i.deletedAt),
      payFilter,
      info,
    );
    return byPayment
      .filter((i) => tab === 'all' || i.type === tab)
      .filter((i) => {
        if (!term) return true;
        const party = db.parties.find((p) => p.id === i.partyId);
        return i.number.toLowerCase().includes(term) || (party?.name.toLowerCase().includes(term) ?? false);
      })
      .sort((a, b) => b.date.localeCompare(a.date) || b.createdAt.localeCompare(a.createdAt));
  }, [db.invoices, db.parties, tab, q, payFilter, info]);

  function newInvoice(type: InvoiceType) {
    const prefix = { sale: 'F', purchase: 'P', quote: 'Q', sale_return: 'RS', purchase_return: 'RP', waste: 'W' }[type];
    const number = nextInvoiceNumber(db.invoices.filter((i) => i.type === type).map((i) => i.number), prefix);
    setEditing({
      id: uuid(),
      businessId: db.business.id,
      type,
      number,
      // ⚠️ قبلاً اولین شخص فهرست خودکار انتخاب می‌شد — یعنی فروش به
      // اشتباه به نام کسی ثبت می‌شد که مغازه‌دار انتخابش نکرده بود.
      partyId: null,
      date: new Date().toISOString().slice(0, 10),
      // فروش و خرید پیش‌فرض نقدی است؛ حالت رایج مغازه
      isCash: type === 'sale' || type === 'purchase',
      isOfficial: false,
      lines: [],
      discount: 0,
      shipping: 0,
      status: 'open',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    });
  }

  return (
    <>
      {summary.unpaidCount > 0 && (
        <div className="grid grid-2" style={{ marginBottom: 14 }}>
          <div className="card stat">
            <div className="label">تسویه‌نشده</div>
            <div className="value"><Money value={summary.unpaidAmount} /></div>
            <div className="sub">{toPersianDigits(summary.unpaidCount)} فاکتور</div>
          </div>
          <div className={`card stat ${summary.overdueCount > 0 ? 'neg' : ''}`}>
            <div className="label">سررسید گذشته</div>
            <div className="value"><Money value={summary.overdueAmount} /></div>
            <div className="sub">{toPersianDigits(summary.overdueCount)} فاکتور</div>
          </div>
        </div>
      )}

      <div className="toolbar no-print">
        <Search value={q} onChange={setQ} placeholder="جستجوی شماره یا طرف حساب…" />
        <select
          className="select"
          style={{ maxWidth: 160 }}
          value={payFilter}
          onChange={(e) => setPayFilter(e.target.value as PaymentFilter)}
          aria-label="فیلتر وضعیت پرداخت"
        >
          {(Object.keys(PAYMENT_FILTER_LABELS) as PaymentFilter[]).map((f) => (
            <option key={f} value={f}>{PAYMENT_FILTER_LABELS[f]}</option>
          ))}
        </select>
        <div style={{ flex: 1 }} />
        {canWrite && (
          <>
            <button className="btn" onClick={() => newInvoice('quote')}>پیش‌فاکتور</button>
            <button className="btn" onClick={() => newInvoice('purchase')}>+ خرید</button>
            <button className="btn btn-primary" onClick={() => newInvoice('sale')}>+ فاکتور فروش</button>
          </>
        )}
      </div>

      {notice && <Banner tone="success" action={<button className="btn btn-sm" onClick={() => setNotice('')}>بستن</button>}>{notice}</Banner>}
      {error && <Banner tone="critical" action={<button className="btn btn-sm" onClick={() => setError('')}>بستن</button>}>{error}</Banner>}

      <Tabs
        active={tab}
        onChange={setTab}
        tabs={[
          { id: 'all' as const, label: 'همه' },
          { id: 'sale' as const, label: 'فروش' },
          { id: 'purchase' as const, label: 'خرید' },
          { id: 'quote' as const, label: 'پیش‌فاکتور' },
          { id: 'sale_return' as const, label: 'برگشت از فروش' },
          { id: 'waste' as const, label: 'ضایعات' },
        ]}
      />

      <Card>
        {list.length === 0 ? (
          <Empty
            icon="🧾"
            text="فاکتوری یافت نشد"
            action={canWrite && <button className="btn btn-primary" onClick={() => newInvoice('sale')}>ثبت فاکتور فروش</button>}
          />
        ) : (
          <table>
            <thead>
              <tr>
                <th>شماره</th>
                <th>نوع</th>
                <th>طرف حساب</th>
                <th>تاریخ</th>
                <th className="end">مبلغ کل</th>
                <th className="end">مانده</th>
                <th className="center">وضعیت</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {list.map((inv) => {
                const total = invoiceTotal(inv);
                const paid = paidOf(db, inv.id);
                const status = inv.type === 'quote' ? 'draft' : paymentStatus(total, paid);
                return (
                  <tr key={inv.id}>
                    <td className="num strong">{inv.number}</td>
                    <td className="small">
                      {INVOICE_TYPE_LABELS[inv.type]}
                      {inv.isOfficial && <> <Badge tone="blue">رسمی</Badge></>}
                    </td>
                    <td>{db.parties.find((p) => p.id === inv.partyId)?.name ?? <span className="muted">—</span>}</td>
                    <td><JDate value={inv.date} /></td>
                    <td className="end"><Money value={total} /></td>
                    <td className="end">
                      {total - paid > 0 ? <Money value={total - paid} sign /> : <span className="muted">۰</span>}
                    </td>
                    <td className="center"><Badge tone={STATUS_TONE[status]}>{STATUS_LABEL[status]}</Badge></td>
                    <td className="end no-print">
                      <button className="btn btn-sm btn-ghost" onClick={() => setViewing(inv)}>مشاهده</button>
                      {canWrite && inv.type === 'quote' && (
                        <button className="btn btn-sm" onClick={() => convert(inv.id)}>تبدیل به فاکتور</button>
                      )}
                      {canWrite && inv.type !== 'quote' && total - paid > 0 && (
                        <button className="btn btn-sm" onClick={() => setSettling(inv)}>تسویه</button>
                      )}
                      {canWrite && (() => {
                        const e = invoiceEditability(db, inv.id);
                        return e.ok ? (
                          <>
                            <button className="btn btn-sm btn-ghost" onClick={() => setEditing(inv)}>ویرایش</button>
                            <button className="btn btn-sm btn-ghost" onClick={() => setDeleting(inv)}>حذف</button>
                          </>
                        ) : null;
                      })()}
                      {canWrite && (inv.type === 'sale' || inv.type === 'purchase')
                        && !isFullyReturned(db, inv.id) && (
                        <button className="btn btn-sm btn-ghost" onClick={() => setReturning(inv)}>برگشت</button>
                      )}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </Card>

      {editing && (
        <InvoiceEditor
          db={db}
          invoice={editing}
          onClose={() => setEditing(null)}
          onSave={(inv) => {
            setDB(postInvoiceToDB(db, inv));
            setEditing(null);
          }}
        />
      )}

      {viewing && <InvoiceView db={db} invoice={viewing} onClose={() => setViewing(null)} />}

      {deleting && (
        <Modal
          title={`حذف فاکتور ${deleting.number}`}
          onClose={() => setDeleting(null)}
          footer={
            <>
              <button
                className="btn btn-danger"
                onClick={() => {
                  try {
                    setDB(voidInvoice(db, deleting.id));
                    setDeleting(null);
                    setNotice('فاکتور حذف شد');
                    setError('');
                  } catch (e) {
                    setError((e as Error).message);
                    setDeleting(null);
                  }
                }}
              >تأیید حذف</button>
              <button className="btn" onClick={() => setDeleting(null)}>انصراف</button>
            </>
          }
        >
          <Banner tone="warning" title="اثر این فاکتور از دفتر برداشته می‌شود">
            سند حسابداری و حرکت انبار مربوط به این فاکتور حذف می‌شود.
            خود فاکتور برای ردّ ممیزی باقی می‌ماند.
          </Banner>
        </Modal>
      )}

      {settling && (
        <SettleDialog
          db={db}
          invoice={settling}
          onClose={() => setSettling(null)}
          onSubmit={(input) => {
            try {
              setDB(recordInvoicePayment(db, { ...input, invoiceId: settling.id }));
              setSettling(null);
              setNotice('پرداخت ثبت شد');
              setError('');
            } catch (e) {
              setError((e as Error).message);
              setSettling(null);
            }
          }}
        />
      )}

      {returning && (
        <ReturnDialog
          db={db}
          source={returning}
          onClose={() => setReturning(null)}
          onSubmit={(qtys) => {
            try {
              const r = createReturnFor(db, returning.id, qtys);
              setDB(r.db);
              setReturning(null);
              setNotice('فاکتور برگشتی ثبت شد');
              setError('');
            } catch (e) {
              setError((e as Error).message);
              setReturning(null);
            }
          }}
        />
      )}
    </>
  );
}

// ─────────── ویرایشگر فاکتور ───────────

function InvoiceEditor({ db, invoice, onClose, onSave }: {
  db: DB;
  invoice: Invoice;
  onClose: () => void;
  onSave: (inv: Invoice) => void;
}) {
  const [inv, setInv] = useState<Invoice>(invoice);
  const [errors, setErrors] = useState<string[]>([]);
  const [scanned, setScanned] = useState<string>('');
  const totals = computeInvoice(inv);
  const isSale = inv.type === 'sale' || inv.type === 'quote' || inv.type === 'sale_return';

  // اسکنر سخت‌افزاری: بارکد را می‌خواند و کالا را به فاکتور اضافه می‌کند
  const invRef = useRef(inv);
  invRef.current = inv;

  useEffect(() => {
    return attachHardwareScanner({
      onScan: (code) => {
        const p = db.products.find((x) => x.barcode === code && !x.archived);
        if (!p) {
          setScanned(`کالایی با بارکد ${code} یافت نشد`);
          setTimeout(() => setScanned(''), 3000);
          return;
        }
        const cur = invRef.current;
        const existing = cur.lines.find((l) => l.productId === p.id);
        if (existing) {
          setInv({
            ...cur,
            lines: cur.lines.map((l) => (l.id === existing.id ? { ...l, qty: l.qty + 1 } : l)),
          });
        } else {
          setInv({
            ...cur,
            lines: [...cur.lines, {
              id: uuid(), productId: p.id, qty: 1, unit: p.unitMain,
              unitPrice: cur.type === 'purchase' ? p.buyPrice : p.sellPrice,
              discount: 0,
              vatRate: cur.isOfficial ? (p.vatRate ?? db.business.defaultVatRate) : 0,
            }],
          });
        }
        setScanned(`${p.name} افزوده شد`);
        setTimeout(() => setScanned(''), 2000);
      },
    });
  }, [db.products, db.business.defaultVatRate]);

  function addLine(productId?: string) {
    const p = db.products.find((x) => x.id === productId) ?? db.products[0];
    if (!p) return;
    const line: InvoiceLine = {
      id: uuid(),
      productId: p.id,
      qty: 1,
      unit: p.unitMain,
      unitPrice: isSale ? p.sellPrice : p.buyPrice,
      discount: 0,
      vatRate: inv.isOfficial ? (p.vatRate ?? db.business.defaultVatRate) : 0,
    };
    setInv({ ...inv, lines: [...inv.lines, line] });
  }

  function patchLine(id: string, patch: Partial<InvoiceLine>) {
    setInv({ ...inv, lines: inv.lines.map((l) => (l.id === id ? { ...l, ...patch } : l)) });
  }

  function save() {
    const errs = validateInvoice(inv);
    setErrors(errs);
    if (errs.length === 0) onSave({ ...inv, updatedAt: new Date().toISOString() });
  }

  return (
    <Modal
      wide
      title={`${INVOICE_TYPE_LABELS[inv.type]} ${inv.number}`}
      onClose={onClose}
      footer={
        <>
          <button className="btn btn-primary" onClick={save}>ثبت فاکتور</button>
          <button className="btn" onClick={onClose}>انصراف</button>
          <div style={{ flex: 1 }} />
          <div style={{ textAlign: 'end' }}>
            <div className="small muted">مبلغ قابل پرداخت</div>
            <div style={{ fontSize: 18, fontWeight: 700 }}><Money value={totals.grandTotal} /></div>
          </div>
        </>
      }
    >
      {errors.length > 0 && (
        <Banner tone="critical" title="فاکتور قابل ثبت نیست">
          <ul style={{ paddingInlineStart: 18, margin: 0 }}>
            {errors.map((e, i) => <li key={i}>{e}</li>)}
          </ul>
        </Banner>
      )}

      {db.products.length === 0 && (
        <Banner tone="warning">ابتدا از بخش «کالاها» حداقل یک کالا تعریف کنید.</Banner>
      )}

      {scanned && <Banner tone={scanned.includes('یافت نشد') ? 'warning' : 'success'}>{scanned}</Banner>}

      <div className="small muted" style={{ marginBottom: 10 }}>
        📷 بارکدخوان فعال است — کافی است بارکد کالا را اسکن کنید.
      </div>

      {/* نقدی یا نسیه — نخستین تصمیم هر فروش سرِ پیشخوان */}
      {(inv.type === 'sale' || inv.type === 'purchase') && (
        <div className="row" style={{ marginBottom: 12 }}>
          <Field label="نحوهٔ پرداخت">
            <div style={{ display: 'flex', gap: 8 }}>
              <button
                type="button"
                className={`btn ${inv.isCash !== false ? 'btn-primary' : ''}`}
                onClick={() => setInv({ ...inv, isCash: true })}
              >
                💵 نقدی
              </button>
              <button
                type="button"
                className={`btn ${inv.isCash === false ? 'btn-primary' : ''}`}
                onClick={() => setInv({ ...inv, isCash: false })}
              >
                📝 نسیه
              </button>
            </div>
          </Field>
          {inv.isCash !== false && db.treasuries.filter((t) => !t.archived).length > 1 && (
            <Field label="به صندوق">
              <select
                className="select"
                value={inv.treasuryId ?? ''}
                onChange={(e) => setInv({ ...inv, treasuryId: e.target.value || null })}
              >
                <option value="">صندوق اصلی</option>
                {db.treasuries.filter((t) => !t.archived).map((t) => (
                  <option key={t.id} value={t.id}>{t.name}</option>
                ))}
              </select>
            </Field>
          )}
        </div>
      )}

      <div className="row">
        <Field label={inv.isCash !== false ? 'طرف حساب (اختیاری)' : 'طرف حساب'}>
          <select
            className="select"
            value={inv.partyId ?? ''}
            onChange={(e) => setInv({ ...inv, partyId: e.target.value || null })}
          >
            <option value="">
              {inv.isCash !== false ? '— مشتری عابر —' : '— انتخاب کنید —'}
            </option>
            {db.parties.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
          </select>
        </Field>
        <Field label="تاریخ">
          <DateInput value={inv.date} onChange={(d) => setInv({ ...inv, date: d })} />
        </Field>
        {inv.isCash === false && (
          <Field label="سررسید">
            <DateInput value={inv.dueDate ?? ''} onChange={(d) => setInv({ ...inv, dueDate: d })} />
          </Field>
        )}
      </div>

      <label style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 14 }}>
        <input
          type="checkbox"
          checked={inv.isOfficial}
          onChange={(e) => {
            const on = e.target.checked;
            setInv({
              ...inv,
              isOfficial: on,
              lines: inv.lines.map((l) => ({
                ...l,
                vatRate: on ? (db.products.find((p) => p.id === l.productId)?.vatRate ?? db.business.defaultVatRate) : 0,
              })),
            });
          }}
        />
        <span>فاکتور رسمی (با مالیات بر ارزش افزوده)</span>
      </label>

      <div className="card" style={{ marginBottom: 16 }}>
        <table>
          <thead>
            <tr>
              <th style={{ width: '32%' }}>کالا / خدمت</th>
              <th style={{ width: 90 }}>مقدار</th>
              <th style={{ width: 130 }}>قیمت واحد</th>
              <th style={{ width: 120 }}>تخفیف</th>
              {inv.isOfficial && <th style={{ width: 70 }}>مالیات</th>}
              <th className="end">جمع</th>
              <th style={{ width: 40 }}></th>
            </tr>
          </thead>
          <tbody>
            {inv.lines.map((l, i) => {
              const p = db.products.find((x) => x.id === l.productId);
              const stock = p && p.kind === 'goods' ? stockOf(db, p.id).qty : null;
              return (
                <tr key={l.id}>
                  <td>
                    <select
                      className="select"
                      value={l.productId}
                      onChange={(e) => {
                        const np = db.products.find((x) => x.id === e.target.value);
                        patchLine(l.id, {
                          productId: e.target.value,
                          unit: np?.unitMain ?? l.unit,
                          unitPrice: np ? (isSale ? np.sellPrice : np.buyPrice) : l.unitPrice,
                        });
                      }}
                    >
                      {db.products.map((x) => <option key={x.id} value={x.id}>{x.name}</option>)}
                    </select>
                    {stock !== null && (
                      <div className="small muted">موجودی: <span className="num">{stock}</span> {p?.unitMain}</div>
                    )}
                  </td>
                  <td><NumberInput value={l.qty} onChange={(v) => patchLine(l.id, { qty: v })} /></td>
                  <td><MoneyInput value={l.unitPrice} onChange={(v) => patchLine(l.id, { unitPrice: v })} /></td>
                  <td><MoneyInput value={l.discount} onChange={(v) => patchLine(l.id, { discount: v })} /></td>
                  {inv.isOfficial && (
                    <td><NumberInput value={l.vatRate} onChange={(v) => patchLine(l.id, { vatRate: v })} /></td>
                  )}
                  <td className="end"><Money value={totals.lines[i]?.total ?? 0} /></td>
                  <td>
                    <button
                      className="btn btn-sm btn-ghost"
                      onClick={() => setInv({ ...inv, lines: inv.lines.filter((x) => x.id !== l.id) })}
                    >✕</button>
                  </td>
                </tr>
              );
            })}
            {inv.lines.length === 0 && (
              <tr><td colSpan={7} className="center muted" style={{ padding: 24 }}>ردیفی اضافه نشده است</td></tr>
            )}
          </tbody>
        </table>
        <div style={{ padding: 12 }}>
          <button className="btn btn-sm" onClick={() => addLine()} disabled={db.products.length === 0}>
            + افزودن ردیف
          </button>
        </div>
      </div>

      <div className="row">
        <div>
          <Field label="تخفیف کلی">
            <MoneyInput value={inv.discount} onChange={(v) => setInv({ ...inv, discount: v })} />
          </Field>
          <Field label="هزینهٔ حمل">
            <MoneyInput value={inv.shipping} onChange={(v) => setInv({ ...inv, shipping: v })} />
          </Field>
          <Field label="توضیحات">
            <textarea
              className="input"
              rows={2}
              value={inv.note ?? ''}
              onChange={(e) => setInv({ ...inv, note: e.target.value })}
            />
          </Field>
        </div>

        <div>
          <table>
            <tbody>
              <tr><td>جمع کل</td><td className="end"><Money value={totals.subtotal} /></td></tr>
              {totals.totalDiscount > 0 && (
                <tr><td>تخفیف</td><td className="end money-neg"><Money value={totals.totalDiscount} /></td></tr>
              )}
              <tr><td>خالص</td><td className="end"><Money value={totals.net} /></td></tr>
              {totals.vat > 0 && (
                <tr><td>مالیات بر ارزش افزوده</td><td className="end"><Money value={totals.vat} /></td></tr>
              )}
              {totals.shipping > 0 && (
                <tr><td>هزینهٔ حمل</td><td className="end"><Money value={totals.shipping} /></td></tr>
              )}
              <tr className="report-total">
                <td>قابل پرداخت</td>
                <td className="end"><Money value={totals.grandTotal} /></td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </Modal>
  );
}

// ─────────── نمایش و چاپ فاکتور ───────────

function InvoiceView({ db, invoice, onClose }: { db: DB; invoice: Invoice; onClose: () => void }) {
  const [thermal, setThermal] = useState(false);
  const [history, setHistory] = useState(false);
  const t = computeInvoice(invoice);
  const party = db.parties.find((p) => p.id === invoice.partyId);
  const paid = paidOf(db, invoice.id);
  const profit = invoiceProfit(invoice);
  const unit = db.business.currencyUnit === 'toman' ? 'تومان' : 'ریال';

  return (
    <Modal
      wide
      title={`${INVOICE_TYPE_LABELS[invoice.type]} ${invoice.number}`}
      onClose={onClose}
      footer={
        <>
          <button className="btn btn-primary" onClick={() => window.print()}>🖨 چاپ A4</button>
          <button className="btn" onClick={() => setThermal(true)}>🧾 چاپ حرارتی</button>
          <button className="btn btn-ghost" onClick={() => setHistory(true)}>📜 تاریخچه</button>
          <button className="btn" onClick={onClose}>بستن</button>
        </>
      }
    >
      {thermal && <ThermalDialog db={db} invoiceId={invoice.id} onClose={() => setThermal(false)} />}
      {history && <HistoryDialog db={db} invoiceId={invoice.id} onClose={() => setHistory(false)} />}
      <div id="print-area">
        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 20 }}>
          <div>
            <div style={{ fontSize: 18, fontWeight: 700 }}>{db.business.name}</div>
            {db.business.address && <div className="small muted">{db.business.address}</div>}
            {db.business.phone && <div className="small muted num">{db.business.phone}</div>}
          </div>
          <div style={{ textAlign: 'end' }}>
            <div className="strong">{INVOICE_TYPE_LABELS[invoice.type]}</div>
            <div className="small">شماره: <span className="num">{invoice.number}</span></div>
            <div className="small">تاریخ: <JDate value={invoice.date} style="long" /></div>
            {invoice.isOfficial && <Badge tone="blue">رسمی</Badge>}
          </div>
        </div>

        {party && (
          <div className="card" style={{ padding: 12, marginBottom: 16 }}>
            <div className="small muted">طرف حساب</div>
            <div className="strong">{party.name}</div>
            {party.phone && <div className="small num">{party.phone}</div>}
            {party.address && <div className="small muted">{party.address}</div>}
          </div>
        )}

        <table style={{ marginBottom: 16 }}>
          <thead>
            <tr>
              <th style={{ width: 36 }}>#</th>
              <th>شرح</th>
              <th className="end">مقدار</th>
              <th className="end">قیمت واحد</th>
              <th className="end">تخفیف</th>
              <th className="end">جمع</th>
            </tr>
          </thead>
          <tbody>
            {invoice.lines.map((l, i) => (
              <tr key={l.id}>
                <td className="num">{i + 1}</td>
                <td>{db.products.find((p) => p.id === l.productId)?.name ?? '—'}</td>
                <td className="end num">{l.qty} {l.unit}</td>
                <td className="end"><Money value={l.unitPrice} /></td>
                <td className="end"><Money value={l.discount + (t.lines[i]?.allocatedDiscount ?? 0)} /></td>
                <td className="end"><Money value={t.lines[i]?.total ?? 0} /></td>
              </tr>
            ))}
          </tbody>
        </table>

        <div style={{ display: 'flex', gap: 20 }}>
          <div style={{ flex: 1 }}>
            <div className="small muted">مبلغ به حروف</div>
            <div style={{ fontWeight: 500 }}>{moneyToWords(t.grandTotal, unit)}</div>
            {invoice.note && (
              <div style={{ marginTop: 12 }}>
                <div className="small muted">توضیحات</div>
                <div className="small">{invoice.note}</div>
              </div>
            )}
          </div>
          <div style={{ minWidth: 260 }}>
            <table>
              <tbody>
                <tr><td>جمع</td><td className="end"><Money value={t.subtotal} /></td></tr>
                {t.totalDiscount > 0 && <tr><td>تخفیف</td><td className="end"><Money value={t.totalDiscount} /></td></tr>}
                {t.vat > 0 && <tr><td>مالیات</td><td className="end"><Money value={t.vat} /></td></tr>}
                {t.shipping > 0 && <tr><td>حمل</td><td className="end"><Money value={t.shipping} /></td></tr>}
                <tr className="report-total">
                  <td>قابل پرداخت</td>
                  <td className="end"><Money value={t.grandTotal} /></td>
                </tr>
                <tr><td>پرداخت‌شده</td><td className="end"><Money value={paid} /></td></tr>
                <tr><td className="strong">مانده</td><td className="end"><Money value={t.grandTotal - paid} sign /></td></tr>
              </tbody>
            </table>
          </div>
        </div>

        {invoice.type === 'sale' && (
          <div className="no-print" style={{ marginTop: 16 }}>
            <Badge tone={profit >= 0 ? 'green' : 'red'}>
              سود این فاکتور: {formatMoney(profit)} {unit}
            </Badge>
          </div>
        )}
      </div>
    </Modal>
  );
}


// ─────────── چاپ حرارتی ───────────

function ThermalDialog({ db, invoiceId, onClose }: {
  db: DB;
  invoiceId: string;
  onClose: () => void;
}) {
  const methods = availableMethods();
  const [method, setMethod] = useState<PrintMethod>(methods[0]!);
  const [width, setWidth] = useState<32 | 48>(48);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const preview = useMemo(() => {
    try {
      return receiptFor(db, invoiceId, { width, shapeArabic: false }).preview();
    } catch {
      return '';
    }
  }, [db, invoiceId, width]);

  async function doPrint() {
    setBusy(true);
    setError('');
    try {
      await printReceipt(db, invoiceId, method, { width });
      onClose();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal
      title="چاپ رسید حرارتی"
      onClose={onClose}
      footer={
        <>
          <button className="btn btn-primary" onClick={() => void doPrint()} disabled={busy}>
            {busy ? 'در حال ارسال…' : 'چاپ'}
          </button>
          <button className="btn" onClick={onClose}>انصراف</button>
        </>
      }
    >
      {error && <Banner tone="critical">{error}</Banner>}

      <div className="row">
        <Field label="روش چاپ">
          <select className="select" value={method} onChange={(e) => setMethod(e.target.value as PrintMethod)}>
            {methods.map((m) => <option key={m} value={m}>{METHOD_LABELS[m]}</option>)}
          </select>
        </Field>
        <Field label="عرض کاغذ">
          <select className="select" value={width} onChange={(e) => setWidth(Number(e.target.value) as 32 | 48)}>
            <option value={48}>۸۰ میلی‌متر</option>
            <option value={32}>۵۸ میلی‌متر</option>
          </select>
        </Field>
      </div>

      <Field label="پیش‌نمایش">
        <pre style={{
          background: 'var(--bg)', border: '1px solid var(--line)', borderRadius: 8,
          padding: 12, fontSize: 11, lineHeight: 1.5, overflowX: 'auto',
          fontFamily: 'monospace', direction: 'rtl', whiteSpace: 'pre',
        }}>{preview}</pre>
      </Field>
    </Modal>
  );
}


// ─────────── فاکتور برگشتی ───────────

/**
 * ساخت برگشت از روی فاکتور اصلی.
 *
 * مقدار قابل برگشت = مقدار فاکتور منهای آنچه قبلاً برگشت خورده.
 * این جلوی برگشت بیش از فروش را می‌گیرد.
 */
function ReturnDialog({ db, source, onClose, onSubmit }: {
  db: DB;
  source: Invoice;
  onClose: () => void;
  onSubmit: (qtys: Map<string, number>) => void;
}) {
  const alreadyReturned = useMemo(() => returnedQtyOf(db, source.id), [db, source.id]);

  const [qtys, setQtys] = useState<Map<string, number>>(() => {
    const m = new Map<string, number>();
    for (const l of source.lines) {
      m.set(l.id, Math.max(0, l.qty - (alreadyReturned.get(l.id) ?? 0)));
    }
    return m;
  });

  const totals = computeInvoice(source);
  const anySelected = [...qtys.values()].some((q) => q > 0);

  const refundTotal = source.lines.reduce((sum, l, i) => {
    const q = qtys.get(l.id) ?? 0;
    if (q <= 0 || l.qty === 0) return sum;
    return sum + Math.round(((totals.lines[i]?.total ?? 0) * q) / l.qty);
  }, 0);

  return (
    <Modal
      wide
      title={`برگشت از فاکتور ${source.number}`}
      onClose={onClose}
      footer={
        <>
          <button
            className="btn btn-primary"
            disabled={!anySelected}
            onClick={() => onSubmit(new Map([...qtys].filter(([, q]) => q > 0)))}
          >ثبت برگشت</button>
          <button className="btn" onClick={onClose}>انصراف</button>
          <div style={{ flex: 1 }} />
          <div style={{ textAlign: 'end' }}>
            <div className="small muted">مبلغ برگشتی</div>
            <div style={{ fontSize: 17, fontWeight: 700 }}><Money value={refundTotal} /></div>
          </div>
        </>
      }
    >
      <Banner tone="info">
        بهای تمام‌شدهٔ اصلی همراه برگشت منتقل می‌شود تا سود دوره درست
        محاسبه شود، حتی اگر قیمت خرید از زمان فروش تغییر کرده باشد.
      </Banner>

      <table>
        <thead>
          <tr>
            <th>کالا</th>
            <th className="end">فروخته</th>
            <th className="end">قبلاً برگشتی</th>
            <th style={{ width: 120 }}>مقدار برگشت</th>
            <th className="end">مبلغ</th>
          </tr>
        </thead>
        <tbody>
          {source.lines.map((l, i) => {
            const done = alreadyReturned.get(l.id) ?? 0;
            const max = Math.max(0, l.qty - done);
            const q = qtys.get(l.id) ?? 0;
            const amount = l.qty > 0 ? Math.round(((totals.lines[i]?.total ?? 0) * q) / l.qty) : 0;
            return (
              <tr key={l.id}>
                <td>{db.products.find((p) => p.id === l.productId)?.name ?? '—'}</td>
                <td className="end num">{toPersianDigits(l.qty)}</td>
                <td className="end num muted">{done ? toPersianDigits(done) : '—'}</td>
                <td>
                  <NumberInput
                    value={q}
                    disabled={max === 0}
                    onChange={(v) => {
                      const clamped = Math.min(Math.max(0, v), max);
                      setQtys((m) => new Map(m).set(l.id, clamped));
                    }}
                  />
                  {max === 0 && <div className="small muted">کاملاً برگشت خورده</div>}
                </td>
                <td className="end"><Money value={amount} /></td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </Modal>
  );
}


// ─────────── تاریخچهٔ فاکتور ───────────

/** «این فاکتور چه اتفاقی برایش افتاده؟» — از ردّ ممیزی */
function HistoryDialog({ db, invoiceId, onClose }: {
  db: DB;
  invoiceId: string;
  onClose: () => void;
}) {
  const logs = useMemo(() => recordHistory(db, 'invoice', invoiceId), [db, invoiceId]);

  return (
    <Modal
      title="تاریخچهٔ این فاکتور"
      onClose={onClose}
      footer={<button className="btn" onClick={onClose}>بستن</button>}
    >
      {logs.length === 0 ? (
        <div className="empty">
          <span className="ico">📜</span>
          <p>رویدادی برای این فاکتور ثبت نشده است</p>
        </div>
      ) : (
        <table>
          <thead>
            <tr><th>زمان</th><th>رویداد</th><th>تغییرات</th></tr>
          </thead>
          <tbody>
            {logs.map((l) => {
              const changes = l.action === 'update'
                ? (l.before as { field: string }[] | undefined)
                : undefined;
              return (
                <tr key={l.id}>
                  <td><JDate value={l.at} /></td>
                  <td>
                    <Badge tone={l.action === 'create' ? 'green' : l.action === 'delete' ? 'red' : 'blue'}>
                      {ACTION_LABELS[l.action]}
                    </Badge>
                  </td>
                  <td className="small muted">
                    {changes?.length
                      ? changes.map((c) => c.field).join('، ')
                      : '—'}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      )}
    </Modal>
  );
}


// ─────────── تسویهٔ فاکتور ───────────

/**
 * ثبت پرداخت روی فاکتور.
 *
 * تراکنش با شناسهٔ فاکتور ثبت می‌شود تا وضعیت پرداخت بروز شود —
 * چیزی که پیش‌تر از صفحهٔ خزانه ممکن نبود.
 */
function SettleDialog({ db, invoice, onClose, onSubmit }: {
  db: DB;
  invoice: Invoice;
  onClose: () => void;
  onSubmit: (input: {
    amount: number; treasuryId: string; date: string; method: 'cash' | 'bank' | 'cheque';
  }) => void;
}) {
  const s = useMemo(() => settlementOf(db, invoice.id), [db, invoice.id]);

  const [amount, setAmount] = useState(s.remaining);
  const [treasuryId, setTreasuryId] = useState(db.treasuries[0]?.id ?? '');
  const [date, setDate] = useState(new Date().toISOString().slice(0, 10));
  const [method, setMethod] = useState<'cash' | 'bank' | 'cheque'>('cash');

  const outgoing = invoice.type === 'purchase' || invoice.type === 'sale_return';
  const tooMuch = amount > s.remaining;

  return (
    <Modal
      title={`تسویهٔ فاکتور ${invoice.number}`}
      onClose={onClose}
      footer={
        <>
          <button
            className="btn btn-primary"
            disabled={amount <= 0 || tooMuch || !treasuryId}
            onClick={() => onSubmit({ amount, treasuryId, date, method })}
          >{outgoing ? 'ثبت پرداخت' : 'ثبت دریافت'}</button>
          <button className="btn" onClick={onClose}>انصراف</button>
        </>
      }
    >
      <table style={{ marginBottom: 14 }}>
        <tbody>
          <tr><td>مبلغ فاکتور</td><td className="end"><Money value={s.total} /></td></tr>
          <tr><td>پرداخت‌شده</td><td className="end"><Money value={s.paid} /></td></tr>
          <tr className="report-total">
            <td>مانده</td>
            <td className="end"><Money value={s.remaining} sign /></td>
          </tr>
        </tbody>
      </table>

      <div className="row">
        <Field label="مبلغ">
          <MoneyInput value={amount} onChange={setAmount} />
        </Field>
        <Field label="تاریخ">
          <DateInput value={date} onChange={setDate} />
        </Field>
      </div>

      {tooMuch && (
        <Banner tone="critical">مبلغ از مانده فاکتور بیشتر است.</Banner>
      )}

      <div className="row">
        <Field label="حساب">
          <select className="select" value={treasuryId} onChange={(e) => setTreasuryId(e.target.value)}>
            {db.treasuries.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
          </select>
        </Field>
        <Field label="روش">
          <select className="select" value={method} onChange={(e) => setMethod(e.target.value as 'cash')}>
            <option value="cash">نقدی</option>
            <option value="bank">بانکی</option>
            <option value="cheque">چک</option>
          </select>
        </Field>
      </div>

      {s.payments.length > 0 && (
        <>
          <div className="small strong" style={{ marginTop: 10, marginBottom: 6 }}>پرداخت‌های قبلی</div>
          <table>
            <tbody>
              {s.payments.map((p) => (
                <tr key={p.id}>
                  <td><JDate value={p.date} /></td>
                  <td className="small muted">{p.description}</td>
                  <td className="end"><Money value={p.amount} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}
    </Modal>
  );
}
