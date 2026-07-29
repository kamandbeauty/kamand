import React, { useState } from 'react';
import {
  balanceOf, defaultTreasuryAccount, postCheque, SYSTEM_ACCOUNTS as A,
  toPersianDigits, uuid, type Cheque, type ChequeDirection, type Transaction, type TransactionKind, type Treasury as T,
} from '@javid/core';

const fa = (n: number) => toPersianDigits(n);
import { indexOf, postTransactionToDB, upsertCheque, type DB } from '../store';
import { Badge, Banner, Card, DateInput, Empty, Field, JDate, Modal, Money, MoneyInput, Tabs } from '../ui';

export function Treasury({ db, setDB, canWrite }: {
  db: DB;
  setDB: (d: DB) => void;
  canWrite: boolean;
}) {
  const [tab, setTab] = useState<'accounts' | 'transactions' | 'cheques'>('accounts');
  const [txModal, setTxModal] = useState<TransactionKind | null>(null);
  const [chqModal, setChqModal] = useState<ChequeDirection | null>(null);

  const index = indexOf(db);
  const today = new Date().toISOString().slice(0, 10);

  const balances = db.treasuries.map((t) => {
    const code = t.kind === 'bank' ? A.BANK : t.kind === 'petty_cash' ? A.PETTY_CASH : A.CASH;
    // چند خزانه با یک حساب: مانده کل حساب را نشان می‌دهیم
    return { t, balance: balanceOf(db.entries, index.id(code)) };
  });

  const totalCash = balances.reduce((s, b) => s + b.balance, 0);

  return (
    <>
      <div className="toolbar no-print">
        {canWrite && (
          <>
            <button className="btn btn-primary" onClick={() => setTxModal('receive')}>+ دریافت</button>
            <button className="btn" onClick={() => setTxModal('pay')}>− پرداخت</button>
            <button className="btn" onClick={() => setTxModal('expense')}>هزینه</button>
            <button className="btn" onClick={() => setTxModal('transfer')}>انتقال</button>
            <div style={{ flex: 1 }} />
            <button className="btn" onClick={() => setChqModal('received')}>+ چک دریافتی</button>
            <button className="btn" onClick={() => setChqModal('issued')}>+ چک پرداختی</button>
          </>
        )}
      </div>

      <div className="grid grid-3" style={{ marginBottom: 18 }}>
        <div className="card stat">
          <div className="label">موجودی کل</div>
          <div className="value"><Money value={totalCash} /></div>
        </div>
        <div className="card stat">
          <div className="label">چک‌های در جریان</div>
          <div className="value">
            <span className="num">{fa(db.cheques.filter((c) => c.status === 'pending').length)}</span>
          </div>
        </div>
        <div className="card stat neg">
          <div className="label">چک‌های سررسید گذشته</div>
          <div className="value">
            <span className="num">{fa(db.cheques.filter((c) => c.status === 'pending' && c.dueDate <= today).length)}</span>
          </div>
        </div>
      </div>

      <Tabs
        active={tab}
        onChange={setTab}
        tabs={[
          { id: 'accounts' as const, label: 'حساب‌ها' },
          { id: 'transactions' as const, label: 'تراکنش‌ها' },
          { id: 'cheques' as const, label: 'چک‌ها' },
        ]}
      />

      {tab === 'accounts' && (
        <Card>
          <table>
            <thead><tr><th>نام</th><th>نوع</th><th>بانک</th><th className="end">مانده</th></tr></thead>
            <tbody>
              {balances.map(({ t, balance }) => (
                <tr key={t.id}>
                  <td className="strong">{t.name}</td>
                  <td className="small">
                    {{ bank: 'حساب بانکی', cash: 'صندوق', petty_cash: 'تنخواه‌گردان' }[t.kind]}
                  </td>
                  <td className="small muted">{t.bankName ?? '—'}</td>
                  <td className="end"><Money value={balance} sign /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      )}

      {tab === 'transactions' && (
        <Card>
          {db.transactions.length === 0 ? <Empty icon="💳" text="تراکنشی ثبت نشده است" /> : (
            <table>
              <thead>
                <tr><th>تاریخ</th><th>نوع</th><th>طرف حساب</th><th>حساب</th><th>شرح</th><th className="end">مبلغ</th></tr>
              </thead>
              <tbody>
                {[...db.transactions].reverse().map((t) => (
                  <tr key={t.id}>
                    <td><JDate value={t.date} /></td>
                    <td className="small">
                      <Badge tone={t.kind === 'receive' || t.kind === 'income' ? 'green' : t.kind === 'transfer' ? 'blue' : 'red'}>
                        {{ receive: 'دریافت', pay: 'پرداخت', transfer: 'انتقال', expense: 'هزینه', income: 'درآمد' }[t.kind]}
                      </Badge>
                    </td>
                    <td>{db.parties.find((p) => p.id === t.partyId)?.name ?? <span className="muted">—</span>}</td>
                    <td className="small">{db.treasuries.find((x) => x.id === t.treasuryId)?.name}</td>
                    <td className="small muted">{t.description ?? '—'}</td>
                    <td className="end"><Money value={t.amount} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </Card>
      )}

      {tab === 'cheques' && (
        <Card>
          {db.cheques.length === 0 ? <Empty icon="🧷" text="چکی ثبت نشده است" /> : (
            <table>
              <thead>
                <tr>
                  <th>شماره</th><th>نوع</th><th>بانک</th><th>طرف حساب</th>
                  <th>سررسید</th><th className="end">مبلغ</th><th className="center">وضعیت</th><th></th>
                </tr>
              </thead>
              <tbody>
                {db.cheques.map((c) => {
                  const late = c.status === 'pending' && c.dueDate <= today;
                  return (
                    <tr key={c.id}>
                      <td className="num">{c.number}</td>
                      <td className="small">{c.direction === 'received' ? 'دریافتی' : 'پرداختی'}</td>
                      <td className="small">{c.bankName}</td>
                      <td>{db.parties.find((p) => p.id === c.partyId)?.name ?? '—'}</td>
                      <td>
                        <JDate value={c.dueDate} />
                        {late && <div><Badge tone="red">گذشته</Badge></div>}
                      </td>
                      <td className="end"><Money value={c.amount} /></td>
                      <td className="center">
                        <Badge tone={
                          c.status === 'cashed' ? 'green' : c.status === 'bounced' ? 'red'
                            : c.status === 'pending' ? 'amber' : 'gray'
                        }>
                          {{ pending: 'در جریان', cashed: 'وصول شده', bounced: 'برگشتی', spent: 'خرج شده', void: 'باطل' }[c.status]}
                        </Badge>
                      </td>
                      <td className="end no-print">
                        {canWrite && c.status === 'pending' && (
                          <>
                            <button
                              className="btn btn-sm btn-ghost"
                              onClick={() => setDB(cashCheque(db, c, 'cash'))}
                            >وصول</button>
                            <button
                              className="btn btn-sm btn-ghost"
                              onClick={() => setDB(cashCheque(db, c, 'bounce'))}
                            >برگشت</button>
                          </>
                        )}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          )}
        </Card>
      )}

      {txModal && (
        <TxModal
          db={db}
          kind={txModal}
          onClose={() => setTxModal(null)}
          onSave={(tx) => {
            setDB(postTransactionToDB(db, tx));
            setTxModal(null);
          }}
        />
      )}

      {chqModal && (
        <ChequeModal
          db={db}
          direction={chqModal}
          onClose={() => setChqModal(null)}
          onSave={(c) => {
            setDB(registerCheque(db, c));
            setChqModal(null);
          }}
        />
      )}
    </>
  );
}

function ctxOf(db: DB) {
  const index = indexOf(db);
  return {
    index,
    businessId: db.business.id,
    idGen: uuid,
    now: new Date().toISOString(),
    treasuryAccount: defaultTreasuryAccount(index),
  };
}

function registerCheque(db: DB, c: Cheque): DB {
  const entry = postCheque(c, 'register', null, ctxOf(db));
  const next = upsertCheque(db, c);
  return { ...next, entries: entry ? [...next.entries, entry] : next.entries };
}

function cashCheque(db: DB, c: Cheque, event: 'cash' | 'bounce'): DB {
  const treasury = db.treasuries.find((t) => t.kind === 'bank') ?? db.treasuries[0] ?? null;
  const updated: Cheque = { ...c, status: event === 'cash' ? 'cashed' : 'bounced' };
  const entry = postCheque(c, event, treasury, ctxOf(db));
  const next = upsertCheque(db, updated);
  return { ...next, entries: entry ? [...next.entries, entry] : next.entries };
}

function TxModal({ db, kind, onClose, onSave }: {
  db: DB;
  kind: TransactionKind;
  onClose: () => void;
  onSave: (tx: Transaction) => void;
}) {
  const [tx, setTx] = useState<Transaction>({
    id: uuid(),
    businessId: db.business.id,
    kind,
    treasuryId: db.treasuries[0]?.id ?? '',
    partyId: null,
    amount: 0,
    date: new Date().toISOString().slice(0, 10),
    method: 'cash',
    createdAt: new Date().toISOString(),
  });
  const [err, setErr] = useState('');

  const title = { receive: 'دریافت وجه', pay: 'پرداخت وجه', transfer: 'انتقال بین حساب‌ها', expense: 'ثبت هزینه', income: 'ثبت درآمد' }[kind];

  return (
    <Modal
      title={title}
      onClose={onClose}
      footer={
        <>
          <button
            className="btn btn-primary"
            onClick={() => {
              if (tx.amount <= 0) return setErr('مبلغ باید بزرگ‌تر از صفر باشد');
              if (kind === 'transfer' && !tx.toTreasuryId) return setErr('حساب مقصد را انتخاب کنید');
              onSave(tx);
            }}
          >ثبت</button>
          <button className="btn" onClick={onClose}>انصراف</button>
        </>
      }
    >
      {err && <Banner tone="critical">{err}</Banner>}

      <div className="row">
        <Field label="مبلغ *">
          <MoneyInput value={tx.amount} onChange={(v) => { setTx({ ...tx, amount: v }); setErr(''); }} />
        </Field>
        <Field label="تاریخ">
          <DateInput value={tx.date} onChange={(d) => setTx({ ...tx, date: d })} />
        </Field>
      </div>

      <div className="row">
        <Field label={kind === 'transfer' ? 'از حساب' : 'حساب'}>
          <select className="select" value={tx.treasuryId} onChange={(e) => setTx({ ...tx, treasuryId: e.target.value })}>
            {db.treasuries.map((t) => <option key={t.id} value={t.id}>{t.name}</option>)}
          </select>
        </Field>
        {kind === 'transfer' ? (
          <Field label="به حساب">
            <select
              className="select"
              value={tx.toTreasuryId ?? ''}
              onChange={(e) => { setTx({ ...tx, toTreasuryId: e.target.value }); setErr(''); }}
            >
              <option value="">— انتخاب —</option>
              {db.treasuries.filter((t) => t.id !== tx.treasuryId).map((t) => (
                <option key={t.id} value={t.id}>{t.name}</option>
              ))}
            </select>
          </Field>
        ) : (
          <Field label="طرف حساب">
            <select className="select" value={tx.partyId ?? ''} onChange={(e) => setTx({ ...tx, partyId: e.target.value || null })}>
              <option value="">— بدون طرف حساب —</option>
              {db.parties.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
            </select>
          </Field>
        )}
      </div>

      <Field label="شرح">
        <input className="input" value={tx.description ?? ''} onChange={(e) => setTx({ ...tx, description: e.target.value })} />
      </Field>
    </Modal>
  );
}

function ChequeModal({ db, direction, onClose, onSave }: {
  db: DB;
  direction: ChequeDirection;
  onClose: () => void;
  onSave: (c: Cheque) => void;
}) {
  const [c, setC] = useState<Cheque>({
    id: uuid(),
    businessId: db.business.id,
    direction,
    number: '',
    bankName: '',
    amount: 0,
    dueDate: new Date().toISOString().slice(0, 10),
    partyId: db.parties[0]?.id ?? null,
    status: 'pending',
    createdAt: new Date().toISOString(),
  });
  const [err, setErr] = useState('');

  return (
    <Modal
      title={direction === 'received' ? 'ثبت چک دریافتی' : 'ثبت چک پرداختی'}
      onClose={onClose}
      footer={
        <>
          <button
            className="btn btn-primary"
            onClick={() => {
              if (!c.number.trim()) return setErr('شمارهٔ چک الزامی است');
              if (c.amount <= 0) return setErr('مبلغ باید بزرگ‌تر از صفر باشد');
              onSave(c);
            }}
          >ثبت</button>
          <button className="btn" onClick={onClose}>انصراف</button>
        </>
      }
    >
      {err && <Banner tone="critical">{err}</Banner>}

      <div className="row">
        <Field label="شمارهٔ چک *">
          <input className="input num-input" value={c.number} onChange={(e) => { setC({ ...c, number: e.target.value }); setErr(''); }} autoFocus />
        </Field>
        <Field label="بانک">
          <input className="input" value={c.bankName} onChange={(e) => setC({ ...c, bankName: e.target.value })} />
        </Field>
      </div>

      <div className="row">
        <Field label="مبلغ *">
          <MoneyInput value={c.amount} onChange={(v) => { setC({ ...c, amount: v }); setErr(''); }} />
        </Field>
        <Field label="تاریخ سررسید">
          <DateInput value={c.dueDate} onChange={(d) => setC({ ...c, dueDate: d })} />
        </Field>
      </div>

      <Field label="طرف حساب">
        <select className="select" value={c.partyId ?? ''} onChange={(e) => setC({ ...c, partyId: e.target.value || null })}>
          <option value="">— انتخاب —</option>
          {db.parties.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
        </select>
      </Field>

      <Field label="شناسهٔ صیاد">
        <input className="input num-input" value={c.sayadId ?? ''} onChange={(e) => setC({ ...c, sayadId: e.target.value })} />
      </Field>
    </Modal>
  );
}
