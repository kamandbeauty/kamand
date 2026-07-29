import React, { useMemo, useState } from 'react';
import {
  computeInvoice, INVOICE_TYPE_LABELS, invoiceProfit, nextInvoiceNumber,
  paymentStatus, uuid, validateInvoice, formatMoney, moneyToWords,
  type Invoice, type InvoiceLine, type InvoiceType,
} from '@javid/core';
import { invoiceTotal, paidOf, postInvoiceToDB, stockOf, type DB } from '../store';
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
  const [q, setQ] = useState('');
  const [editing, setEditing] = useState<Invoice | null>(null);
  const [viewing, setViewing] = useState<Invoice | null>(null);

  const list = useMemo(() => {
    const term = q.trim().toLowerCase();
    return db.invoices
      .filter((i) => !i.deletedAt)
      .filter((i) => tab === 'all' || i.type === tab)
      .filter((i) => {
        if (!term) return true;
        const party = db.parties.find((p) => p.id === i.partyId);
        return i.number.toLowerCase().includes(term) || (party?.name.toLowerCase().includes(term) ?? false);
      })
      .sort((a, b) => b.date.localeCompare(a.date) || b.createdAt.localeCompare(a.createdAt));
  }, [db.invoices, db.parties, tab, q]);

  function newInvoice(type: InvoiceType) {
    const prefix = { sale: 'F', purchase: 'P', quote: 'Q', sale_return: 'RS', purchase_return: 'RP', waste: 'W' }[type];
    const number = nextInvoiceNumber(db.invoices.filter((i) => i.type === type).map((i) => i.number), prefix);
    setEditing({
      id: uuid(),
      businessId: db.business.id,
      type,
      number,
      partyId: db.parties[0]?.id ?? null,
      date: new Date().toISOString().slice(0, 10),
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
      <div className="toolbar no-print">
        <Search value={q} onChange={setQ} placeholder="جستجوی شماره یا طرف حساب…" />
        <div style={{ flex: 1 }} />
        {canWrite && (
          <>
            <button className="btn" onClick={() => newInvoice('quote')}>پیش‌فاکتور</button>
            <button className="btn" onClick={() => newInvoice('purchase')}>+ خرید</button>
            <button className="btn btn-primary" onClick={() => newInvoice('sale')}>+ فاکتور فروش</button>
          </>
        )}
      </div>

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
  const totals = computeInvoice(inv);
  const isSale = inv.type === 'sale' || inv.type === 'quote' || inv.type === 'sale_return';

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

      <div className="row">
        <Field label="طرف حساب">
          <select
            className="select"
            value={inv.partyId ?? ''}
            onChange={(e) => setInv({ ...inv, partyId: e.target.value || null })}
          >
            <option value="">— انتخاب کنید —</option>
            {db.parties.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
          </select>
        </Field>
        <Field label="تاریخ">
          <DateInput value={inv.date} onChange={(d) => setInv({ ...inv, date: d })} />
        </Field>
        <Field label="سررسید">
          <DateInput value={inv.dueDate ?? ''} onChange={(d) => setInv({ ...inv, dueDate: d })} />
        </Field>
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
          <button className="btn btn-primary" onClick={() => window.print()}>🖨 چاپ</button>
          <button className="btn" onClick={onClose}>بستن</button>
        </>
      }
    >
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
