import { useState } from 'react'
import { getState, saveState } from '../store'

const WC = [
  { id: '', label: '— پیش‌فرض مرحله —' },
  { id: 'pending', label: 'در انتظار پرداخت' },
  { id: 'processing', label: 'در حال انجام' },
  { id: 'on-hold', label: 'در انتظار بررسی' },
  { id: 'packing', label: 'بسته‌بندی' },
  { id: 'completed', label: 'تکمیل شده' },
  { id: 'delivered', label: 'تحویل شده' },
]

export default function SettingsPage({ state, onToast, onState }) {
  const [s, setS] = useState(state.settings)
  function set(k, v) { setS((x) => ({ ...x, [k]: v })) }
  function save(e) {
    e.preventDefault()
    const next = getState()
    next.settings = s
    saveState(next)
    onState(next)
    onToast('تنظیمات ساینا ذخیره شد')
  }
  return (
    <form onSubmit={save} className="saina-wp p-4 text-sm sm:p-0">
      <h1 className="mb-4 text-xl font-black text-slate-800">به افزونه پیگیری سفارشات ووکامرس ساینا خوش آمدید</h1>

      <Red>نمایش جزئیات سفارش برای کاربران وارد شده (با فعال‌سازی این گزینه کاربران فقط مجاز به دیدن سفارش خودشان می‌باشند)</Red>
      <Check label="فعال سازی" checked={s.ownOrders} onChange={(v) => set('ownOrders', v)} />
      <p className="mb-3 text-xs font-bold text-rose-600">فعال سازی کد کپچا از لحاظ امنیتی این مورد پیشنهاد میشود!</p>
      <label className="mb-3 block">
        <span className="ml-2">فعال سازی کد کپچا</span>
        <select value={s.captcha} onChange={(e) => set('captcha', e.target.value)} className="h-9 rounded border px-2">
          <option value="none">غیرفعال</option>
          <option value="math">کپچای عددی</option>
          <option value="recaptcha2">Google reCAPTCHA v2</option>
          <option value="recaptcha3">Google reCAPTCHA v3</option>
        </select>
      </label>

      <Red>حد هایی که میخواهید با آن جستجوی سفارش انجام شود</Red>
      <p className="mb-2 text-xs text-slate-500">توجه: سفارشاتی که با ایمیل و موبایل جستجو می‌شوند اگر بیش از ۱ سفارش وجود داشته باشد مجموع ۴ سفارش اخیر در فرم پیگیری نمایش داده می‌شود!</p>
      <div className="mb-3 flex flex-wrap gap-4">
        <Check label="شماره سفارش" checked={s.searchOrder} onChange={(v) => set('searchOrder', v)} />
        <Check label="شماره موبایل" checked={s.searchMobile} onChange={(v) => set('searchMobile', v)} />
        <Check label="ایمیل" checked={s.searchEmail} onChange={(v) => set('searchEmail', v)} />
      </div>

      <Check label="ارسال اطلاعات به صورت ایجکسی. در صورتی که در قسمت فرم چیزی نمایش داده نشد و یا بهم‌ریختگی بوجود آمد این تیک را بردارید؛ قالب شما پشتیبانی نمی‌کند" checked={s.ajaxSearch} onChange={(v) => set('ajaxSearch', v)} />
      <Check label="اگر میخواهید فرم پیگیری پست به صورت تب جدید باز شود فعال کنید" checked={s.postNewTab} onChange={(v) => set('postNewTab', v)} />
      <Check label="غیرفعال سازی پیگیری محصولات دانلودی و مجازی" checked={s.disableVirtual} onChange={(v) => set('disableVirtual', v)} />
      <Check label="غیرفعال سازی نوار پیشرفت در سفارشات کاربری" checked={s.disableProgressAccount} onChange={(v) => set('disableProgressAccount', v)} />
      <Check label="غیرفعال سازی نوار پیشرفت در قسمت صفحه تشکر" checked={s.disableProgressThanks} onChange={(v) => set('disableProgressThanks', v)} />
      <Check label="غیرفعال سازی ستون آیکن ها در قسمت سفارشات کاربری" checked={s.disableIconsColumn} onChange={(v) => set('disableIconsColumn', v)} />
      <Check label="فعال سازی درج کد رهگیری برای فروشندگان دکان" checked={s.dokanTracking} onChange={(v) => set('dokanTracking', v)} />
      <Check label="اگر نمیخواهید در فرم پیگیری کاربر شماره سفارش یا شماره موبایل یا ایمیل سفارششان را تکمیل نمایند این گزینه را فعال کنید" checked={s.skipRequired} onChange={(v) => set('skipRequired', v)} />
      <p className="mb-3 text-xs text-slate-500">در برخی قالب‌ها زمانی که تکمیل‌شده در مرحله تکمیل‌شده به نوار پیشرفت چک‌مارک با بهم‌ریختگی به‌وجود آید، در این صورت این گزینه را فعال کنید.</p>

      <label className="mb-4 block">
        <span className="mb-1 block font-bold">متن سفارشی فرم پیگیری</span>
        <input value={s.formPlaceholder} onChange={(e) => set('formPlaceholder', e.target.value)} className="h-10 w-full rounded border px-3" />
      </label>

      <p className="mb-3 text-xs leading-6 text-slate-500">شما می‌توانید با استفاده از این قسمت تکمیل بودن نوار پیشرفت را تغییر دهید. در صورتی که وضعیتی انتخاب ننمایید از وضعیت‌های پیش‌فرض پیروی خواهد شد. برای فعال شدن وضعیت جدید، پلاگین‌های جانبی هم وضعیت را فعال نمایید.</p>

      <table className="mb-4 w-full border text-xs">
        <thead className="bg-slate-50"><tr><th className="p-2 text-right">مرحله نوار</th><th className="p-2">وضعیت ووکامرس</th><th className="p-2">گزینه</th></tr></thead>
        <tbody>
          <StepRow title="انجام وضعیت‌ها در مرحله ۱ — در حال انجام" value={s.step1Status} onChange={(v) => set('step1Status', v)} />
          <StepRow title="انجام وضعیت‌ها در مرحله ۲ — در حال بررسی" value={s.step2Status} onChange={(v) => set('step2Status', v)} />
          <StepRow title="انجام وضعیت‌ها در مرحله ۳ — بسته‌بندی" value={s.step3Status} onChange={(v) => set('step3Status', v)} />
          <StepRow title="انجام وضعیت‌ها در مرحله ۴ — تکمیل شده" value={s.step4Status} onChange={(v) => set('step4Status', v)} extra={<Check label="تحویل به پست" checked={s.step4ToPost} onChange={(v) => set('step4ToPost', v)} />} />
          <StepRow title="انجام وضعیت‌ها در مرحله ۵ — تحویل شده" value={s.step5Status} onChange={(v) => set('step5Status', v)} extra={<Check label="تحویل شده" checked={s.step5Delivered} onChange={(v) => set('step5Delivered', v)} />} />
        </tbody>
      </table>

      <Check label="فعال کردن تحویل شده" checked={s.enableDelivered} onChange={(v) => set('enableDelivered', v)} />
      <Check label="غیرفعال سازی صحت دریافت محصول در صفحه سفارشات کاربر" checked={s.disableConfirm} onChange={(v) => set('disableConfirm', v)} />
      <p className="mb-3 text-xs">شورتکدها: <code className="rounded bg-slate-100 px-1">{'{order_id}'}</code> <code className="rounded bg-slate-100 px-1">{'{trackingurl}'}</code> <code className="rounded bg-slate-100 px-1">{'{username}'}</code> <code className="rounded bg-slate-100 px-1">{'{senddate}'}</code> <code className="rounded bg-slate-100 px-1">{'{deliverydate}'}</code> <code className="rounded bg-slate-100 px-1">{'{peyk}'}</code></p>

      <Text label="متن تولتیپ تکمیل شده (یا مرحله ۳)" value={s.tooltipCompleted} onChange={(v) => set('tooltipCompleted', v)} />
      <Text label="متن تولتیپ تحویل شده (یا مرحله ۵)" value={s.tooltipDelivered} onChange={(v) => set('tooltipDelivered', v)} />
      <Text label="متن تولتیپ تکمیل شده برای پیک (یا مرحله ۴)" value={s.tooltipPeykCompleted} onChange={(v) => set('tooltipPeykCompleted', v)} />
      <Text label="متن تولتیپ تحویل شده برای پیک (یا مرحله ۵)" value={s.tooltipPeykDelivered} onChange={(v) => set('tooltipPeykDelivered', v)} />

      <p className="mb-2 text-xs text-slate-600">در این قسمت می‌توانید متن پیامکی که برای پیک ارسال می‌گردد را وارد نمایید. توجه کنید این پیام جایگزین پیامک تکمیل شده یا وضعیتی که در زیر انتخاب می‌کنید برای مشتری می‌باشد</p>
      <select value={s.peykSmsStatus} onChange={(e) => set('peykSmsStatus', e.target.value)} className="mb-2 h-9 rounded border px-2">
        {WC.map((o) => <option key={o.id} value={o.id}>{o.label}</option>)}
      </select>
      <textarea value={s.peykSmsText} onChange={(e) => set('peykSmsText', e.target.value)} className="mb-3 h-20 w-full rounded border p-2 text-xs" />

      <Text label="شهرها و شهرستان‌هایی که می‌خواهید سیستم پیک در آن فعال شود" value={s.peykCities} onChange={(v) => set('peykCities', v)} placeholder="تهران، کرج، اصفهان" />
      <Text label="روش حمل و نقلی که می‌خواهید برای سیستم پیک در آن فعال شود" value={s.peykMethod} onChange={(v) => set('peykMethod', v)} placeholder="پیک موتوری" />
      <Check label="چک باکسی در سطح کشور اضافه (شهرها یا مشتری)" checked={s.peykNationwide} onChange={(v) => set('peykNationwide', v)} />

      <Red>نمایش جزئیات مرسوله</Red>
      <div className="mb-3 grid grid-cols-2 gap-2 sm:grid-cols-3">
        <Check label="کاربر" checked={s.showUser} onChange={(v) => set('showUser', v)} />
        <Check label="روش پرداخت" checked={s.showPayment} onChange={(v) => set('showPayment', v)} />
        <Check label="مقصد" checked={s.showDestination} onChange={(v) => set('showDestination', v)} />
        <Check label="مبلغ پرداخت" checked={s.showAmount} onChange={(v) => set('showAmount', v)} />
        <Check label="نمایش تصویر محصول" checked={s.showProductImage} onChange={(v) => set('showProductImage', v)} />
        <Check label="نمایش نام محصول" checked={s.showProductName} onChange={(v) => set('showProductName', v)} />
        <Check label="نمایش حالت در کنار نوار وضعیت‌ها" checked={s.showStateBeside} onChange={(v) => set('showStateBeside', v)} />
        <Check label="ساخت تصویر پیشرفت مشترک" checked={s.sharedProgressImage} onChange={(v) => set('sharedProgressImage', v)} />
        <Check label="بارگذاری تصویر در فرم پیگیری" checked={s.uploadFormImage} onChange={(v) => set('uploadFormImage', v)} />
      </div>

      <Text label="آدرس لوگو (URL)" value={s.logo} onChange={(v) => set('logo', v)} />
      <label className="mb-3 block">اندازه آیکن نوار پیشرفت (۱۵ تا ۱۵۰)
        <input type="number" min="15" max="150" value={s.iconSize} onChange={(e) => set('iconSize', Number(e.target.value))} className="mr-2 h-9 w-24 rounded border px-2" />
      </label>
      <div className="mb-4 grid gap-2 sm:grid-cols-2">
        <Color label="رنگ نوار پیشرفت استایل نوین" value={s.colorProgress} onChange={(v) => set('colorProgress', v)} />
        <Color label="رنگ دکمه و فیلد فرم پیگیری" value={s.colorFormBtn} onChange={(v) => set('colorFormBtn', v)} />
        <Color label="رنگ هدر جدول جزئیات کاربر" value={s.colorTableHeader} onChange={(v) => set('colorTableHeader', v)} />
        <Color label="رنگ متن هدر جدول جزئیات کاربر" value={s.colorTableHeaderText} onChange={(v) => set('colorTableHeaderText', v)} />
        <Color label="رنگ دکمه پیگیری از پست" value={s.colorPostBtn} onChange={(v) => set('colorPostBtn', v)} />
        <Color label="رنگ متن دکمه پیگیری از پست" value={s.colorPostBtnText} onChange={(v) => set('colorPostBtnText', v)} />
      </div>

      <label className="mb-3 block">انتخاب استایل نوار پیشرفت
        <select value={s.progressStyle} onChange={(e) => set('progressStyle', e.target.value)} className="mr-2 h-9 rounded border px-2">
          <option value="digi">استایل دیجی نوین</option>
          <option value="classic">کلاسیک</option>
          <option value="minimal">مینیمال</option>
        </select>
      </label>
      <label className="mb-3 block">محل نمایش نوار پیشرفت
        <select value={s.progressPosition} onChange={(e) => set('progressPosition', e.target.value)} className="mr-2 h-9 rounded border px-2">
          <option value="before">قبل از جزئیات سفارش</option>
          <option value="after">بعد از جزئیات سفارش</option>
        </select>
      </label>
      <p className="mb-3 text-xs text-slate-500">انتخاب نمایش نوار پیشرفت بعد از فیل جزئیات سفارش (این مورد بستگی به قالب شما دارد؛ اگر از فیل جزئیات سفارش بهم‌ریختگی دارد شامل پشتیبانی نمی‌شود)</p>

      <Check label="فعال سازی تقویم شمسی در صفحه سفارش" checked={s.jalaliCalendar} onChange={(v) => set('jalaliCalendar', v)} />
      <p className="mb-3 text-xs text-slate-500">در صورت تداخل تقویم شمسی با سایر افزونه‌های شمسی این گزینه را غیرفعال کنید</p>
      <Check label="فعال سازی خودکار تغییر وضعیت به تحویل شده سفارشات" checked={s.autoDeliver} onChange={(v) => set('autoDeliver', v)} />
      <label className="mb-3 block text-xs">از این قسمت تعیین کنید سفارشات تکمیل شده پس از چند روز به وضعیت تحویل شده تغییر وضعیت دهد (از یک ماه اخیر در نظر گرفته می‌شود). تعداد روز:
        <input type="number" min="1" value={s.autoDeliverDays} onChange={(e) => set('autoDeliverDays', Number(e.target.value))} className="mr-2 h-8 w-16 rounded border px-2" />
      </label>
      <Check label="اگر از افزونه حمل و نقل تاپین که در مخزن وردپرس موجود است استفاده می‌کنید و کدهای رهگیری که توسط تاپین دریافت می‌شود را می‌خواهید در فیلد کد رهگیری سفارشات اضافه کنید، فعال کنید (این مورد هنگامی‌که کدهای مرسوله دریافت شده باشند و بعد از آن تغییر وضعیت تکمیل شده فعال می‌شود. تاریخ ارسال لحظه تغییر وضعیت تکمیل و نوع فرم پست پیشتاز انتخاب می‌شود)" checked={s.tapinSync} onChange={(v) => set('tapinSync', v)} />
      <Check label="درج جزئیات ارسال در ایمیل ووکامرس" checked={s.emailEmbed} onChange={(v) => set('emailEmbed', v)} />

      <button className="mt-4 rounded bg-[#2271b1] px-5 py-2 text-sm font-bold text-white">ذخیره تغییرات</button>
    </form>
  )
}

