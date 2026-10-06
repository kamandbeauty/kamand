import {
  computeCompatibility,
  compatLabels,
  rankedFor,
  signById,
} from '../engine.js';
import { fa, compatLevel, shortScorePhrase } from '../persian.js';
import { GlassCard, SectionTitle, ScoreBar, Sheet, Chip } from './Glass.jsx';

export default function LoveTab({ profile, partner, onOpen }) {
  const sign = profile.sign;
  const ranked = rankedFor(sign.id);
  const best = ranked[0];
  const challenging = ranked[ranked.length - 1];

  return (
    <div className="space-y-5 px-4 pb-6 pt-4">
      {/* couple card */}
      <section className="animate-fade-up">
        <SectionTitle
          action={
            <button
              onClick={() => onOpen(partner ? 'couple' : 'partner')}
              className="text-[11px] font-bold text-gold-300 light:text-gold-600"
            >
              {partner ? 'تحلیل کامل رابطه ←' : 'افزودن شریک'}
            </button>
          }
        >
          رابطهٔ من
        </SectionTitle>
        {partner ? (
          <button onClick={() => onOpen('couple')} className="w-full text-right">
            <GlassCard className="relative overflow-hidden">
              <div className="absolute -left-10 -top-10 h-28 w-28 rounded-full bg-rose-300/10 blur-2xl" />
              <div className="flex items-center justify-between">
                <SignBadge sign={sign} label="من" />
                <div className="flex flex-col items-center gap-1">
                  <span className="text-2xl text-rose-300/90">❤</span>
                  <span className="text-lg font-black text-gold-300 light:text-gold-600">
                    {fa(computeCompatibility(sign.id, partner.signId).scores.overall)}
                    <span className="text-[10px] font-normal text-slate-400">٪</span>
                  </span>
                </div>
                <SignBadge sign={signById(partner.signId)} label={partner.name || 'شریک من'} />
              </div>
              <p className="mt-3 text-center text-[11px] text-slate-400">
                {compatLevel(computeCompatibility(sign.id, partner.signId).scores.overall)} —{' '}
                {computeCompatibility(sign.id, partner.signId).aspectTitle}
              </p>
            </GlassCard>
          </button>
        ) : (
          <button onClick={() => onOpen('partner')} className="w-full text-right">
            <GlassCard className="flex items-center gap-3 border-dashed border-white/15 py-6">
              <span className="flex h-11 w-11 items-center justify-center rounded-2xl bg-white/[0.06] text-xl text-gold-300">+</span>
              <div>
                <p className="text-[13px] font-bold text-slate-200 light:text-slate-700">افزودن شریک عاطفی</p>
                <p className="mt-1 text-[11px] text-slate-400">
                  برج او را انتخاب کن تا سازگاری عاطفی‌تان را ببینی
                </p>
              </div>
            </GlassCard>
          </button>
        )}
      </section>

      {/* best / hardest */}
      <section className="animate-fade-up grid grid-cols-2 gap-3" style={{ animationDelay: '80ms' }}>
        <MiniRank title="هماهنگ‌ترین" data={best} tone="emerald" onOpen={onOpen} />
        <MiniRank title="چالش‌برانگیزترین" data={challenging} tone="amber" onOpen={onOpen} />
      </section>

      {/* 12-sign grid */}
      <section className="animate-fade-up" style={{ animationDelay: '140ms' }}>
        <SectionTitle>سازگاری تو با همهٔ برج‌ها</SectionTitle>
        <GlassCard className="grid grid-cols-3 gap-2 p-3">
          {ranked.map((r) => (
            <button
              key={r.signB.id}
              onClick={() => onOpen('compat', r.signB.id)}
              className="flex flex-col items-center gap-1 rounded-2xl bg-white/[0.04] light:bg-white/60 px-2 py-3 transition hover:bg-white/[0.08]"
            >
              <span className="text-xl text-gold-300/90">{r.signB.symbol}</span>
              <span className="text-[11px] font-bold text-slate-200 light:text-slate-700">{r.signB.nameFa}</span>
              <span className={`text-[10px] font-extrabold ${
                r.scores.overall >= 72 ? 'text-emerald-300' : r.scores.overall >= 48 ? 'text-gold-300' : 'text-rose-300'
              }`}>
                {fa(r.scores.overall)}٪
              </span>
            </button>
          ))}
        </GlassCard>
      </section>

      <p className="px-2 text-center text-[9px] leading-5 text-slate-600 light:text-slate-400">
        تحلیل سازگاری بر پایهٔ astrologی سنتی است و جایگزین قضاوت خودت نیست.
      </p>
    </div>
  );
}

function SignBadge({ sign, label }) {
  return (
    <div className="flex w-24 flex-col items-center gap-1">
      <span className="text-4xl text-gold-200 light:text-gold-700">{sign.symbol}</span>
      <span className="text-[11px] font-bold text-slate-200 light:text-slate-700">برج {sign.nameFa}</span>
      <span className="max-w-full truncate text-[9px] text-slate-500">{label}</span>
    </div>
  );
}

