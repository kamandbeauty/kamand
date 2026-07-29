import React, { useMemo, useState } from 'react';
import {
  ACTION_LABELS, describeAudit, ENTITY_LABELS, filterAudit, formatJalali,
  PERMISSION_LABELS, permissionsOf, ROLE_DESCRIPTIONS, ROLE_LABELS,
  toCSV, toPersianDigits, validateLockRequest, validateUnlock,
  type AuditedEntity, type AuditLog,
} from '@javid/core';
import { can, lockPeriod, unlockPeriod, type DB } from '../store';
import {
  Badge, Banner, Card, DateInput, Empty, Field, JDate, Modal, Search, Tabs, download,
} from '../ui';

const fa = (n: number) => toPersianDigits(n);

const ACTION_TONE: Record<AuditLog['action'], 'green' | 'blue' | 'red' | 'amber'> = {
  create: 'green',
  update: 'blue',
  delete: 'red',
  restore: 'amber',
};

/**
 * ردّ ممیزی و قفل دورهٔ مالی.
 *
 * هر دو در تحلیل بازار «اجباری در نرم‌افزار مالی چندکاربره» شناخته شدند:
 * بدون ردّ ممیزی اختلاف بین شرکا حل‌نشدنی است، و بدون قفل دوره
 * دفتر با اظهارنامهٔ ارسالی ناهماهنگ می‌شود.
 */
export function Audit({ db, setDB }: { db: DB; setDB: (d: DB) => void }) {
  const [tab, setTab] = useState<'log' | 'period' | 'access'>('log');

  return (
    <>
      <Tabs
        active={tab}
        onChange={setTab}
        tabs={[
          { id: 'log' as const, label: 'ردّ ممیزی' },
          { id: 'period' as const, label: 'دورهٔ مالی' },
          { id: 'access' as const, label: 'سطح دسترسی' },
        ]}
      />
      {tab === 'log' && <AuditTrail db={db} />}
      {tab === 'period' && <PeriodControl db={db} setDB={setDB} />}
      {tab === 'access' && <AccessInfo db={db} />}
    </>
  );
}

// ─────────── ردّ ممیزی ───────────

