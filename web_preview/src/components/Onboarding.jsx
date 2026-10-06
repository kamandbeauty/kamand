import { useMemo, useState } from 'react';
import CITIES from '../cities.json';
import {
  todayJalali,
  isJalaliValid,
  jalaliMonthLength,
  zodiacForGregorian,
  jalaliToGregorian,
} from '../engine.js';
import { fa, JALALI_MONTHS } from '../persian.js';
import { GlassCard } from './Glass.jsx';
import StarField from './StarField.jsx';

const YEARS = Array.from({ length: 100 }, (_, i) => todayJalali()[0] - i);

export default function Onboarding({ onFinish, onSkipAll }) {
  const [step, setStep] = useState(0); // 0 welcome … 6 notification
  const [name, setName] = useState('');
  const [y, setY] = useState(todayJalali()[0] - 25);
  const [m, setM] = useState(1);
  const [d, setD] = useState(1);
  const [timeKnown, setTimeKnown] = useState(false);
  const [hour, setHour] = useState(12);
  const [minute, setMinute] = useState(0);
  const [city, setCity] = useState('');

  const sign = useMemo(() => {
    if (!isJalaliValid(y, m, d)) return null;
    const g = jalaliToGregorian([y, m, d]);
    return zodiacForGregorian(g.getMonth() + 1, g.getDate());
  }, [y, m, d]);

  const dayCount = isJalaliValid(y, m, 1) ? jalaliMonthLength(y, m) : 31;

  const finish = (notifications) =>
    onFinish({ name: name.trim(), y, m, d, timeKnown: timeKnown, time: timeKnown ? [hour, minute] : null, city: city || null, notifications });

  return (
    <div className="relative flex min-h-0 flex-1 flex-col px-6 pb-6 pt-8">
      <StarField className="opacity-90" />

      {step > 0 && step < 6 && (
        <button
          onClick={() => setStep(step + 1)}
          className="absolute left-6 top-8 z-20 text-xs font-medium text-slate-400 transition hover:text-slate-200"
        >
          رد کردن
        </button>
      )}

      <div key={step} className="animate-fade-up relative z-10 flex min-h-0 flex-1 flex-col">
        {step === 0 && (
          <Welcome onBegin={() => setStep(1)} />
        )}
        {step === 1 && (
          <NameStep name={name} setName={setName} onNext={() => setStep(2)} />
        )}
        {step === 2 && (
          <DateStep
            y={y} m={m} d={d} setY={setY} setM={setM} setD={setD}
            dayCount={dayCount} valid={!!sign}
            onNext={() => setStep(3)}
          />
        )}
        {step === 3 && (
          <TimeStep
            timeKnown={timeKnown} setTimeKnown={setTimeKnown}
            hour={hour} minute={minute} setHour={setHour} setMinute={setMinute}
            onNext={() => setStep(4)}
          />
        )}
        {step === 4 && (
          <CityStep city={city} setCity={setCity} onNext={() => setStep(5)} />
        )}
        {step === 5 && sign && (
          <ResultStep
            sign={sign} name={name}
            onNext={() => setStep(6)}
          />
        )}
        {step === 6 && (
          <NotifyStep onYes={() => finish(true)} onNo={() => finish(false)} />
        )}
      </div>

      {/* progress dots */}
      <div className="relative z-10 mt-4 flex justify-center gap-1.5" aria-hidden>
        {Array.from({ length: 7 }, (_, i) => (
          <span
            key={i}
            className={`h-1.5 rounded-full transition-all duration-300 ${
              i === step ? 'w-5 bg-gold-400' : i < step ? 'w-1.5 bg-gold-400/50' : 'w-1.5 bg-white/15'
            }`}
          />
        ))}
      </div>
    </div>
  );
}

/* ── steps ─────────────────────────────────────────────────────────────── */

function Welcome({ onBegin }) {
  return (
    <div className="flex flex-1 flex-col items-center justify-center gap-6 text-center">
      <div className="relative">
        <div className="absolute inset-0 -z-10 animate-twinkle rounded-full bg-gold-400/20 blur-2xl" />
        <svg width="96" height="96" viewBox="0 0 64 64" aria-hidden>
          <defs>
            <linearGradient id="og" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stopColor="#f6e7c1" />
              <stop offset="100%" stopColor="#c9a24b" />
            </linearGradient>
          </defs>
          <path d="M40.5 12a20 20 0 1 0 11.4 25.7A16 16 0 0 1 40.5 12z" fill="url(#og)" />
          <path d="M46 8l1.6 4.4L52 14l-4.4 1.6L46 20l-1.6-4.4L40 14l4.4-1.6z" fill="#f6e7c1" />
        </svg>
      </div>
      <div>
        <h1 className="gold-text text-4xl font-black">طالع من</h1>
        <p className="mt-3 max-w-[260px] text-sm leading-7 text-slate-300">
          سفر شخصی تو در دنیای ستاره‌ها — طالع روزانه، هفتگی و ماهانه،
          سازگاری عاطفی و شناخت عمیق شخصیت، همه به‌صورت آفلاین.
        </p>
      </div>
      <p className="text-[10px] leading-5 text-slate-500">
        این اپلیکیشن بر پایهٔ astrologی سنتی و برای سرگرمی است؛ محتوای آن
        توصیهٔ قطعی در زمینهٔ سلامت، مالی یا حقوقی نیست.
      </p>
      <button className="btn-primary w-full max-w-[260px]" onClick={onBegin}>
        شروع کنیم
      </button>
    </div>
  );
}

