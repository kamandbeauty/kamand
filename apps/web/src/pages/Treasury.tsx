import React, { useState } from 'react';
import {
  treasuryBalance, treasuryBalances,
  toPersianDigits, uuid, type Cheque, type ChequeDirection, type Transaction, type TransactionKind, type Treasury as T,
} from '@javid/core';

const fa = (n: number) => toPersianDigits(n);
import {
  allocatePayment, canChangeChequeStatus, chequeAlerts, CHEQUE_STATUS_LABELS,
  activeTransactions, indexOf, openInvoicesOf, postTransactionToDB,
  registerCheque, settleCheque, voidTransaction, type DB,
} from '../store';
import { Badge, Banner, Card, DateInput, Empty, Field, JDate, Modal, Money, MoneyInput, Tabs } from '../ui';

export function Treasury({ db, setDB, canWrite }: {
  db: DB;
  setDB: (d: DB) => void;
  canWrite: boolean;
}) {
  const [tab, setTab] = useState<'accounts' | 'transactions' | 'cheques'>('accounts');
  const [txModal, setTxModal] = useState<TransactionKind | null>(null);
  const [chqModal, setChqModal] = useState<ChequeDirection | null>(null);
  const [error, setError] = useState('');

  function act(chequeId: string, event: 'cash' | 'bounce') {
    try {
      setDB(settleCheque(db, chequeId, event));
      setError('');
    } catch (e) {
      setError((e as Error).message);
    }
  }

  const index = indexOf(db);
  const today = new Date().toISOString().slice(0, 10);

  // موجودی هر خزانه جداگانه — پیش‌تر همهٔ صندوق‌ها مانده حساب کل را
  // نشان می‌دادند و جمعشان چند برابر پول واقعی می‌شد
  const perTreasury = treasuryBalances(db.entries);
  const balances = db.treasuries.map((t) => ({
    t,
    balance: perTreasury.get(t.id) ?? 0,
  }));

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

      {error && (
        <Banner tone="critical" action={<button className="btn btn-sm" onClick={() => setError('')}>بستن</button>}>
          {error}
        </Banner>
      )}

      {(() => {
        const a = chequeAlerts(db);
        if (a.overdue.length === 0 && a.dueSoon.length === 0) return null;
        return (
          <Banner tone={a.overdue.length > 0 ? 'critical' : 'warning'} title="یادآوری چک">
            {a.overdue.length > 0 && <>{fa(a.overdue.length)} چک سررسید گذشته دارید. </>}
            {a.dueSoon.length > 0 && <>{fa(a.dueSoon.length)} چک تا هفتهٔ آینده سررسید می‌شود.</>}
          </Banner>
        );
      })()}

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
          {activeTransactions(db).length === 0 ? <Empty icon="💳" text="تراکنشی ثبت نشده است" /> : (
            <table>
              <thead>
                <tr><th>تاریخ</th><th>نوع</th><th>طرف حساب</th><th>حساب</th><th>شرح</th><th className="end">مبلغ</th><th></th></tr>
              </thead>
              <tbody>
                {[...activeTransactions(db)].reverse().map((t) => (
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
                    <td className="end no-print">
                      {canWrite && !t.invoiceId && (
                        <button
                          className="btn btn-sm btn-ghost"
                          onClick={() => {
                            try { setDB(voidTransaction(db, t.id)); setError(''); }
                            catch (e) { setError((e as Error).message); }
                          }}
                        >حذف</button>
                      )}
                    </td>
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
                          {CHEQUE_STATUS_LABELS[c.status]}
                        </Badge>
                      </td>
                      <td className="end no-print">
                        {canWrite && c.status === 'pending' && (
                          <>
                            <button
                              className="btn btn-sm btn-ghost"
                              onClick={() => act(c.id, 'cash')}
                            >وصول</button>
                            <button
                              className="btn btn-sm btn-ghost"
                              onClick={() => act(c.id, 'bounce')}
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
          onSave={(tx, autoAllocate) => {
            // دریافت از مشتری می‌تواند خودکار به فاکتورهای باز تخصیص یابد
            if (autoAllocate && tx.kind === 'receive' && tx.partyId) {
              const r = allocatePayment(db, {
                partyId: tx.partyId,
                amount: tx.amount,
                treasuryId: tx.treasuryId,
                date: tx.date,
                method: tx.method,
              });
              setDB(r.db);
            } else {
              setDB(postTransactionToDB(db, tx));
            }
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
            try {
              setDB(registerCheque(db, c));
              setChqModal(null);
              setError('');
            } catch (e) {
              setError((e as Error).message);
              setChqModal(null);
            }
          }}
        />
      )}
    </>
  );
}

function TxModal({ db, kind, onClose, onSave }: {
  db: DB;
  kind: TransactionKind;
  onClose: () => void;
  onSave: (tx: Transaction, autoAllocate: boolean) => void;
}) {
  const [autoAllocate, setAutoAllocate] = useState(true);
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
              onSave(tx, autoAllocate);
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

      {kind === 'receive' && tx.partyId && (() => {
        const open = openInvoicesOf(db, tx.partyId);
        if (open.length === 0) return null;
        const totalOpen = open.reduce((s2, r) => s2 + r.remaining, 0);
        return (
          <div className="card" style={{ padding: 12, marginBottom: 14 }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
              <input
                type="checkbox"
                checked={autoAllocate}
                onChange={(e) => setAutoAllocate(e.target.checked)}
              />
              <span>تخصیص خودکار به فاکتورهای باز</span>
            </label>
            <div className="small muted" style={{ marginBottom: 8 }}>
              {fa(open.length)} فاکتور باز با مجموع مانده <Money value={totalOpen} /> —
              مبلغ از قدیمی‌ترین کم می‌شود.
            </div>
            <table>
              <tbody>
                {open.slice(0, 5).map((r) => (
                  <tr key={r.invoice.id}>
                    <td className="num small">{r.invoice.number}</td>
                    <td><JDate value={r.invoice.date} /></td>
                    <td className="end"><Money value={r.remaining} /></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        );
      })()}

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
