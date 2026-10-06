import { useState } from 'react';
import { fa } from '../persian.js';
import { GlassCard } from './Glass.jsx';

const PLANS = [
  { id: 'monthly', label: 'ماهانه', price: '۹۸٬۰۰۰', note: 'هر ماه' },
  { id: 'yearly', label: 'سالانه', price: '۴۹۰٬۰۰۰', note: 'دو ماه رایگان' },
  { id: 'lifetime', label: 'یک‌بار برای همیشه', price: '۱٬۲۰۰٬۰۰۰', note: 'پرداخت یک‌باره' },
];

const FEATURES = [
  ['تحلیل کامل روزانه', 'همهٔ بخش‌ها بدون محدودیت، هر روز'],
  ['تحلیل عمیق شخصیت', 'لایه‌های پنهان برج تو'],
  ['تحلیل کامل رابطه', 'جزئیاتِ همهٔ ابعاد سازگاری'],
  ['چارت تولد', 'موقعیت سیارات و خانه‌ها (به‌زودی)'],
  ['طالع ماهانهٔ پیشرفته', 'برنامه‌ریزی ماه با تقویم شمسی'],
  ['بدون هیچ محدودیتی', 'همهٔ قابلیت‌ها، برای همیشه'],
];

export function PremiumSheet({ premium, onSubscribe, onClose }) {
  const [plan, setPlan] = useState('yearly');
  return (
    <div className="space-y-4">
      <div className="relative overflow-hidden rounded-3xl border border-gold-400/30 bg-gradient-to-b from-gold-400/[0.14] to-transparent p-5 text-center">
        <div className="absolute -left-10 -top-10 h-32 w-32 rounded-full bg-gold-400/20 blur-2xl" />
        <p className="gold-text text-xl font-black">طالع من ویژه</p>
        <p className="mt-2 text-[11px] leading-6 text-slate-400">
          تجربهٔ کامل طالع‌بینی، بدون محدودیت — پشتیبانی از توسعهٔ مستقل این
          اپلیکیشن ایرانی
        </p>
      </div>

      {premium ? (
        <GlassCard className="text-center">
          <p className="text-[13px] font-extrabold text-emerald-300">اشتراک ویژه فعال است</p>
          <p className="mt-2 text-[11px] leading-6 text-slate-400">
            از همهٔ قابلیت‌ها لذت ببر. مرسی که حمایت می‌کنی.
          </p>
        </GlassCard>
      ) : (
        <>
          <div className="space-y-2">
            {FEATURES.map(([title, note]) => (
              <div key={title} className="flex items-start gap-2.5 px-1">
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" className="mt-0.5 shrink-0 text-gold-300" aria-hidden>
                  <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="1.5" opacity="0.4" />
                  <path d="M8 12.5l2.5 2.5L16 9.5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
                </svg>
                <div>
                  <p className="text-[12px] font-bold text-slate-100">{title}</p>
                  <p className="text-[10px] text-slate-500">{note}</p>
                </div>
              </div>
            ))}
          </div>

          <div className="space-y-2">
            {PLANS.map((p) => (
              <button
                key={p.id}
                onClick={() => setPlan(p.id)}
                aria-pressed={plan === p.id}
                className={`flex w-full items-center justify-between rounded-2xl border px-4 py-3.5 text-right transition ${
                  plan === p.id
                    ? 'border-gold-400/60 bg-gold-400/10'
                    : 'border-white/10 bg-white/[0.04] hover:bg-white/[0.07]'
                }`}
              >
                <div>
                  <p className={`text-[13px] font-bold ${plan === p.id ? 'text-gold-200' : 'text-slate-200'}`}>
                    {p.label}
                  </p>
                  <p className="mt-0.5 text-[10px] text-slate-500">{p.note}</p>
                </div>
                <p className="text-[13px] font-black text-gold-300">
                  {p.price} <span className="text-[9px] font-normal text-slate-400">تومان</span>
                </p>
              </button>
            ))}
          </div>

          <button className="btn-primary w-full" onClick={() => onSubscribe(plan)}>
            فعال‌سازی اشتراک ویژه
          </button>
          <p className="text-center text-[9px] leading-5 text-slate-500">
            در این پیش‌نمایش وب، خرید شبیه‌سازی شده است و پرداختی انجام نمی‌شود.
            در نسخهٔ اندروید از پرداخت درون‌برنامه‌ای گوگل‌پلی استفاده می‌شود.
          </p>
        </>
      )}
    </div>
  );
}