function StepTitle({ title, subtitle }) {
  return (
    <div className="pt-6">
      <h2 className="text-xl font-extrabold text-slate-100">{title}</h2>
      <p className="mt-2 text-xs leading-6 text-slate-400">{subtitle}</p>
    </div>
  );
}

function NameStep({ name, setName, onNext }) {
  return (
    <div className="flex flex-1 flex-col">
      <StepTitle title="اسمت چیه؟" subtitle="برای شخصی‌سازی تجربهٔ تو. (اختیاری)" />
      <input
        value={name}
        onChange={(e) => setName(e.target.value)}
        placeholder="مثلاً ستاره"
        maxLength={30}
        className="glass mt-8 w-full bg-white/[0.04] px-4 py-3.5 text-sm text-slate-100 outline-none placeholder:text-slate-500 focus:border-gold-400/50"
      />
      <div className="mt-auto">
        <button className="btn-primary w-full" onClick={onNext}>ادامه</button>
      </div>
    </div>
  );
}

function Select({ value, onChange, children, ariaLabel }) {
  return (
    <select
      value={value}
      onChange={(e) => onChange(Number(e.target.value))}
      aria-label={ariaLabel}
      className="glass-soft flex-1 appearance-none bg-midnight-800/70 px-3 py-3 text-center text-sm font-semibold text-slate-100 outline-none"
    >
      {children}
    </select>
  );
}

function DateStep({ y, m, d, setY, setM, setD, dayCount, valid, onNext }) {
  return (
    <div className="flex flex-1 flex-col">
      <StepTitle
        title="تاریخ تولدت"
        subtitle="بر اساس تقویم هجری شمسی. همین یک بار واردش می‌کنی و همه‌چیز خودکار محاسبه می‌شود."
      />
      <div className="mt-8 flex gap-2">
        <Select value={d} onChange={(x) => setD(Math.min(x, dayCount))} ariaLabel="روز">
          {Array.from({ length: dayCount }, (_, i) => i + 1).map((x) => (
            <option key={x} value={x}>{fa(x)}</option>
          ))}
        </Select>
        <Select value={m} onChange={(x) => setM(x)} ariaLabel="ماه">
          {JALALI_MONTHS.map((mm, i) => (
            <option key={mm} value={i + 1}>{mm}</option>
          ))}
        </Select>
        <Select value={y} onChange={(x) => setY(x)} ariaLabel="سال">
          {YEARS.map((x) => (
            <option key={x} value={x}>{fa(x)}</option>
          ))}
        </Select>
      </div>
      {!valid && (
        <p className="mt-3 text-xs text-rose-300">این تاریخ معتبر نیست — لطفاً اصلاح کن.</p>
      )}
      <p className="mt-4 text-[11px] leading-6 text-slate-500">
        تاریخ تولد فقط روی همین دستگاه ذخیره می‌شود و جایی ارسال نمی‌شود.
      </p>
      <div className="mt-auto">
        <button className="btn-primary w-full disabled:opacity-40" disabled={!valid} onClick={onNext}>
          ادامه
        </button>
      </div>
    </div>
  );
}

function TimeStep({ timeKnown, setTimeKnown, hour, minute, setHour, setMinute, onNext }) {
  return (
    <div className="flex flex-1 flex-col">
      <StepTitle
        title="ساعت تولدت"
        subtitle="برای چارت تولد و طالعِ دقیق‌تر در نسخه‌های بعدی. (اختیاری)"
      />
      {timeKnown ? (
        <div className="mt-8 flex items-center gap-2">
          <Select value={hour} onChange={setHour} ariaLabel="ساعت">
            {Array.from({ length: 24 }, (_, i) => i).map((x) => (
              <option key={x} value={x}>{fa(x)}</option>
            ))}
          </Select>
          <span className="text-lg font-bold text-gold-300">:</span>
          <Select value={minute} onChange={setMinute} ariaLabel="دقیقه">
            {Array.from({ length: 12 }, (_, i) => i * 5).map((x) => (
              <option key={x} value={x}>{fa(String(x).padStart(2, '0'))}</option>
            ))}
          </Select>
        </div>
      ) : null}
      <button
        onClick={() => setTimeKnown(!timeKnown)}
        className="glass-soft mt-6 flex items-center justify-between px-4 py-3 text-xs text-slate-300"
      >
        <span>ساعت تولدم را می‌دانم</span>
        <span className={`relative h-5 w-9 rounded-full transition ${timeKnown ? 'bg-gold-400' : 'bg-white/15'}`}>
          <span className={`absolute top-0.5 h-4 w-4 rounded-full bg-white transition-all ${timeKnown ? 'right-0.5' : 'right-[18px]'}`} />
        </span>
      </button>
      {!timeKnown && (
        <button
          onClick={onNext}
          className="mt-4 text-center text-xs font-medium text-gold-300 underline decoration-gold-400/40 underline-offset-4"
        >
          ساعت تولدم را نمی‌دانم
        </button>
      )}
      <div className="mt-auto">
        <button className="btn-primary w-full" onClick={onNext}>ادامه</button>
      </div>
    </div>
  );
}