function MiniRank({ title, data, tone, onOpen }) {
  const tones = {
    emerald: 'text-emerald-300 border-emerald-300/25 bg-emerald-300/[0.05]',
    amber: 'text-amber-300 border-amber-300/25 bg-amber-300/[0.05]',
  };
  return (
    <button className="w-full" onClick={() => onOpen('compat', data.signB.id)}>
      <GlassCard className={`h-full border text-center ${tones[tone]}`}>
        <p className="text-[10px] text-slate-400">{title}</p>
        <span className="mt-1.5 block text-2xl opacity-90">{data.signB.symbol}</span>
        <p className="mt-1 text-[12px] font-bold text-slate-100">{data.signB.nameFa}</p>
        <p className="mt-0.5 text-[13px] font-black">{fa(data.scores.overall)}٪</p>
        <p className="mt-0.5 text-[9px] text-slate-500">{compatLevel(data.scores.overall)}</p>
      </GlassCard>
    </button>
  );
}

/* ── Sheets ────────────────────────────────────────────────────────────── */

export function CompatSheet({ profile, otherId, onClose }) {
  const result = computeCompatibility(profile.sign.id, otherId);
  const dims = [
    ['love', 15], ['attraction', 21], ['communication', 13], ['trust', 11], ['longTerm', 13],
  ];
  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between px-2">
        <SignBadge sign={result.signA} label="تو" />
        <span className="text-2xl text-rose-300/80">❤</span>
        <SignBadge sign={result.signB} label="" />
      </div>

      <GlassCard className="text-center">
        <p className="text-4xl font-black text-gold-300 light:text-gold-600">
          {fa(result.scores.overall)}<span className="text-lg">٪</span>
        </p>
        <p className="mt-1 text-[12px] font-bold text-slate-200">{compatLevel(result.scores.overall)}</p>
        <p className="mt-2 text-[10px] text-slate-500">{result.aspectTitle}</p>
      </GlassCard>

      <GlassCard className="space-y-2.5">
        {dims.map(([key]) => (
          <ScoreBar key={key} label={compatLabels[key]} value={result.scores[key]} />
        ))}
      </GlassCard>

      <GlassCard>
        <p className="mb-2 text-[12px] font-extrabold text-gold-200 light:text-gold-700">
          چرا این دو برج با هم سازگارند؟
        </p>
        <p className="text-[12px] leading-7 text-slate-300 light:text-slate-600">{result.whyText}</p>
      </GlassCard>

      <GlassCard>
        <p className="mb-2 text-[12px] font-extrabold text-gold-200 light:text-gold-700">شیمی عناصر</p>
        <p className="text-[12px] leading-7 text-slate-300 light:text-slate-600">{result.elementChemistryText}</p>
      </GlassCard>
    </div>
  );
}

export function CoupleSheet({ profile, partner, onEditPartner, onRemovePartner }) {
  const result = computeCompatibility(profile.sign.id, partner.signId);
  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between px-2">
        <SignBadge sign={result.signA} label={profile.name || 'من'} />
        <span className="text-2xl text-rose-300/80">❤</span>
        <SignBadge sign={result.signB} label={partner.name || 'شریک من'} />
      </div>

      <GlassCard className="text-center">
        <p className="text-4xl font-black text-gold-300 light:text-gold-600">
          {fa(result.scores.overall)}<span className="text-lg">٪</span>
        </p>
        <p className="mt-1 text-[12px] font-bold text-slate-200">{compatLevel(result.scores.overall)}</p>
      </GlassCard>

      <GlassCard className="space-y-2.5">
        {['love', 'attraction', 'communication', 'trust', 'longTerm'].map((key) => (
          <ScoreBar key={key} label={compatLabels[key]} value={result.scores[key]} />
        ))}
      </GlassCard>

      <GlassCard>
        <p className="mb-2 text-[12px] font-extrabold text-gold-200 light:text-gold-700">تحلیل رابطه</p>
        <p className="text-[12px] leading-7 text-slate-300 light:text-slate-600">{result.whyText}</p>
      </GlassCard>

      <GlassCard>
        <p className="mb-2 text-[12px] font-extrabold text-gold-200 light:text-gold-700">شیمی عناصر</p>
        <p className="text-[12px] leading-7 text-slate-300 light:text-slate-600">{result.elementChemistryText}</p>
      </GlassCard>

      <CoupleToday profile={profile} partner={partner} />

      <div className="flex gap-2">
        <button className="btn-ghost flex-1" onClick={onEditPartner}>ویرایش شریک</button>
        <button
          className="flex-1 rounded-2xl border border-rose-300/25 bg-rose-300/10 px-5 py-3 text-sm font-semibold text-rose-300 transition active:scale-[0.98]"
          onClick={() => {
            if (window.confirm('شریک عاطفی حذف شود؟')) onRemovePartner();
          }}
        >
          حذف شریک
        </button>
      </div>
    </div>
  );
}

/** Little deterministic "today for both" strip. */
function CoupleToday({ profile, partner }) {
  const a = computeCompatibility(profile.sign.id, partner.signId);
  const text = a.scores.overall >= 60
    ? 'امروز روز خوبی برای گفت‌وگوی صادقانه با یکدیگر است.'
    : 'امروز ممکن است حساسیت‌ها تند باشد؛ با مهربانی حرف بزنید.';
  return (
    <GlassCard className="border-rose-300/20 bg-rose-300/[0.04]">
      <p className="text-[12px] font-extrabold text-rose-200">نکتهٔ امروز برای شما دو نفر</p>
      <p className="mt-2 text-[12px] leading-7 text-rose-100/80">{text}</p>
    </GlassCard>
  );
}