function Red({ children }) {
  return <p className="mb-2 mt-5 font-bold text-rose-600">{children}</p>
}
function Check({ label, checked, onChange }) {
  return (
    <label className="mb-2 flex items-start gap-2 text-xs leading-6">
      <input type="checkbox" className="mt-1" checked={!!checked} onChange={(e) => onChange(e.target.checked)} />
      <span>{label}</span>
    </label>
  )
}
function Text({ label, value, onChange, placeholder }) {
  return (
    <label className="mb-3 block text-xs">
      <span className="mb-1 block font-bold">{label}</span>
      <input value={value || ''} placeholder={placeholder} onChange={(e) => onChange(e.target.value)} className="h-10 w-full rounded border px-3" />
    </label>
  )
}
function Color({ label, value, onChange }) {
  return (
    <label className="flex items-center justify-between gap-2 text-xs">
      <span>{label}</span>
      <input type="color" value={value} onChange={(e) => onChange(e.target.value)} />
    </label>
  )
}
function StepRow({ title, value, onChange, extra }) {
  return (
    <tr className="border-t">
      <td className="p-2">{title}</td>
      <td className="p-2">
        <select value={value} onChange={(e) => onChange(e.target.value)} className="h-8 w-full rounded border px-1">
          {WC.map((o) => <option key={o.id} value={o.id}>{o.label}</option>)}
        </select>
      </td>
      <td className="p-2">{extra}</td>
    </tr>
  )
}