function CityStep({ city, setCity, onNext }) {
  return (
    <div className="flex flex-1 flex-col">
      <StepTitle
        title="شهر تولدت"
        subtitle="بدون هیچ دسترسی به موقعیت — خودت انتخاب می‌کنی. (اختیاری)"
      />
      <div className="glass-soft mt-8 max-h-64 overflow-y-auto p-1.5">
        {CITIES.map((c) => (
          <button
            key={c}
            onClick={() => setCity(city === c ? '' : c)}
            className="flex w-full items-center gap-2.5 rounded-xl px-3 py-2.5 text-right text-[13px] transition hover:bg-white/5"
          >
            <span className={`text-[10px] ${city === c ? 'text-gold-300' : 'text-slate-600'}`}>●</span>
            <span className={city === c ? 'font-bold text-gold-200' : 'text-slate-300'}>{c}</span>
          </button>
        ))}
      </div>
      <div className="mt-auto">
        <button className="btn-primary w-full" onClick={onNext}>ادامه</button>
      </div>
    </div>
  );
}

function ResultStep({ sign, name, onNext }) {
  return (
    <div className="flex flex-1 flex-col items-center justify-center gap-5 text-center">
      <div className="relative">
        <div className="absolute inset-0 -z-10 rounded-full bg-gold-400/15 blur-2xl" />
        <span className="block text-[72px] leading-none text-gold-300 drop-shadow-[0_0_24px_rgba(232,199,123,0.35)]">
          {sign.symbol}
        </span>
      </div>
      <div>
        <p className="text-sm text-slate-400">{name ? `${name}،` : ''} تو یک</p>
        <h2 className="gold-text mt-1 text-3xl font-black">{sign.nameFa} هستی</h2>
        <p className="mt-1 text-[11px] tracking-widest text-slate-500">{sign.nameEn}</p>
      </div>
      <GlassCard className="mt-2 w-full max-w-[300px]">
        <div className="flex justify-around py-1 text-center">
          <div>
            <p className="text-[10px] text-slate-400">عنصر</p>
            <p className="mt-1 text-xs font-bold text-gold-200">{sign.element}</p>
          </div>
          <div>
            <p className="text-[10px] text-slate-400">سیارهٔ راهبر</p>
            <p className="mt-1 text-xs font-bold text-gold-200">{sign.rulingPlanet}</p>
          </div>
          <div>
            <p className="text-[10px] text-slate-400">نماد</p>
            <p className="mt-1 text-xs font-bold text-gold-200">{sign.symbol}</p>
          </div>
        </div>
      </GlassCard>
      <p className="max-w-[280px] text-[11px] leading-6 text-slate-400">{sign.description}</p>
      <button className="btn-primary mt-2 w-full max-w-[280px]" onClick={onNext}>
        ورود به طالع من
      </button>
    </div>
  );
}

function NotifyStep({ onYes, onNo }) {
  return (
    <div className="flex flex-1 flex-col items-center justify-center gap-6 text-center">
      <svg width="72" height="72" viewBox="0 0 24 24" fill="none" className="text-gold-300" aria-hidden>
        <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
        <path d="M13.7 21a2 2 0 0 1-3.4 0" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
      <div>
        <h2 className="text-xl font-extrabold text-slate-100">هر روز ساعت ۸ صبح</h2>
        <p className="mx-auto mt-3 max-w-[280px] text-xs leading-6 text-slate-400">
          «طالع امروزت آماده است» — اول روز، یک نگاه کوتاه به عشق، کار و شانسِ
          امروزت. هیچ اسپمی نیست؛ هر وقت بخواهی از تنظیمات خاموشش می‌کنی.
        </p>
      </div>
      <div className="w-full max-w-[280px] space-y-2.5">
        <button className="btn-primary w-full" onClick={onYes}>آره، فعال کن</button>
        <button className="btn-ghost w-full" onClick={onNo}>فعلاً نه</button>
      </div>
    </div>
  );
}