function AuditTrail({ db }: { db: DB }) {
  const [q, setQ] = useState('');
  const [entity, setEntity] = useState<'' | AuditedEntity>('');
  const [action, setAction] = useState<'' | AuditLog['action']>('');
  const [detail, setDetail] = useState<AuditLog | null>(null);

  const rows = useMemo(() => {
    const filtered = filterAudit(db.auditLogs, {
      ...(entity ? { entity } : {}),
      ...(action ? { action } : {}),
    });
    const term = q.trim().toLowerCase();
    if (!term) return filtered;
    return filtered.filter((l) => describeAudit(l).toLowerCase().includes(term));
  }, [db.auditLogs, entity, action, q]);

  function exportCsv() {
    download(
      'رد-ممیزی.csv',
      toCSV(rows, [
        { key: 'at', header: 'زمان', value: (l) => formatJalali(new Date(l.at), 'short', false) },
        { key: 'action', header: 'عملیات', value: (l) => ACTION_LABELS[l.action] },
        { key: 'entity', header: 'موجودیت', value: (l) => ENTITY_LABELS[l.entity as AuditedEntity] ?? l.entity },
        { key: 'entityId', header: 'شناسه', value: (l) => l.entityId },
        { key: 'userId', header: 'کاربر', value: (l) => l.userId },
      ]),
      'text/csv;charset=utf-8',
    );
  }

  return (
    <>
      <div className="toolbar no-print">
        <Search value={q} onChange={setQ} placeholder="جستجو در رویدادها…" />
        <select className="select" style={{ maxWidth: 160 }} value={entity} onChange={(e) => setEntity(e.target.value as AuditedEntity)}>
          <option value="">همهٔ موجودیت‌ها</option>
          {Object.entries(ENTITY_LABELS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
        </select>
        <select className="select" style={{ maxWidth: 130 }} value={action} onChange={(e) => setAction(e.target.value as AuditLog['action'])}>
          <option value="">همهٔ عملیات</option>
          {Object.entries(ACTION_LABELS).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
        </select>
        <div style={{ flex: 1 }} />
        <button className="btn" onClick={exportCsv}>⬇ خروجی</button>
      </div>

      <Card>
        {rows.length === 0 ? (
          <Empty icon="📜" text="رویدادی ثبت نشده است" />
        ) : (
          <table>
            <thead>
              <tr>
                <th>زمان</th>
                <th>عملیات</th>
                <th>موجودیت</th>
                <th>شرح</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {rows.slice(0, 200).map((l) => (
                <tr key={l.id}>
                  <td><JDate value={l.at} /></td>
                  <td><Badge tone={ACTION_TONE[l.action]}>{ACTION_LABELS[l.action]}</Badge></td>
                  <td className="small">{ENTITY_LABELS[l.entity as AuditedEntity] ?? l.entity}</td>
                  <td className="small muted">{describeAudit(l)}</td>
                  <td className="end no-print">
                    <button className="btn btn-sm btn-ghost" onClick={() => setDetail(l)}>جزئیات</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        {rows.length > 200 && (
          <div className="small muted" style={{ marginTop: 10 }}>
            نمایش ۲۰۰ رویداد از {fa(rows.length)} — برای دیدن همه خروجی بگیرید.
          </div>
        )}
      </Card>

      {detail && <AuditDetail log={detail} onClose={() => setDetail(null)} />}
    </>
  );
}

function AuditDetail({ log, onClose }: { log: AuditLog; onClose: () => void }) {
  const changes = log.action === 'update' ? (log.before as { field: string; before: unknown; after: unknown }[] | undefined) : undefined;

  const show = (v: unknown) =>
    v === null || v === undefined ? '—' : typeof v === 'object' ? JSON.stringify(v) : String(v);

  return (
    <Modal
      title="جزئیات رویداد"
      onClose={onClose}
      footer={<button className="btn" onClick={onClose}>بستن</button>}
    >
      <table style={{ marginBottom: 14 }}>
        <tbody>
          <tr><td>عملیات</td><td className="end"><Badge tone={ACTION_TONE[log.action]}>{ACTION_LABELS[log.action]}</Badge></td></tr>
          <tr><td>موجودیت</td><td className="end">{ENTITY_LABELS[log.entity as AuditedEntity] ?? log.entity}</td></tr>
          <tr><td>شناسه</td><td className="end num small" style={{ direction: 'ltr' }}>{log.entityId}</td></tr>
          <tr><td>زمان</td><td className="end"><JDate value={log.at} style="full" /></td></tr>
        </tbody>
      </table>

      {changes && changes.length > 0 && (
        <>
          <div className="small strong" style={{ marginBottom: 8 }}>تغییرات</div>
          <table>
            <thead>
              <tr><th>فیلد</th><th>مقدار قبلی</th><th>مقدار جدید</th></tr>
            </thead>
            <tbody>
              {changes.map((c, i) => (
                <tr key={i}>
                  <td className="small">{c.field}</td>
                  <td className="small muted">{show(c.before)}</td>
                  <td className="small strong">{show(c.after)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}
    </Modal>
  );
}

// ─────────── دورهٔ مالی ───────────

function PeriodControl({ db, setDB }: { db: DB; setDB: (d: DB) => void }) {
  const today = new Date().toISOString().slice(0, 10);
  const [through, setThrough] = useState(today);
  const [note, setNote] = useState('');
  const [unlockOpen, setUnlockOpen] = useState(false);
  const [reason, setReason] = useState('');
  const [errors, setErrors] = useState<string[]>([]);

  const lock = db.periodLock;
  const mayLock = can(db, 'period.lock');
  const mayUnlock = can(db, 'period.unlock');

  function doLock() {
    const issues = validateLockRequest(through, { today, currentLock: lock });
    setErrors(issues);
    if (issues.length === 0) {
      setDB(lockPeriod(db, through, note.trim() || undefined));
      setNote('');
    }
  }

  function doUnlock() {
    const issues = validateUnlock({ reason });
    setErrors(issues);
    if (issues.length === 0) {
      setDB(unlockPeriod(db, reason.trim()));
      setUnlockOpen(false);
      setReason('');
    }
  }

  return (
    <div style={{ display: 'grid', gap: 18, maxWidth: 760 }}>
      {errors.length > 0 && (
        <Banner tone="critical" title="امکان انجام این کار نیست">
          <ul style={{ paddingInlineStart: 18, margin: 0 }}>
            {errors.map((e, i) => <li key={i}>{e}</li>)}
          </ul>
        </Banner>
      )}

      <Card title="وضعیت دورهٔ مالی">
        {lock ? (
          <>
            <Banner tone="warning" title="دوره بسته است">
              همهٔ اسناد تا <strong><JDate value={lock.lockedThrough} style="long" /></strong> قفل
              هستند و امکان ثبت یا ویرایش در آن بازه وجود ندارد.
            </Banner>
            <table>
              <tbody>
                <tr><td>بسته‌شده تا</td><td className="end"><JDate value={lock.lockedThrough} style="long" /></td></tr>
                <tr><td>تاریخ بستن</td><td className="end"><JDate value={lock.lockedAt} /></td></tr>
                {lock.note && <tr><td>توضیح</td><td className="end small">{lock.note}</td></tr>}
              </tbody>
            </table>
            {mayUnlock && (
              <button className="btn btn-danger" style={{ marginTop: 12 }} onClick={() => setUnlockOpen(true)}>
                بازکردن دوره
              </button>
            )}
          </>
        ) : (
          <Banner tone="success">
            هیچ دوره‌ای بسته نیست؛ ثبت و ویرایش در همهٔ تاریخ‌ها آزاد است.
          </Banner>
        )}
      </Card>

      {mayLock && (
        <Card title="بستن دوره">
          <p className="small muted" style={{ marginBottom: 12 }}>
            پس از بستن دوره، اسناد آن بازه قابل تغییر نیستند. این کار از
            ناهماهنگی دفتر با اظهارنامهٔ ارسالی به سازمان امور مالیاتی
            جلوگیری می‌کند.
          </p>
          <div className="row">
            <Field label="بستن تا تاریخ">
              <DateInput value={through} onChange={(d) => { setThrough(d); setErrors([]); }} />
            </Field>
            <Field label="توضیح (اختیاری)">
              <input className="input" value={note} onChange={(e) => setNote(e.target.value)} />
            </Field>
          </div>
          <button className="btn btn-primary" onClick={doLock}>🔒 بستن دوره</button>
        </Card>
      )}

      {!mayLock && (
        <Banner tone="info">
          نقش «{ROLE_LABELS[db.role]}» اجازهٔ بستن دورهٔ مالی را ندارد.
        </Banner>
      )}

      {unlockOpen && (
        <Modal
          title="بازکردن دورهٔ مالی"
          onClose={() => setUnlockOpen(false)}
          footer={
            <>
              <button className="btn btn-danger" onClick={doUnlock}>تأیید و بازکردن</button>
              <button className="btn" onClick={() => setUnlockOpen(false)}>انصراف</button>
            </>
          }
        >
          <Banner tone="critical" title="این کار ثبت می‌شود">
            بازکردن دورهٔ بسته‌شده ممکن است باعث ناهماهنگی با اظهارنامهٔ
            ارسالی شود. دلیل شما در ردّ ممیزی ثبت خواهد شد.
          </Banner>
          <Field label="دلیل بازکردن *" hint="حداقل ۱۰ نویسه">
            <textarea
              className="input"
              rows={3}
              value={reason}
              onChange={(e) => { setReason(e.target.value); setErrors([]); }}
              autoFocus
            />
          </Field>
        </Modal>
      )}
    </div>
  );
}

// ─────────── سطح دسترسی ───────────

function AccessInfo({ db }: { db: DB }) {
  const perms = permissionsOf(db.role);

  return (
    <div style={{ display: 'grid', gap: 18, maxWidth: 760 }}>
      <Card title="نقش شما در این کسب‌وکار">
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 8 }}>
          <Badge tone="blue">{ROLE_LABELS[db.role]}</Badge>
          <span className="small muted">{ROLE_DESCRIPTIONS[db.role]}</span>
        </div>
      </Card>

      <Card title="اجازه‌های شما">
        <table>
          <tbody>
            {(Object.keys(PERMISSION_LABELS) as (keyof typeof PERMISSION_LABELS)[]).map((p) => (
              <tr key={p}>
                <td>{PERMISSION_LABELS[p]}</td>
                <td className="end">
                  {perms.includes(p)
                    ? <Badge tone="green">✓ مجاز</Badge>
                    : <Badge tone="gray">✕ غیرمجاز</Badge>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>

      <Banner tone="info" title="گزارش و خروجی همیشه آزاد است">
        حتی نقش «فقط مشاهده» می‌تواند گزارش بگیرد و از اطلاعات خروجی
        دریافت کند. محدودیت نقش فقط روی ثبت و ویرایش است.
      </Banner>
    </div>
  );
}
