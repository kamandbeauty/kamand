import React, { useMemo, useState } from 'react';
import { formatMoney, kardex, stockByProduct, toCSV, toPersianDigits, uuid, type Product, type ProductKind } from '@javid/core';

const fa = (n: number) => toPersianDigits(n);
import {
  can, postStockCount, stockCountPreview, unpostedOpeningStock,
  upsertProduct, type DB, type StockCountLine,
} from '../store';
import { Badge, Banner, Card, Empty, Field, JDate, Modal, Money, MoneyInput, NumberInput, Search, Tabs, download } from '../ui';

export function Products({ db, setDB, canWrite }: {
  db: DB;
  setDB: (d: DB) => void;
  canWrite: boolean;
}) {
  const [tab, setTab] = useState<'all' | ProductKind>('all');
  const [q, setQ] = useState('');
  const [editing, setEditing] = useState<Product | null>(null);
  const [viewing, setViewing] = useState<Product | null>(null);
  const [counting, setCounting] = useState(false);
  const [countError, setCountError] = useState('');

  const stock = stockByProduct(db.movements, db.business.costingMethod, { allowNegative: true });

  const list = useMemo(() => {
    const term = q.trim().toLowerCase();
    return db.products
      .filter((p) => !p.archived)
      .filter((p) => tab === 'all' || p.kind === tab)
      .filter((p) => !term || p.name.toLowerCase().includes(term) || (p.barcode ?? '').includes(term))
      .sort((a, b) => a.name.localeCompare(b.name, 'fa'));
  }, [db.products, tab, q]);

  const totalValue = list.reduce((s, p) => s + (stock.get(p.id)?.value ?? 0), 0);

  function blank(): Product {
    return {
      id: uuid(),
      businessId: db.business.id,
      kind: 'goods',
      name: '',
      unitMain: 'عدد',
      buyPrice: 0,
      sellPrice: 0,
      openingQty: 0,
      openingCost: 0,
      vatRate: db.business.defaultVatRate,
    };
  }

  function exportCSV() {
    const csv = toCSV(list, [
      { key: 'name', header: 'نام', value: (p) => p.name },
      { key: 'barcode', header: 'بارکد', value: (p) => p.barcode ?? '' },
      { key: 'unit', header: 'واحد', value: (p) => p.unitMain },
      { key: 'buy', header: 'قیمت خرید', value: (p) => p.buyPrice },
      { key: 'sell', header: 'قیمت فروش', value: (p) => p.sellPrice },
      { key: 'qty', header: 'موجودی', value: (p) => stock.get(p.id)?.qty ?? 0 },
      { key: 'value', header: 'ارزش موجودی', value: (p) => stock.get(p.id)?.value ?? 0 },
    ]);
    download('کالاها.csv', csv, 'text/csv;charset=utf-8');
  }

  return (
    <>
      {(() => {
        const pending = unpostedOpeningStock(db);
        if (pending.length === 0) return null;
        const total = pending.reduce((s2, x) => s2 + x.value, 0);
        return (
          <Banner tone="warning" title="موجودی اولیه هنوز در دفتر ثبت نشده">
            {fa(pending.length)} کالا با موجودی اولیه به ارزش <Money value={total} /> دارید
            که سند حسابداری‌شان ثبت نشده است. از بخش «دفتر و اسناد ← مانده‌های اول دوره»
            سند افتتاحیه را ثبت کنید تا حساب موجودی کالا درست شود.
          </Banner>
        );
      })()}

      {countError && (
        <Banner tone="critical" action={<button className="btn btn-sm" onClick={() => setCountError('')}>بستن</button>}>
          {countError}
        </Banner>
      )}

      <div className="toolbar no-print">
        <Search value={q} onChange={setQ} placeholder="جستجوی نام یا بارکد…" />
        <div style={{ flex: 1 }} />
        {canWrite && (
          <button className="btn" onClick={() => setCounting(true)}>📋 انبارگردانی</button>
        )}
        <button className="btn" onClick={exportCSV}>⬇ خروجی</button>
        {canWrite && <button className="btn btn-primary" onClick={() => setEditing(blank())}>+ کالای جدید</button>}
      </div>

      <div className="grid grid-3" style={{ marginBottom: 18 }}>
        <div className="card stat">
          <div className="label">تعداد اقلام</div>
          <div className="value"><span className="num">{fa(list.length)}</span></div>
        </div>
        <div className="card stat">
          <div className="label">ارزش کل موجودی</div>
          <div className="value"><Money value={totalValue} /></div>
        </div>
        <div className="card stat">
          <div className="label">روش قیمت‌گذاری</div>
          <div className="value" style={{ fontSize: 17 }}>
            {{ fifo: 'فایفو (FIFO)', lifo: 'لایفو (LIFO)', weighted_average: 'میانگین موزون' }[db.business.costingMethod]}
          </div>
        </div>
      </div>

      <Tabs
        active={tab}
        onChange={setTab}
        tabs={[
          { id: 'all' as const, label: 'همه' },
          { id: 'goods' as const, label: 'کالا' },
          { id: 'service' as const, label: 'خدمات' },
        ]}
      />

      <Card>
        {list.length === 0 ? (
          <Empty
            icon="📦"
            text="کالایی ثبت نشده است"
            action={canWrite && <button className="btn btn-primary" onClick={() => setEditing(blank())}>افزودن کالا</button>}
          />
        ) : (
          <table>
            <thead>
              <tr>
                <th>نام</th>
                <th>بارکد</th>
                <th className="end">قیمت خرید</th>
                <th className="end">قیمت فروش</th>
                <th className="end">موجودی</th>
                <th className="end">ارزش</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {list.map((p) => {
                const s = stock.get(p.id);
                const qty = s?.qty ?? 0;
                const low = p.kind === 'goods' && p.minQty !== undefined && qty <= p.minQty;
                return (
                  <tr key={p.id}>
                    <td className="strong">
                      {p.name}
                      {p.kind === 'service' && <> <Badge tone="blue">خدمت</Badge></>}
                    </td>
                    <td className="num small muted">{p.barcode ?? '—'}</td>
                    <td className="end"><Money value={p.buyPrice} /></td>
                    <td className="end"><Money value={p.sellPrice} /></td>
                    <td className="end">
                      {p.kind === 'service' ? <span className="muted">—</span> : (
                        <>
                          <span className={`num ${qty < 0 ? 'money-neg' : low ? 'money-neg' : ''}`}>{fa(qty)}</span>
                          <span className="muted small"> {p.unitMain}</span>
                          {low && <div><Badge tone="amber">کم</Badge></div>}
                        </>
                      )}
                    </td>
                    <td className="end">{p.kind === 'service' ? '—' : <Money value={s?.value ?? 0} />}</td>
                    <td className="end no-print">
                      {p.kind === 'goods' && (
                        <button className="btn btn-sm btn-ghost" onClick={() => setViewing(p)}>کاردکس</button>
                      )}
                      {canWrite && <button className="btn btn-sm btn-ghost" onClick={() => setEditing(p)}>ویرایش</button>}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </Card>

      {editing && (
        <ProductEditor
          product={editing}
          isNew={!db.products.some((p) => p.id === editing.id)}
          onClose={() => setEditing(null)}
          onSave={(p) => {
            setDB(upsertProduct(db, p));
            setEditing(null);
          }}
        />
      )}

      {viewing && <Kardex db={db} product={viewing} onClose={() => setViewing(null)} />}

      {counting && (
        <StockCountDialog
          db={db}
          onClose={() => setCounting(false)}
          onSubmit={(lines) => {
            try {
              setDB(postStockCount(db, lines));
              setCounting(false);
              setCountError('');
            } catch (e) {
              setCountError((e as Error).message);
              setCounting(false);
            }
          }}
        />
      )}
    </>
  );
}

function ProductEditor({ product, isNew, onClose, onSave }: {
  product: Product;
  isNew: boolean;
  onClose: () => void;
  onSave: (p: Product) => void;
}) {
  const [p, setP] = useState(product);
  const [err, setErr] = useState('');

  return (
    <Modal
      title={isNew ? 'کالای جدید' : `ویرایش ${product.name}`}
      onClose={onClose}
      footer={
        <>
          <button
            className="btn btn-primary"
            onClick={() => {
              if (!p.name.trim()) return setErr('نام الزامی است');
              onSave({ ...p, name: p.name.trim() });
            }}
          >ذخیره</button>
          <button className="btn" onClick={onClose}>انصراف</button>
        </>
      }
    >
      <div className="row">
        <Field label="نام *">
          <input
            className="input"
            value={p.name}
            aria-invalid={!!err}
            onChange={(e) => { setP({ ...p, name: e.target.value }); setErr(''); }}
            autoFocus
          />
        </Field>
        <Field label="نوع">
          <select className="select" value={p.kind} onChange={(e) => setP({ ...p, kind: e.target.value as ProductKind })}>
            <option value="goods">کالا</option>
            <option value="service">خدمت</option>
          </select>
        </Field>
      </div>
      {err && <div className="small" style={{ color: 'var(--red)', marginTop: -8, marginBottom: 10 }}>{err}</div>}

      <div className="row">
        <Field label="بارکد">
          <input className="input num-input" value={p.barcode ?? ''} onChange={(e) => setP({ ...p, barcode: e.target.value })} />
        </Field>
        <Field label="واحد اصلی">
          <input className="input" value={p.unitMain} onChange={(e) => setP({ ...p, unitMain: e.target.value })} />
        </Field>
      </div>

      <div className="row">
        <Field label="واحد فرعی" hint="مثلاً کارتن">
          <input className="input" value={p.unitSub ?? ''} onChange={(e) => setP({ ...p, unitSub: e.target.value })} />
        </Field>
        <Field label="ضریب تبدیل" hint="چند واحد اصلی در یک فرعی">
          <NumberInput value={p.unitRatio ?? 0} onChange={(v) => setP({ ...p, unitRatio: v })} />
        </Field>
      </div>

      <Field label="شناسهٔ کالا/خدمت (سامانهٔ مؤدیان)" hint="برای صدور صورتحساب الکترونیکی الزامی است">
        <input
          className="input num-input"
          value={p.taxCode ?? ''}
          onChange={(e) => setP({ ...p, taxCode: e.target.value })}
        />
      </Field>

      <div className="row">
        <Field label="قیمت خرید">
          <MoneyInput value={p.buyPrice} onChange={(v) => setP({ ...p, buyPrice: v })} />
        </Field>
        <Field label="قیمت فروش">
          <MoneyInput value={p.sellPrice} onChange={(v) => setP({ ...p, sellPrice: v })} />
        </Field>
      </div>

      {p.kind === 'goods' && (
        <div className="row">
          <Field label="موجودی اولیه" hint={isNew ? '' : 'فقط هنگام ایجاد اعمال می‌شود'}>
            <NumberInput value={p.openingQty} onChange={(v) => setP({ ...p, openingQty: v })} disabled={!isNew} />
          </Field>
          <Field label="بهای واحد موجودی اولیه">
            <MoneyInput value={p.openingCost} onChange={(v) => setP({ ...p, openingCost: v })} disabled={!isNew} />
          </Field>
          <Field label="حداقل موجودی" hint="برای هشدار">
            <NumberInput value={p.minQty ?? 0} onChange={(v) => setP({ ...p, minQty: v })} />
          </Field>
        </div>
      )}
    </Modal>
  );
}

function Kardex({ db, product, onClose }: { db: DB; product: Product; onClose: () => void }) {
  const ms = db.movements.filter((m) => m.productId === product.id);
  const rows = kardex(ms, db.business.costingMethod);

  return (
    <Modal
      wide
      title={`کاردکس ${product.name}`}
      onClose={onClose}
      footer={<button className="btn" onClick={onClose}>بستن</button>}
    >
      {rows.length === 0 ? (
        <Empty icon="📦" text="حرکتی برای این کالا ثبت نشده است" />
      ) : (
        <table>
          <thead>
            <tr>
              <th>تاریخ</th>
              <th>منبع</th>
              <th className="end">ورود</th>
              <th className="end">خروج</th>
              <th className="end">بهای واحد</th>
              <th className="end">مانده</th>
              <th className="end">ارزش مانده</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r, i) => (
              <tr key={i}>
                <td><JDate value={r.date} /></td>
                <td className="small">
                  {{ invoice: 'فاکتور', opening: 'موجودی اولیه', adjustment: 'اصلاح' }[r.sourceType] ?? r.sourceType}
                </td>
                <td className="end">{r.inQty ? <span className="num money-pos">{fa(r.inQty)}</span> : '—'}</td>
                <td className="end">{r.outQty ? <span className="num money-neg">{fa(r.outQty)}</span> : '—'}</td>
                <td className="end"><Money value={r.unitCost} /></td>
                <td className="end num strong">{fa(r.balanceQty)}</td>
                <td className="end"><Money value={r.balanceValue} /></td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </Modal>
  );
}


// ─────────── انبارگردانی ───────────

/**
 * شمارش فیزیکی و اصلاح موجودی.
 *
 * کاربر موجودی واقعی هر کالا را وارد می‌کند؛ اختلاف با سیستم
 * محاسبه و به صورت کسری (ضایعات) یا اضافی (درآمد) ثبت می‌شود.
 */
function StockCountDialog({ db, onClose, onSubmit }: {
  db: DB;
  onClose: () => void;
  onSubmit: (lines: StockCountLine[]) => void;
}) {
  const stock = useMemo(
    () => stockByProduct(db.movements, db.business.costingMethod, { allowNegative: true }),
    [db.movements, db.business.costingMethod],
  );

  const goods = useMemo(
    () => db.products.filter((p) => p.kind === 'goods' && !p.archived),
    [db.products],
  );

  // پیش‌فرض: شمارش برابر سیستم، یعنی بدون اختلاف
  const [counted, setCounted] = useState<Map<string, number>>(
    () => new Map(goods.map((p) => [p.id, stock.get(p.id)?.qty ?? 0])),
  );

  const lines: StockCountLine[] = goods.map((p) => ({
    productId: p.id,
    counted: counted.get(p.id) ?? 0,
  }));

  const preview = stockCountPreview(db, lines);

  return (
    <Modal
      wide
      title="انبارگردانی — شمارش فیزیکی"
      onClose={onClose}
      footer={
        <>
          <button
            className="btn btn-primary"
            disabled={preview.rows.length === 0}
            onClick={() => onSubmit(lines)}
          >ثبت اصلاح موجودی</button>
          <button className="btn" onClick={onClose}>انصراف</button>
          <div style={{ flex: 1 }} />
          <div style={{ textAlign: 'end' }}>
            <div className="small muted">اثر مالی</div>
            <div className={`num strong ${preview.net >= 0 ? 'money-pos' : 'money-neg'}`}>
              {formatMoney(Math.abs(preview.net))}
            </div>
          </div>
        </>
      }
    >
      <Banner tone="info">
        موجودی واقعی هر کالا را وارد کنید. کسری به حساب ضایعات و
        اضافی به درآمد متفرقه ثبت می‌شود.
      </Banner>

      {preview.rows.length === 0 ? (
        <div className="small muted" style={{ marginBottom: 12 }}>
          هنوز اختلافی وارد نشده است.
        </div>
      ) : (
        <div className="grid grid-3" style={{ marginBottom: 14 }}>
          <div className="card stat">
            <div className="label">اقلام دارای اختلاف</div>
            <div className="value"><span className="num">{fa(preview.rows.length)}</span></div>
          </div>
          <div className="card stat pos">
            <div className="label">اضافی</div>
            <div className="value"><Money value={preview.surplus} /></div>
          </div>
          <div className="card stat neg">
            <div className="label">کسری</div>
            <div className="value"><Money value={preview.shortage} /></div>
          </div>
        </div>
      )}

      <table>
        <thead>
          <tr>
            <th>کالا</th>
            <th className="end">موجودی سیستم</th>
            <th style={{ width: 130 }}>شمارش فیزیکی</th>
            <th className="end">اختلاف</th>
            <th className="end">اثر مالی</th>
          </tr>
        </thead>
        <tbody>
          {goods.map((p) => {
            const system = stock.get(p.id)?.qty ?? 0;
            const c = counted.get(p.id) ?? 0;
            const diff = c - system;
            const row = preview.rows.find((r) => r.product.id === p.id);
            return (
              <tr key={p.id}>
                <td>{p.name}</td>
                <td className="end num">{fa(system)} <span className="muted small">{p.unitMain}</span></td>
                <td>
                  <NumberInput
                    value={c}
                    onChange={(v) => setCounted((m) => new Map(m).set(p.id, v))}
                  />
                </td>
                <td className={`end num ${diff > 0 ? 'money-pos' : diff < 0 ? 'money-neg' : 'muted'}`}>
                  {diff === 0 ? '—' : `${diff > 0 ? '+' : ''}${fa(diff)}`}
                </td>
                <td className="end">{row ? <Money value={Math.abs(row.value)} /> : '—'}</td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </Modal>
  );
}
