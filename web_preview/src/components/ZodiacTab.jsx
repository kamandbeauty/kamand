import { Chip, GlassCard, SectionTitle } from './Glass.jsx';
import { fa } from '../persian.js';

export default function ZodiacTab({ profile, onOpen }) {
  const sign = profile.sign;
  return (
    <div className="space-y-5 px-4 pb-6 pt-4">
      {/* hero */}
      <GlassCard className="animate-fade-up relative overflow-hidden text-center">
        <div className="absolute -right-10 -top-10 h-32 w-32 rounded-full bg-gold-400/10 blur-2xl" />
        <span className="block text-[56px] leading-none text-gold-300 drop-shadow-[0_0_18px_rgba(232,199,123,0.3)]">
          {sign.symbol}
        </span>
        <h1 className="mt-2 text-xl font-black text-slate-100 light:text-slate-900">برج {sign.nameFa}</h1>
        <p className="mt-1 text-[10px] tracking-[0.25em] text-slate-500">{sign.nameEn}</p>
        <div className="mt-3 flex flex-wrap justify-center gap-1.5">
          <Chip>عنصر {sign.element}</Chip>
          <Chip>سیارهٔ {sign.rulingPlanet}</Chip>
          <Chip>{rangeLabel(sign)}</Chip>
        </div>
      </GlassCard>

      {/* personality */}
      <section className="animate-fade-up" style={{ animationDelay: '80ms' }}>
        <SectionTitle>شخصیت تو</SectionTitle>
        <GlassCard>
          <p className="text-[12px] leading-7 text-slate-300 light:text-slate-600">
            {sign.personality}
          </p>
        </GlassCard>
      </section>

      {/* strengths / weaknesses */}
      <section className="animate-fade-up grid grid-cols-1 gap-3" style={{ animationDelay: '140ms' }}>
        <div>
          <SectionTitle>نقاط قوت</SectionTitle>
          <GlassCard className="flex flex-wrap gap-1.5">
            {sign.strengths.map((s) => (
              <Chip key={s} className="border-emerald-300/25 bg-emerald-300/10 text-emerald-200">{s}</Chip>
            ))}
          </GlassCard>
        </div>
        <div>
          <SectionTitle>نقاط ضعف</SectionTitle>
          <GlassCard className="flex flex-wrap gap-1.5">
            {sign.weaknesses.map((s) => (
              <Chip key={s} className="border-rose-300/25 bg-rose-300/10 text-rose-200">{s}</Chip>
            ))}
          </GlassCard>
        </div>
      </section>

      {/* styles */}
      <section className="animate-fade-up space-y-3" style={{ animationDelay: '200ms' }}>
        <StyleCard title="در عشق" text={sign.loveStyle} glyph="❤" tone="rose" />
        <StyleCard title="در کار" text={sign.workStyle} glyph="◈" tone="sky" />
        <StyleCard title="در دوستی" text={sign.friendshipStyle} glyph="☾" tone="violet" />
      </section>

      {/* lucky constants */}
      <section className="animate-fade-up" style={{ animationDelay: '260ms' }}>
        <SectionTitle>آنچه همیشه با توست</SectionTitle>
        <GlassCard className="grid grid-cols-3 gap-2 py-5 text-center">
          <div>
            <p className="text-[10px] text-slate-400">رنگ‌های شانس</p>
            <p className="mt-1.5 text-[11px] font-bold leading-6 text-gold-200 light:text-gold-700">
              {sign.luckyColors.slice(0, 3).join('، ')}
            </p>
          </div>
          <div>
            <p className="text-[10px] text-slate-400">اعداد شانس</p>
            <p className="mt-1.5 text-[11px] font-bold leading-6 text-gold-200 light:text-gold-700">
              {sign.luckyNumbers.slice(0, 4).map(fa).join('، ')}
            </p>
          </div>
          <div>
            <p className="text-[10px] text-slate-400">ساعت‌های شانس</p>
            <p className="mt-1.5 text-[11px] font-bold leading-6 text-gold-200 light:text-gold-700">
              {sign.luckyTimes.slice(0, 2).join('، ')}
            </p>
          </div>
        </GlassCard>
      </section>
    </div>
  );
}

const MONTHS_FA = [
  'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
  'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند',
];

function rangeLabel(sign) {
  // Boundaries are Gregorian (same as the app’s calculator).
  const g = (m, d) => `${fa(d)} ${MONTHS_FA[m - 1]}`;
  return `${g(sign.startMonth, sign.startDay)} تا ${g(sign.endMonth, sign.endDay)}`;
}

function StyleCard({ title, text, glyph, tone }) {
  const tones = {
    rose: 'text-rose-300 border-rose-300/20 bg-rose-300/[0.05]',
    sky: 'text-sky-300 border-sky-300/20 bg-sky-300/[0.05]',
    violet: 'text-violet-300 border-violet-300/20 bg-violet-300/[0.05]',
  };
  return (
    <GlassCard className={`flex gap-3 border ${tones[tone]}`}>
      <span className="mt-0.5 shrink-0 text-base opacity-80">{glyph}</span>
      <div>
        <p className="text-[12px] font-extrabold">{title}</p>
        <p className="mt-1.5 text-[12px] leading-7 text-slate-300 light:text-slate-600">{text}</p>
      </div>
    </GlassCard>
  );
}
