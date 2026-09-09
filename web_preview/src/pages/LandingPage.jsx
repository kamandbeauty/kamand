import {
  MessageSquare,
  Search,
  PackageCheck,
  Mail,
  Shield,
  FileSpreadsheet,
  Truck,
  Sparkles,
  BadgeCheck,
  Smartphone,
} from 'lucide-react'
import { ProgressBar } from '../components'
import { getState } from '../store'

const FEATURES = [
  { icon: MessageSquare, title: 'ارسال کد رهگیری با پیامک', desc: 'هماهنگ با افزونه پیامک ووکامرس فارسی؛ شورتکد کد رهگیری، حامل، تاریخ ارسال و تحویل.' },
  { icon: Search, title: 'فرم پیگیری مشتری', desc: 'جستجو با شماره سفارش، موبایل، ایمیل یا ترکیب آن‌ها به‌همراه Ajax و کپچا.' },
  { icon: PackageCheck, title: 'نوار پیشرفت ۵ مرحله‌ای', desc: 'از دریافت تا تحویل، با وضعیت بسته‌بندی و تحویل‌شده، رنگ و نام قابل‌سفارشی.' },
  { icon: Mail, title: 'درج در ایمیل ووکامرس', desc: 'جزئیات ارسال به ایمیل وضعیت تکمیل‌شده اضافه می‌شود؛ بدون ایمیل جداگانه.' },
  { icon: FileSpreadsheet, title: 'درج گروهی و اکسل', desc: 'ثبت کد رهگیری دسته‌جمعی در پیشخوان و درون‌ریزی CSV/Excel بر اساس شماره سفارش.' },
  { icon: Truck, title: 'پست، چاپار و تیپاکس', desc: 'دکمه پیگیری خودکار با پر شدن کد مرسوله در فرم شرکت حمل‌ونقل.' },
  { icon: Shield, title: 'کپچای عددی و گوگل', desc: 'محافظت فرم در برابر جستجوی جعلی با کپچای ریاضی و reCAPTCHA نسخه ۲ و ۳.' },
  { icon: Smartphone, title: 'حساب کاربری و آیکن وضعیت', desc: 'نوار پیشرفت و تولتیپ جزئیات ارسال در سفارش‌های من و لیست سفارشات مدیر.' },
]

export default function LandingPage({ onOpen }) {
  const sample = getState().orders.find((o) => o.id === 1042)
  const settings = getState().settings
  return (
    <div className="mx-auto max-w-6xl px-4 py-8">
      <section className="grid items-center gap-8 lg:grid-cols-2">
        <div>
          <div className="mb-3 inline-flex items-center gap-2 rounded-full bg-saina-50 px-3 py-1 text-xs font-bold text-saina-800">
            <Sparkles size={14} /> افزونه ووکامرس · نسخه ۱.۰.۰
          </div>
          <h1 className="text-3xl font-black leading-snug text-slate-900 sm:text-4xl">
            ساینا؛ پیگیری سفارشات ووکامرس
            <span className="block text-saina-700">با نوار پیشرفت و کد رهگیری پستی</span>
          </h1>
          <p className="mt-4 text-sm leading-7 text-slate-600">
            مشابه افزونه نوین ترک‌اوردر، ساینا مدیریت حمل‌ونقل فروشگاه را ساده می‌کند: ثبت کد رهگیری، پیامک و ایمیل، فرم جستجوی مشتری، وضعیت بسته‌بندی و تحویل، و پیگیری از پست ایران، چاپار و تیپاکس.
          </p>
          <div className="mt-6 flex flex-wrap gap-3">
            <button onClick={() => onOpen('track')} className="rounded-2xl bg-saina-700 px-5 py-3 text-sm font-bold text-white shadow-card">
              امتحان فرم پیگیری
            </button>
            <button onClick={() => onOpen('admin')} className="rounded-2xl border border-saina-200 bg-white px-5 py-3 text-sm font-bold text-saina-800">
              پیشخوان مدیر
            </button>
          </div>
          <div className="mt-5 text-xs text-slate-500">
            شورتکد صفحه پیگیری: <code className="rounded bg-slate-100 px-1.5 py-0.5 font-mono">[saina_track_order]</code>
          </div>
        </div>
        <div className="relative">
          <img src="/saina-hero.png" alt="نمای مسیر سفارش ساینا" className="w-full rounded-[28px] border border-saina-100 shadow-card" />
        </div>
      </section>

      <section className="mt-10 rounded-3xl border border-saina-100 bg-white p-5 shadow-soft">
        <div className="mb-4 text-sm font-bold">پیش‌نمایش زنده نوار پیشرفت</div>
        {sample && <ProgressBar order={sample} statuses={settings.statuses} />}
      </section>

      <section className="mt-10 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {FEATURES.map((f) => (
          <div key={f.title} className="rounded-3xl border border-slate-100 bg-white p-4 shadow-soft">
            <div className="mb-3 flex h-10 w-10 items-center justify-center rounded-2xl bg-saina-50 text-saina-700">
              <f.icon size={18} />
            </div>
            <div className="text-sm font-bold text-slate-900">{f.title}</div>
            <p className="mt-1 text-xs leading-6 text-slate-500">{f.desc}</p>
          </div>
        ))}
      </section>

      <section className="mt-10 grid gap-4 lg:grid-cols-3">
        <Guide
          title="برای مشتری"
          items={[
            'پیگیری با شماره سفارش، موبایل یا ایمیل',
            'نمایش ۴ سفارش آخر در جستجوی موبایل/ایمیل',
            'تولتیپ تاریخ تغییر هر وضعیت',
            'دکمه «کالا را تحویل گرفتم»',
          ]}
        />
        <Guide
          title="برای مدیر فروشگاه"
          items={[
            'متاباکس کد رهگیری با تقویم شمسی',
            'درج گروهی و درون‌ریزی اکسل',
            'وضعیت بسته‌بندی و تحویل‌شده',
            'آیکن جزئیات ارسال در لیست سفارشات',
          ]}
        />
        <Guide
          title="شورتکدهای پیامک"
          items={[
            '{tracking_code} کد مرسوله',
            '{carrier} سیستم حمل‌ونقل',
            '{ship_date} تاریخ ارسال',
            '{delivery_date} تاریخ تحویل',
          ]}
        />
      </section>

      <div className="mt-10 flex items-center justify-center gap-2 text-xs text-slate-400">
        <BadgeCheck size={14} className="text-saina-600" />
        سازگار با ووکامرس، HPOS، دکان، پیامک ووکامرس فارسی، تاپین و افزونه حمل مسیر
      </div>
    </div>
  )
}

function Guide({ title, items }) {
  return (
    <div className="rounded-3xl bg-saina-950 p-5 text-saina-50">
      <div className="mb-3 text-sm font-bold text-white">{title}</div>
      <ul className="space-y-2 text-xs leading-6 text-saina-100">
        {items.map((it) => (
          <li key={it} className="flex gap-2">
            <span className="mt-1.5 h-1.5 w-1.5 shrink-0 rounded-full bg-saina-400" />
            {it}
          </li>
        ))}
      </ul>
    </div>
  )
}
