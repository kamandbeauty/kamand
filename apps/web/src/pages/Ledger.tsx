import React, { useMemo, useState } from 'react';
import {
  formatMoney, journal, toPersianDigits, uuid,
  type Account, type JournalEntry,
} from '@javid/core';
import {
  can, hasOpeningEntry, indexOf, openingDateOf, pendingOpeningBalances,
  postManualEntry, postOpeningBalances, validateManualEntry, voidManualEntry,
  type DB, type ManualLineInput,
} from '../store';
import {
  Badge, Banner, Card, DateInput, Empty, Field, JDate,
  Modal, Money, MoneyInput, Search, Tabs,
} from '../ui';

const fa = (n: number) => toPersianDigits(n);

/**
 * دفتر: سند دستی و مانده‌های اول دوره.
 *
 * این دو تنها راه‌هایی هستند که کاربر مستقیماً به دفتر می‌نویسد،
 * بیرون از جریان عادی فاکتور و تراکنش.
 */
export function Ledger({ db, setDB }: { db: DB; setDB: (d: DB) => void }) {
  const [tab, setTab] = useState<'entries' | 'opening'>('entries');

  return (
    <>
      <Tabs
        active={tab}
        onChange={setTab}
        tabs={[
          { id: 'entries' as const, label: 'اسناد' },
          { id: 'opening' as const, label: 'مانده‌های اول دوره' },
        ]}
      />
      {tab === 'entries' && <Entries db={db} setDB={setDB} />}
      {tab === 'opening' && <OpeningBalances db={db} setDB={setDB} />}
    </>
  );
}

// ─────────── اسناد ───────────

const SOURCE_LABELS: Record<string, string> = {
  invoice: 'فاکتور',
  transaction: 'تراکنش',
  cheque: 'چک',
  opening: 'افتتاحیه',
  closing: 'اختتامیه',
  manual: 'دستی',
};

