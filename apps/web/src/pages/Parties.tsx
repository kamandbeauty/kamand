import React, { useMemo, useState } from 'react';
import {
  accountLedger, computeInvoice, debtorsAndCreditors, SYSTEM_ACCOUNTS as A,
  toCSV, uuid, type Party, type PartyKind,
} from '@javid/core';
import { indexOf, type DB } from '../store';
import { upsertParty } from '../store';
import { Badge, Card, Empty, Field, JDate, Modal, Money, MoneyInput, Search, Tabs, download } from '../ui';

const KIND_LABEL: Record<PartyKind, string> = {
  customer: 'مشتری', vendor: 'فروشنده', shareholder: 'سهامدار', employee: 'کارمند',
};

export function Parties({ db, setDB, canWrite }: {
  db: DB;
  setDB: (d: DB) => void;
  canWrite: boolean;
}) {
  const [tab, setTab] = useState<'all' | PartyKind>('all');
  const [q, setQ] = useState('');
  const [editing, setEditing] = useState<Party | null>(null);
  const [statement, setStatement] = useState<Party | null>(null);

  const index = indexOf(db);
  const dc = debtorsAndCreditors(db.entries, index, db.parties);
  const balances = new Map([...dc.debtors, ...dc.creditors].map((r) => [r.partyId, r.balance]));

  const list = useMemo(() => {
    const term = q.trim().toLowerCase();
    return db.parties
      .filter((p) => !p.archived)
      .filter((p) => tab === 'all' || p.kind === tab)
      .filter((p) => !term || p.name.toLowerCase().includes(term) || (p.phone ?? '').includes(term))
      .sort((a, b) => a.name.localeCompare(b.name, 'fa'));
  }, [db.parties, tab, q]);

  function blank(): Party {
    return {
      id: uuid(),
      businessId: db.business.id,
      kind: tab === 'all' ? 'customer' : tab,
      name: '',
      openingBalance: 0,
    };
  }

  function exportCSV() {
    const csv = toCSV(list, [
      { key: 'name', header: 'نام', value: (p) => p.name },
      { key: 'kind', header: 'نوع', value: (p) => KIND_LABEL[p.kind] },
      { key: 'phone', header: 'تلفن', value: (p) => p.phone ?? '' },
      { key: 'address', header: 'آدرس', value: (p) => p.address ?? '' },
      { key: 'balance', header: 'مانده', value: (p) => balances.get(p.id) ?? 0 },
    ]);
    download('اشخاص.csv', csv, 'text/csv;charset=utf-8');
  }

  return (
    <>
      <div className="toolbar no-print">
        <Search value={q} onChange={setQ} placeholder="جستجوی نام یا تلفن…" />
        <div style={{ flex: 1 }} />
        <button className="btn" onClick={exportCSV}>⬇ خروجی</button>
        {canWrite && <button className="btn btn-primary" onClick={() => setEditing(blank())}>+ شخص جدید</button>}
      </div>

      <div className="grid grid-3" style={{ marginBottom: 18 }}>
        <div className="card stat pos">
          <div className="label">جمع طلب ما</div>
          <div className="value"><Money value={dc.totalDebt} /></div>
        </div>
        <div className="card stat neg">
          <div className="label">جمع بدهی ما</div>
          <div className="value"><Money value={dc.totalCredit} /></div>
        </div>
        <div className="card stat">
          <div className="label">مانده خالص</div>
          <div className="value"><Money value={dc.net} sign /></div>
        </div>
      </div>

      <Tabs
        active={tab}
        onChange={setTab}
        tabs={[
          { id: 'all' as const, label: 'همه' },
          { id: 'customer' as const, label: 'مشتریان' },
          { id: 'vendor' as const, label: 'فروشندگان' },
          { id: 'shareholder' as const, label: 'سهامداران' },
        ]}
      />

      <Card>
        {list.length === 0 ? (
          <Empty
            icon="👥"
            text="شخصی ثبت نشده است"
            action={canWrite && <button className="btn btn-primary" onClick={() => setEditing(blank())}>افزودن شخص</button>}
          />
        ) : (
          <table>
            <thead>
              <tr>
                <th>نام</th>
                <th>نوع</th>
                <th>تلفن</th>
                <th className="end">مانده حساب</th>
                <th className="center">وضعیت</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {list.map((p) => {
                const bal = balances.get(p.id) ?? 0;
                return (
                  <tr key={p.id}>
                    <td className="strong">
                      {p.name}
                      {p.kind === 'shareholder' && p.sharePercent ? (
                        <span className="small muted"> · سهم <span className="num">{p.sharePercent}٪</span></span>
                      ) : null}
                    </td>
                    <td className="small">{KIND_LABEL[p.kind]}</td>
                    <td className="num small">{p.phone ?? '—'}</td>
                    <td className="end"><Money value={Math.abs(bal)} /></td>
                    <td className="center">
                      {bal > 0 ? <Badge tone="green">بدهکار</Badge>
                        : bal < 0 ? <Badge tone="red">بستانکار</Badge>
                        : <Badge tone="gray">تسویه</Badge>}
                    </td>
                    <td className="end no-print">
                      <button className="btn btn-sm btn-ghost" onClick={() => setStatement(p)}>صورتحساب</button>
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
        <PartyEditor
          party={editing}
          onClose={() => setEditing(null)}
          onSave={(p) => {
            setDB(upsertParty(db, p));
            setEditing(null);
          }}
        />
      )}

      {statement && <Statement db={db} party={statement} onClose={() => setStatement(null)} />}
    </>
  );
}

function PartyEditor({ party, onClose, onSave }: {
  party: Party;
  onClose: () => void;
  onSave: (p: Party) => void;
}) {
  const [p, setP] = useState(party);
  const [err, setErr] = useState('');

  return (
    <Modal
      title={party.name ? `ویرایش ${party.name}` : 'شخص جدید'}
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
          <select className="select" value={p.kind} onChange={(e) => setP({ ...p, kind: e.target.value as PartyKind })}>
            {Object.entries(KIND_LABEL).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </select>
        </Field>
      </div>
      {err && <div className="small" style={{ color: 'var(--red)', marginTop: -8, marginBottom: 10 }}>{err}</div>}

      <div className="row">
        <Field label="تلفن">
          <input className="input num-input" value={p.phone ?? ''} onChange={(e) => setP({ ...p, phone: e.target.value })} />
        </Field>
        <Field label="کد ملی / شناسهٔ ملی">
          <input className="input num-input" value={p.nationalId ?? ''} onChange={(e) => setP({ ...p, nationalId: e.target.value })} />
        </Field>
      </div>

      <Field label="آدرس">
        <textarea className="input" rows={2} value={p.address ?? ''} onChange={(e) => setP({ ...p, address: e.target.value })} />
      </Field>

      <div className="row">
        <Field label="مانده اول دوره" hint="مثبت = او به ما بدهکار است">
          <MoneyInput value={p.openingBalance} onChange={(v) => setP({ ...p, openingBalance: v })} />
        </Field>
        {p.kind === 'shareholder' && (
          <Field label="درصد شراکت">
            <input
              className="input num-input"
              value={p.sharePercent ?? ''}
              onChange={(e) => setP({ ...p, sharePercent: Number(e.target.value) || 0 })}
            />
          </Field>
        )}
      </div>
    </Modal>
  );
}

function Statement({ db, party, onClose }: { db: DB; party: Party; onClose: () => void }) {
  const index = indexOf(db);
  const rows = [
    ...accountLedger(db.entries, index.id(A.RECEIVABLE), 0, { partyId: party.id }),
    ...accountLedger(db.entries, index.id(A.PAYABLE), 0, { partyId: party.id }),
  ].sort((a, b) => a.date.localeCompare(b.date));

  let running = 0;
  const withRunning = rows.map((r) => {
    running += r.debit - r.credit;
    return { ...r, running };
  });

  return (
    <Modal
      wide
      title={`صورتحساب ${party.name}`}
      onClose={onClose}
      footer={
        <>
          <button className="btn btn-primary" onClick={() => window.print()}>🖨 چاپ</button>
          <button className="btn" onClick={onClose}>بستن</button>
        </>
      }
    >
      {withRunning.length === 0 ? (
        <Empty icon="📄" text="تراکنشی برای این شخص ثبت نشده است" />
      ) : (
        <table>
          <thead>
            <tr>
              <th>تاریخ</th>
              <th>شرح</th>
              <th className="end">بدهکار</th>
              <th className="end">بستانکار</th>
              <th className="end">مانده</th>
            </tr>
          </thead>
          <tbody>
            {withRunning.map((r, i) => (
              <tr key={i}>
                <td><JDate value={r.date} /></td>
                <td>{r.description}</td>
                <td className="end">{r.debit ? <Money value={r.debit} /> : '—'}</td>
                <td className="end">{r.credit ? <Money value={r.credit} /> : '—'}</td>
                <td className="end"><Money value={r.running} sign /></td>
              </tr>
            ))}
            <tr className="report-total">
              <td colSpan={4}>مانده نهایی</td>
              <td className="end"><Money value={running} sign /></td>
            </tr>
          </tbody>
        </table>
      )}
    </Modal>
  );
}
