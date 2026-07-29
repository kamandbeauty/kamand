import React, { useEffect, useState } from 'react';
import { maskPhone, normalizePhone, toPersianDigits, type BusinessRef } from '@javid/core';
import * as api from '../api';
import { bootstrapFromServer, runSync, type SyncOutcome } from '../syncEngine';
import { deviceId, queue, type DB } from '../store';
import { Badge, Banner, Card, Empty, Field, Modal } from '../ui';

const fa = (n: number) => toPersianDigits(n);

/**
 * حساب کاربری و همگام‌سازی ابری.
 *
 * نکتهٔ محصولی: همگام‌سازی کاملاً **اختیاری** است. برنامه بدون سرور
 * هم کامل کار می‌کند — این صفحه فقط یک قابلیت اضافه است، نه پیش‌نیاز.
 */
export function Account({ db, setDB }: { db: DB; setDB: (d: DB) => void }) {
  const [server, setServer] = useState(api.serverUrl());
  const [signedIn, setSignedIn] = useState(api.isSignedIn());
  const [businesses, setBusinesses] = useState<BusinessRef[]>([]);
  const [selected, setSelected] = useState(api.remoteBusinessId() ?? '');
  const [phone, setPhone] = useState('');
  const [step, setStep] = useState<'phone' | 'code'>('phone');
  const [code, setCode] = useState('');
  const [devCode, setDevCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [notice, setNotice] = useState('');
  const [last, setLast] = useState<SyncOutcome | null>(null);
  const [inviteOpen, setInviteOpen] = useState(false);

  useEffect(() => {
    if (!signedIn) return;
    void api.me()
      .then((r) => setBusinesses(r.businesses))
      .catch(() => setSignedIn(api.isSignedIn()));
  }, [signedIn]);

  function saveServer() {
    api.setServerUrl(server.trim());
    setServer(api.serverUrl());
    setError('');
    setNotice('آدرس سرور ذخیره شد');
    void api.health()
      .then((h) => setNotice(`اتصال برقرار است — نسخهٔ قرارداد ${fa(h.protocol)}`))
      .catch((e) => setError((e as Error).message));
  }

  async function sendCode() {
    const normalized = normalizePhone(phone);
    if (!normalized) return setError('شمارهٔ موبایل نامعتبر است');

    setBusy(true);
    setError('');
    try {
      const r = await api.requestOtp(normalized);
      setStep('code');
      if (r.devCode) setDevCode(r.devCode);
      setNotice(`کد تأیید به ${maskPhone(normalized)} ارسال شد`);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  async function confirmCode() {
    setBusy(true);
    setError('');
    try {
      const r = await api.verifyOtp(normalizePhone(phone)!, code, deviceId(), 'مرورگر');
      setSignedIn(true);
      setBusinesses(r.businesses);
      setStep('phone');
      setCode('');
      setDevCode('');
      setNotice('با موفقیت وارد شدید');
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  async function doLogout() {
    await api.logout();
    setSignedIn(false);
    setBusinesses([]);
    setSelected('');
    setNotice('از حساب خارج شدید — اطلاعات محلی شما دست‌نخورده است');
  }

  async function linkBusiness() {
    setBusy(true);
    setError('');
    try {
      // کسب‌وکار محلی را با همان شناسه روی سرور می‌سازیم تا نگاشت ساده بماند
      const b = await api.createRemoteBusiness(db.business.name, db.business.id);
      api.setRemoteBusinessId(b.id);
      setSelected(b.id);
      setBusinesses((prev) => [...prev, b]);
      setNotice('کسب‌وکار روی سرور ثبت شد');
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  function chooseBusiness(id: string) {
    api.setRemoteBusinessId(id || null);
    api.setSyncCursor(0);
    setSelected(id);
  }

  async function syncNow() {
    setBusy(true);
    setError('');
    try {
      const r = await runSync(db, setDB);
      setLast(r);
      if (!r.ok) setError(r.error ?? 'همگام‌سازی ناموفق بود');
      else setNotice(`همگام شد — ${fa(r.pushed)} ارسال، ${fa(r.pulled)} دریافت`);
    } finally {
      setBusy(false);
    }
  }

  async function bootstrap() {
    setBusy(true);
    setError('');
    try {
      const r = await bootstrapFromServer(db);
      setDB(r.db);
      setNotice(`${fa(r.count)} رکورد از سرور بارگذاری شد`);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div style={{ display: 'grid', gap: 18, maxWidth: 820 }}>
      <Banner tone="info" title="همگام‌سازی اختیاری است">
        جاوید بدون سرور هم کامل کار می‌کند. اطلاعات شما همیشه روی همین دستگاه
        ذخیره می‌شود؛ همگام‌سازی فقط برای کار روی چند دستگاه است.
      </Banner>

      {error && <Banner tone="critical">{error}</Banner>}
      {notice && !error && <Banner tone="success">{notice}</Banner>}

      <Card title="آدرس سرور">
        <Field label="نشانی سرور همگام‌سازی" hint="برای مثال https://sync.example.ir">
          <input
            className="input"
            style={{ direction: 'ltr', textAlign: 'start' }}
            value={server}
            placeholder="http://localhost:8787"
            onChange={(e) => setServer(e.target.value)}
          />
        </Field>
        <button className="btn btn-primary" onClick={saveServer}>ذخیره و بررسی اتصال</button>
      </Card>

      {api.isConfigured() && !signedIn && (
        <Card title="ورود با شمارهٔ موبایل">
          {step === 'phone' ? (
            <>
              <Field label="شمارهٔ موبایل">
                <input
                  className="input num-input"
                  value={phone}
                  placeholder="۰۹۱۲۳۴۵۶۷۸۹"
                  onChange={(e) => { setPhone(e.target.value); setError(''); }}
                />
              </Field>
              <button className="btn btn-primary" onClick={() => void sendCode()} disabled={busy}>
                {busy ? 'در حال ارسال…' : 'ارسال کد تأیید'}
              </button>
            </>
          ) : (
            <>
              {devCode && (
                <Banner tone="warning" title="حالت توسعه">
                  کد تأیید: <span className="num strong">{devCode}</span>
                </Banner>
              )}
              <Field label="کد تأیید">
                <input
                  className="input num-input"
                  style={{ letterSpacing: 6, textAlign: 'center' }}
                  maxLength={6}
                  value={code}
                  onChange={(e) => { setCode(e.target.value); setError(''); }}
                  autoFocus
                />
              </Field>
              <div style={{ display: 'flex', gap: 10 }}>
                <button className="btn btn-primary" onClick={() => void confirmCode()} disabled={busy}>
                  {busy ? 'در حال بررسی…' : 'تأیید و ورود'}
                </button>
                <button className="btn" onClick={() => { setStep('phone'); setCode(''); setDevCode(''); }}>
                  تغییر شماره
                </button>
              </div>
            </>
          )}
        </Card>
      )}

      {signedIn && (
        <>
          <Card
            title="کسب‌وکار همگام‌شونده"
            action={<button className="btn btn-sm" onClick={() => void doLogout()}>خروج از حساب</button>}
          >
            {businesses.length === 0 ? (
              <Empty
                icon="🏪"
                text="هنوز کسب‌وکاری روی سرور ندارید"
                action={
                  <button className="btn btn-primary" onClick={() => void linkBusiness()} disabled={busy}>
                    ثبت «{db.business.name}» روی سرور
                  </button>
                }
              />
            ) : (
              <>
                <Field label="انتخاب کسب‌وکار">
                  <select className="select" value={selected} onChange={(e) => chooseBusiness(e.target.value)}>
                    <option value="">— انتخاب کنید —</option>
                    {businesses.map((b) => (
                      <option key={b.id} value={b.id}>{b.name}</option>
                    ))}
                  </select>
                </Field>
                {selected && (
                  <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                    <button className="btn btn-primary" onClick={() => void syncNow()} disabled={busy}>
                      {busy ? 'در حال همگام‌سازی…' : '🔄 همگام‌سازی'}
                    </button>
                    <button className="btn" onClick={() => void bootstrap()} disabled={busy}>
                      ⬇ بارگذاری از سرور
                    </button>
                    <button className="btn" onClick={() => setInviteOpen(true)}>
                      + افزودن کاربر
                    </button>
                  </div>
                )}
              </>
            )}
          </Card>

          <Card title="وضعیت همگام‌سازی">
            <table>
              <tbody>
                <tr>
                  <td>تغییرات در انتظار ارسال</td>
                  <td className="end num strong">{fa(queue.size())}</td>
                </tr>
                <tr>
                  <td>نشانک همگام‌سازی</td>
                  <td className="end num">{fa(api.syncCursor())}</td>
                </tr>
                <tr>
                  <td>شناسهٔ این دستگاه</td>
                  <td className="end small muted" style={{ direction: 'ltr' }}>
                    {deviceId().slice(0, 8)}…
                  </td>
                </tr>
                {last && (
                  <>
                    <tr>
                      <td>آخرین نتیجه</td>
                      <td className="end">
                        <Badge tone={last.ok ? 'green' : 'red'}>
                          {last.ok ? 'موفق' : 'ناموفق'}
                        </Badge>
                      </td>
                    </tr>
                    <tr>
                      <td>ارسال / دریافت</td>
                      <td className="end num">{fa(last.pushed)} / {fa(last.pulled)}</td>
                    </tr>
                    {last.conflicts > 0 && (
                      <tr>
                        <td>تعارض حل‌شده</td>
                        <td className="end num">{fa(last.conflicts)}</td>
                      </tr>
                    )}
                  </>
                )}
              </tbody>
            </table>
          </Card>
        </>
      )}

      {inviteOpen && selected && (
        <InviteDialog businessId={selected} onClose={() => setInviteOpen(false)} />
      )}
    </div>
  );
}

function InviteDialog({ businessId, onClose }: { businessId: string; onClose: () => void }) {
  const [phone, setPhone] = useState('');
  const [role, setRole] = useState('salesperson');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [done, setDone] = useState(false);

  async function submit() {
    const normalized = normalizePhone(phone);
    if (!normalized) return setError('شمارهٔ موبایل نامعتبر است');
    setBusy(true);
    setError('');
    try {
      await api.addMember(businessId, normalized, role);
      setDone(true);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal
      title="افزودن کاربر به کسب‌وکار"
      onClose={onClose}
      footer={
        done ? (
          <button className="btn btn-primary" onClick={onClose}>بستن</button>
        ) : (
          <>
            <button className="btn btn-primary" onClick={() => void submit()} disabled={busy}>
              {busy ? 'در حال افزودن…' : 'افزودن'}
            </button>
            <button className="btn" onClick={onClose}>انصراف</button>
          </>
        )
      }
    >
      {error && <Banner tone="critical">{error}</Banner>}
      {done ? (
        <Banner tone="success">
          کاربر افزوده شد. با همان شمارهٔ موبایل وارد شود تا به این کسب‌وکار دسترسی پیدا کند.
        </Banner>
      ) : (
        <>
          <Field label="شمارهٔ موبایل">
            <input
              className="input num-input"
              value={phone}
              placeholder="۰۹۱۲۳۴۵۶۷۸۹"
              onChange={(e) => { setPhone(e.target.value); setError(''); }}
              autoFocus
            />
          </Field>
          <Field label="سطح دسترسی">
            <select className="select" value={role} onChange={(e) => setRole(e.target.value)}>
              <option value="owner">مالک — دسترسی کامل</option>
              <option value="accountant">حسابدار — ثبت و گزارش</option>
              <option value="salesperson">فروشنده — ثبت فاکتور</option>
              <option value="viewer">فقط مشاهده</option>
            </select>
          </Field>
        </>
      )}
    </Modal>
  );
}