function Entries({ db, setDB }: { db: DB; setDB: (d: DB) => void }) {
  const [q, setQ] = useState('');
  const [editing, setEditing] = useState(false);
  const [error, setError] = useState('');
  const index = indexOf(db);
  const mayWrite = can(db, 'entry.manual');

  const rows = useMemo(() => {
    const all = journal(db.entries, index);
    const term = q.trim().toLowerCase();
    if (!term) return all.slice(-200).reverse();
    return all.filter((e) => e.description.toLowerCase().includes(term)).reverse();
  }, [db.entries, index, q]);

  const byId = new Map(db.entries.map((e) => [e.id, e]));

  function remove(id: string) {
    try {
      setDB(voidManualEntry(db, id));
      setError('');
    } catch (e) {
      setError((e as Error).message);
    }
  }

  return (
    <>
      <div className="toolbar no-print">
        <Search value={q} onChange={setQ} placeholder="جستجو در شرح سند…" />
        <div style={{ flex: 1 }} />
        {mayWrite && (
          <button className="btn btn-primary" onClick={() => setEditing(true)}>+ سند دستی</button>
        )}
      </div>

      {error && <Banner tone="critical">{error}</Banner>}

      <Card>
        {rows.length === 0 ? (
          <Empty icon="📒" text="سندی ثبت نشده است" />
        ) : (
          <table>
            <thead>
              <tr>
                <th>تاریخ</th>
                <th>منبع</th>
                <th>شرح</th>
                <th className="end">مبلغ</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {rows.map((e) => {
                const src = byId.get(e.entryId);
                const isManual = src?.sourceType === 'manual';
                return (
                  <tr key={e.entryId}>
                    <td><JDate value={e.date} /></td>
                    <td className="small">
                      <Badge tone={isManual ? 'amber' : 'gray'}>
                        {SOURCE_LABELS[src?.sourceType ?? ''] ?? '—'}
                      </Badge>
                    </td>
                    <td>{e.description}</td>
                    <td className="end"><Money value={e.total} /></td>
                    <td className="end no-print">
                      {isManual && mayWrite && (
                        <button className="btn btn-sm btn-ghost" onClick={() => remove(e.entryId)}>
                          حذف
                        </button>
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
        <ManualEntryEditor
          db={db}
          onClose={() => setEditing(false)}
          onSave={(input) => {
            try {
              setDB(postManualEntry(db, input));
              setEditing(false);
              setError('');
            } catch (e) {
              setError((e as Error).message);
            }
          }}
        />
      )}
    </>
  );
}

function ManualEntryEditor({ db, onClose, onSave }: {
  db: DB;
  onClose: () => void;
  onSave: (input: { date: string; description: string; lines: ManualLineInput[] }) => void;
}) {
  const accounts = useMemo(
    () => indexOf(db).all()
      .filter((a) => indexOf(db).children(a.id).length === 0)
      .sort((a, b) => a.code.localeCompare(b.code)),
    [db],
  );

  const blank = (): ManualLineInput & { key: string } => ({
    key: uuid(), accountId: accounts[0]?.id ?? '', debit: 0, credit: 0,
  });

  const [date, setDate] = useState(new Date().toISOString().slice(0, 10));
  const [description, setDescription] = useState('');
  const [lines, setLines] = useState([blank(), blank()]);
  const [errors, setErrors] = useState<string[]>([]);

  const debit = lines.reduce((s, l) => s + l.debit, 0);
  const credit = lines.reduce((s, l) => s + l.credit, 0);
  const diff = debit - credit;

  function patch(key: string, p: Partial<ManualLineInput>) {
    setLines((ls) => ls.map((l) => (l.key === key ? { ...l, ...p } : l)));
    setErrors([]);
  }

  function submit() {
    const input = { date, description, lines: lines.map(({ key, ...l }) => l) };
    const errs = validateManualEntry(input);
    setErrors(errs);
    if (errs.length === 0) onSave(input);
  }

  return (
    <Modal
      wide
      title="ثبت سند دستی"
      onClose={onClose}
      footer={
        <>
          <button className="btn btn-primary" onClick={submit} disabled={diff !== 0 || debit === 0}>
            ثبت سند
          </button>
          <button className="btn" onClick={onClose}>انصراف</button>
          <div style={{ flex: 1 }} />
          <div style={{ textAlign: 'end' }}>
            <div className="small muted">اختلاف</div>
            <div className={`num strong ${diff === 0 ? 'money-pos' : 'money-neg'}`}>
              {diff === 0 ? '✓ متوازن' : formatMoney(Math.abs(diff))}
            </div>
          </div>
        </>
      }
    >
      {errors.length > 0 && (
        <Banner tone="critical" title="سند قابل ثبت نیست">
          <ul style={{ paddingInlineStart: 18, margin: 0 }}>
            {errors.map((e, i) => <li key={i}>{e}</li>)}
          </ul>
        </Banner>
      )}

      <Banner tone="info">
        سند دستی مستقیماً در دفتر ثبت می‌شود. برای ثبت فروش یا خرید از
        بخش فاکتورها استفاده کنید تا موجودی کالا هم بروز شود.
      </Banner>

      <div className="row">
        <Field label="تاریخ">
          <DateInput value={date} onChange={(d) => { setDate(d); setErrors([]); }} />
        </Field>
        <Field label="شرح سند *">
          <input
            className="input"
            value={description}
            onChange={(e) => { setDescription(e.target.value); setErrors([]); }}
            placeholder="مثلاً: اصلاح خطای ثبت"
          />
        </Field>
      </div>

      <div className="card" style={{ marginBottom: 14 }}>
        <table>
          <thead>
            <tr>
              <th style={{ width: '38%' }}>حساب</th>
              <th style={{ width: 140 }}>بدهکار</th>
              <th style={{ width: 140 }}>بستانکار</th>
              <th>طرف حساب</th>
              <th style={{ width: 40 }}></th>
            </tr>
          </thead>
          <tbody>
            {lines.map((l) => (
              <tr key={l.key}>
                <td>
                  <select
                    className="select"
                    value={l.accountId}
                    onChange={(e) => patch(l.key, { accountId: e.target.value })}
                  >
                    {accounts.map((a: Account) => (
                      <option key={a.id} value={a.id}>{a.code} — {a.name}</option>
                    ))}
                  </select>
                </td>
                <td>
                  <MoneyInput
                    value={l.debit}
                    onChange={(v) => patch(l.key, { debit: v, credit: v > 0 ? 0 : l.credit })}
                  />
                </td>
                <td>
                  <MoneyInput
                    value={l.credit}
                    onChange={(v) => patch(l.key, { credit: v, debit: v > 0 ? 0 : l.debit })}
                  />
                </td>
                <td>
                  <select
                    className="select"
                    value={l.partyId ?? ''}
                    onChange={(e) => patch(l.key, { partyId: e.target.value || null })}
                  >
                    <option value="">—</option>
                    {db.parties.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
                  </select>
                </td>
                <td>
                  <button
                    className="btn btn-sm btn-ghost"
                    disabled={lines.length <= 2}
                    onClick={() => setLines((ls) => ls.filter((x) => x.key !== l.key))}
                  >✕</button>
                </td>
              </tr>
            ))}
            <tr className="report-total">
              <td>جمع</td>
              <td className="end"><Money value={debit} /></td>
              <td className="end"><Money value={credit} /></td>
              <td colSpan={2}></td>
            </tr>
          </tbody>
        </table>
        <div style={{ padding: 12 }}>
          <button className="btn btn-sm" onClick={() => setLines((ls) => [...ls, blank()])}>
            + افزودن ردیف
          </button>
        </div>
      </div>
    </Modal>
  );
}

// ─────────── مانده‌های اول دوره ───────────

function OpeningBalances({ db, setDB }: { db: DB; setDB: (d: DB) => void }) {
  const [date, setDate] = useState(openingDateOf(db));
  const [done, setDone] = useState(false);
  const [error, setError] = useState('');

  const pending = pendingOpeningBalances(db);
  const posted = hasOpeningEntry(db);
  const mayWrite = can(db, 'entry.manual');

  const partiesWith = db.parties.filter((p) => !p.archived && p.openingBalance !== 0);
  const treasuriesWith = db.treasuries.filter((t) => !t.archived && t.openingBalance !== 0);

  function post() {
    try {
      setDB(postOpeningBalances(db, date));
      setDone(true);
      setError('');
    } catch (e) {
      setError((e as Error).message);
    }
  }

  return (
    <div style={{ display: 'grid', gap: 18, maxWidth: 820 }}>
      {done && (
        <Banner tone="success" title="مانده‌های اول دوره ثبت شد">
          حالا این مبالغ در گزارش بدهکاران و بستانکاران و ترازنامه دیده می‌شوند.
        </Banner>
      )}
      {error && <Banner tone="critical">{error}</Banner>}

      {!posted && pending.total > 0 && (
        <Banner tone="warning" title="مانده‌های وارد‌شده هنوز در دفتر نیستند">
          شما مانده اول دوره وارد کرده‌اید ولی سند افتتاحیه ثبت نشده است.
          تا زمانی که این سند ثبت نشود، این مبالغ در گزارش‌ها دیده نمی‌شوند.
        </Banner>
      )}

      {posted && (
        <Banner tone="success">
          سند افتتاحیه ثبت شده است. اگر مانده‌ای را تغییر دادید، دوباره ثبت کنید
          تا سند بروز شود.
        </Banner>
      )}

      <Card title="خلاصهٔ مانده‌ها">
        <table>
          <tbody>
            <tr>
              <td>اشخاص با مانده اول دوره</td>
              <td className="end num strong">{fa(pending.parties)}</td>
            </tr>
            <tr>
              <td>حساب‌های خزانه با مانده</td>
              <td className="end num strong">{fa(pending.treasuries)}</td>
            </tr>
            <tr>
              <td>ارزش موجودی اولیهٔ کالا</td>
              <td className="end"><Money value={pending.inventory} /></td>
            </tr>
          </tbody>
        </table>
      </Card>

      {partiesWith.length > 0 && (
        <Card title="اشخاص">
          <table>
            <thead>
              <tr><th>نام</th><th className="end">مانده</th><th className="center">وضعیت</th></tr>
            </thead>
            <tbody>
              {partiesWith.map((p) => (
                <tr key={p.id}>
                  <td>{p.name}</td>
                  <td className="end"><Money value={Math.abs(p.openingBalance)} /></td>
                  <td className="center">
                    <Badge tone={p.openingBalance > 0 ? 'green' : 'red'}>
                      {p.openingBalance > 0 ? 'بدهکار' : 'بستانکار'}
                    </Badge>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      )}

      {treasuriesWith.length > 0 && (
        <Card title="حساب‌های خزانه">
          <table>
            <tbody>
              {treasuriesWith.map((t) => (
                <tr key={t.id}>
                  <td>{t.name}</td>
                  <td className="end"><Money value={t.openingBalance} /></td>
                </tr>
              ))}
            </tbody>
          </table>
        </Card>
      )}

      <Card title="ثبت سند افتتاحیه">
        <p className="small muted" style={{ marginBottom: 12 }}>
          اختلاف بین دارایی‌ها و بدهی‌ها خودکار به حساب سرمایه منتقل می‌شود
          تا سند متوازن بماند.
        </p>
        <Field label="تاریخ سند" hint="معمولاً ابتدای سال مالی">
          <div style={{ maxWidth: 200 }}>
            <DateInput value={date} onChange={setDate} />
          </div>
        </Field>
        {mayWrite ? (
          <button className="btn btn-primary" onClick={post} disabled={pending.total === 0}>
            {posted ? '🔄 بروزرسانی سند افتتاحیه' : '✓ ثبت سند افتتاحیه'}
          </button>
        ) : (
          <Banner tone="info">نقش شما اجازهٔ ثبت سند را ندارد.</Banner>
        )}
        {pending.total === 0 && (
          <div className="small muted" style={{ marginTop: 8 }}>
            هیچ مانده اول دوره‌ای وارد نشده است. آن‌ها را از بخش «اشخاص» و
            «خزانه» وارد کنید.
          </div>
        )}
      </Card>
    </div>
  );
}
