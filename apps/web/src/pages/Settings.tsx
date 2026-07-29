import React, { useState } from 'react';
import {
  createBackup, parseBackup, serializeBackup, subscriptionNotice, toExcelXML,
  toPersianDigits, type Business, type CostingMethod,
} from '@javid/core';
import { clearDB, queue, type DB } from '../store';
import { Badge, Banner, Card, Field, JDate, Modal, download } from '../ui';

export function Settings({ db, setDB }: { db: DB; setDB: (d: DB) => void }) {
  const [biz, setBiz] = useState<Business>(db.business);
  const [saved, setSaved] = useState(false);
  const [confirmReset, setConfirmReset] = useState(false);
  const notice = subscriptionNotice(db.subscription, new Date());

  function save() {
    setDB({ ...db, business: biz });
    setSaved(true);
    setTimeout(() => setSaved(false), 2500);
  }

  function exportAll() {
    const backup = createBackup(db.business, {
      parties: db.parties,
      products: db.products,
      invoices: db.invoices,
      transactions: db.transactions,
      cheques: db.cheques,
      treasuries: db.treasuries,
      entries: db.entries,
      movements: db.movements,
      accounts: db.accounts,
    });
    download(`javid-backup-${new Date().toISOString().slice(0, 10)}.json`, serializeBackup(backup), 'application/json');
  }

  function exportExcel() {
    const xml = toExcelXML([
      {
        name: 'اشخاص',
        rows: db.parties as never[],
        columns: [
          { key: 'name', header: 'نام', value: (p: never) => (p as { name: string }).name },
          { key: 'phone', header: 'تلفن', value: (p: never) => (p as { phone?: string }).phone ?? '' },
        ],
      },
      {
        name: 'کالاها',
        rows: db.products as never[],
        columns: [
          { key: 'name', header: 'نام', value: (p: never) => (p as { name: string }).name },
          { key: 'sell', header: 'قیمت فروش', value: (p: never) => (p as { sellPrice: number }).sellPrice },
        ],
      },
      {
        name: 'فاکتورها',
        rows: db.invoices as never[],
        columns: [
          { key: 'number', header: 'شماره', value: (i: never) => (i as { number: string }).number },
          { key: 'date', header: 'تاریخ', value: (i: never) => (i as { date: string }).date },
        ],
      },
    ]);
    download(`javid-export-${new Date().toISOString().slice(0, 10)}.xls`, xml, 'application/vnd.ms-excel');
  }

  function importBackup(file: File) {
    const reader = new FileReader();
    reader.onload = () => {
      try {
        const b = parseBackup(String(reader.result));
        const d = b.data as Record<string, never[]>;
        setDB({
          ...db,
          business: (b.business as Business) ?? db.business,
          parties: d.parties ?? [],
          products: d.products ?? [],
          invoices: d.invoices ?? [],
          transactions: d.transactions ?? [],
          cheques: d.cheques ?? [],
          treasuries: d.treasuries ?? db.treasuries,
          entries: d.entries ?? [],
          movements: d.movements ?? [],
          accounts: d.accounts ?? db.accounts,
        });
        alert('اطلاعات با موفقیت بازیابی شد.');
      } catch (e) {
        alert(`بازیابی ناموفق بود: ${(e as Error).message}`);
      }
    };
    reader.readAsText(file);
  }

  return (
    <div style={{ display: 'grid', gap: 18, maxWidth: 860 }}>
      {notice.level !== 'none' && (
        <Banner tone={notice.level === 'expired' || notice.level === 'critical' ? 'critical' : notice.level === 'warning' ? 'warning' : 'info'}>
          {notice.message}
        </Banner>
      )}

      <Card title="مشخصات کسب‌وکار" action={saved && <Badge tone="green">✓ ذخیره شد</Badge>}>
        <div className="row">
          <Field label="نام کسب‌وکار">
            <input className="input" value={biz.name} onChange={(e) => setBiz({ ...biz, name: e.target.value })} />
          </Field>
          <Field label="تلفن">
            <input className="input num-input" value={biz.phone ?? ''} onChange={(e) => setBiz({ ...biz, phone: e.target.value })} />
          </Field>
        </div>

        <Field label="آدرس">
          <textarea className="input" rows={2} value={biz.address ?? ''} onChange={(e) => setBiz({ ...biz, address: e.target.value })} />
        </Field>

        <div className="row">
          <Field label="کد اقتصادی">
            <input className="input num-input" value={biz.economicCode ?? ''} onChange={(e) => setBiz({ ...biz, economicCode: e.target.value })} />
          </Field>
          <Field label="شناسهٔ ملی">
            <input className="input num-input" value={biz.nationalId ?? ''} onChange={(e) => setBiz({ ...biz, nationalId: e.target.value })} />
          </Field>
        </div>

        <button className="btn btn-primary" onClick={save}>ذخیرهٔ تغییرات</button>
      </Card>

      <Card title="تنظیمات مالی">
        <div className="row">
          <Field label="روش قیمت‌گذاری انبار" hint="پس از ثبت فاکتور تغییر آن توصیه نمی‌شود">
            <select
              className="select"
              value={biz.costingMethod}
              onChange={(e) => setBiz({ ...biz, costingMethod: e.target.value as CostingMethod })}
            >
              <option value="fifo">فایفو — اولین ورودی، اولین خروجی</option>
              <option value="lifo">لایفو — آخرین ورودی، اولین خروجی</option>
              <option value="weighted_average">میانگین موزون</option>
            </select>
          </Field>
          <Field label="نرخ پیش‌فرض مالیات (٪)">
            <input
              className="input num-input"
              value={biz.defaultVatRate}
              onChange={(e) => setBiz({ ...biz, defaultVatRate: Number(e.target.value) || 0 })}
            />
          </Field>
        </div>

        <div className="row">
          <Field label="ماه شروع سال مالی">
            <select
              className="select"
              value={biz.fiscalYearStartMonth}
              onChange={(e) => setBiz({ ...biz, fiscalYearStartMonth: Number(e.target.value) })}
            >
              {['فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', 'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند']
                .map((m, i) => <option key={i} value={i + 1}>{m}</option>)}
            </select>
          </Field>
          <Field label="واحد پول">
            <select
              className="select"
              value={biz.currencyUnit}
              onChange={(e) => setBiz({ ...biz, currencyUnit: e.target.value as 'rial' | 'toman' })}
            >
              <option value="toman">تومان</option>
              <option value="rial">ریال</option>
            </select>
          </Field>
        </div>

        <button className="btn btn-primary" onClick={save}>ذخیرهٔ تغییرات</button>
      </Card>

      <Card title="اطلاعات شما، متعلق به شماست">
        <Banner tone="success" title="تعهد جاوید">
          دریافت خروجی از اطلاعات هرگز به اشتراک فعال نیاز ندارد. حتی پس از پایان اشتراک،
          می‌توانید کل داده‌های کسب‌وکارتان را کامل دریافت کنید.
        </Banner>

        <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', marginTop: 4 }}>
          <button className="btn btn-primary" onClick={exportAll}>⬇ دریافت کل اطلاعات (JSON)</button>
          <button className="btn" onClick={exportExcel}>⬇ خروجی اکسل</button>
          <label className="btn" style={{ cursor: 'pointer' }}>
            ⬆ بازیابی از فایل پشتیبان
            <input
              type="file"
              accept="application/json"
              style={{ display: 'none' }}
              onChange={(e) => {
                const f = e.target.files?.[0];
                if (f) importBackup(f);
                e.target.value = '';
              }}
            />
          </label>
        </div>
      </Card>

      <Card title="وضعیت اشتراک">
        <table>
          <tbody>
            <tr><td>پلن</td><td className="end strong">{db.subscription.plan === 'trial' ? 'دورهٔ آزمایشی' : db.subscription.plan}</td></tr>
            <tr><td>تاریخ انقضا</td><td className="end"><JDate value={db.subscription.expiresAt} style="long" /></td></tr>
            <tr>
              <td>وضعیت نوشتن</td>
              <td className="end">
                <Badge tone={notice.canWrite ? 'green' : 'red'}>
                  {notice.canWrite ? 'فعال' : 'قفل'}
                </Badge>
              </td>
            </tr>
            <tr>
              <td>وضعیت خواندن و خروجی</td>
              <td className="end"><Badge tone="green">همیشه آزاد</Badge></td>
            </tr>
          </tbody>
        </table>
      </Card>

      <Card title="همگام‌سازی">
        <table>
          <tbody>
            <tr>
              <td>تغییرات در انتظار ارسال</td>
              <td className="end num strong">{toPersianDigits(queue.size())}</td>
            </tr>
            <tr>
              <td>محل ذخیره</td>
              <td className="end small muted">حافظهٔ محلی این دستگاه</td>
            </tr>
          </tbody>
        </table>
        <div className="small muted" style={{ marginTop: 10 }}>
          جاوید آفلاین-اول است: همهٔ اطلاعات ابتدا روی دستگاه شما ذخیره می‌شود و
          قطعی اینترنت مانع ثبت فاکتور نمی‌شود.
        </div>
      </Card>

      <Card title="منطقهٔ خطر">
        <p className="small muted" style={{ marginBottom: 12 }}>
          پاک کردن اطلاعات این دستگاه غیرقابل بازگشت است. پیش از آن حتماً خروجی بگیرید.
        </p>
        <button className="btn btn-danger" onClick={() => setConfirmReset(true)}>پاک کردن همهٔ اطلاعات</button>
      </Card>

      {confirmReset && (
        <Modal
          title="پاک کردن همهٔ اطلاعات"
          onClose={() => setConfirmReset(false)}
          footer={
            <>
              <button
                className="btn btn-danger"
                onClick={() => { clearDB(); location.reload(); }}
              >بله، پاک کن</button>
              <button className="btn" onClick={() => setConfirmReset(false)}>انصراف</button>
            </>
          }
        >
          <Banner tone="critical" title="این عمل قابل بازگشت نیست">
            همهٔ فاکتورها، اشخاص، کالاها و اسناد حسابداری از این دستگاه پاک می‌شوند.
          </Banner>
          <button className="btn btn-primary" onClick={exportAll}>⬇ ابتدا خروجی بگیرید</button>
        </Modal>
      )}
    </div>
  );
}
