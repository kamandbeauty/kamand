import {
  generateDaily,
  generateWeekly,
  generateMonthly,
  todayJalali,
  weekStartJalali,
} from '../engine.js';
import {
  fa,
  formatJalaliLong,
  formatJalaliShort,
  weekdayShortLabel,
  shortScorePhrase,
  SCORE_LABELS,
} from '../persian.js';
import { GlassCard, SectionTitle, ScoreRing, ScoreBar } from './Glass.jsx';

export default function HomeTab({ profile, onOpen }) {
  const today = todayJalali();
  const sign = profile.sign;
  const daily = generateDaily(sign, today);
  const weekStart = weekStartJalali();
  const weekly = generateWeekly(sign, weekStart);
  const month = todayJalali();
  const monthly = generateMonthly(sign, month[0], month[1]);

  return (
    <div className="space-y-5 px-4 pb-6 pt-4">
      {/* greeting */}
      <div className="animate-fade-up px-1">
        <p className="text-xs text-slate-400 light:text-slate-500">{formatJalaliLong(today)}</p>
        <h1 className="mt-1 text-2xl font-black text-slate-100 light:text-slate-900">
          سلام {profile.name || 'ستاره'} <span className="text-gold-300">{sign.symbol}</span>
        </h1>
        <p className="mt-1 text-xs text-slate-400 light:text-slate-500">
          برج {sign.nameFa} — طالع امروزت آماده است
        </p>
      </div>

      {/* daily scores */}
      <section className="animate-fade-up" style={{ animationDelay: '60ms' }} aria-label="امتیازهای امروز">
        <SectionTitle
          action={
            <button onClick={() => onOpen('daily')} className="text-[11px] font-bold text-gold-300 light:text-gold-600">
              طالع کامل امروز ←
            </button>
          }
        >
          طالع امروز تو
        </SectionTitle>
        <GlassCard>
          <div className="flex justify-between">
            <ScoreRing value={daily.scores.love} label={SCORE_LABELS.love} />
            <ScoreRing value={daily.scores.career} label={SCORE_LABELS.career} />
            <ScoreRing value={daily.scores.finance} label={SCORE_LABELS.finance} />
            <ScoreRing value={daily.scores.mood} label={SCORE_LABELS.mood} />
          </div>
          <p className="mt-4 rounded-2xl bg-white/[0.05] light:bg-white/70 p-3 text-[12px] leading-7 text-slate-300 light:text-slate-600">
            {daily.generalText}
          </p>
        </GlassCard>
      </section>

      {/* lucky */}
      <section className="animate-fade-up" style={{ animationDelay: '120ms' }} aria-label="نشانه‌های شانس">
        <SectionTitle>نشانه‌های شانس امروز</SectionTitle>
        <GlassCard className="grid grid-cols-3 gap-2 py-5">
          <LuckyItem label="رنگ شانس" value={daily.lucky.color} />
          <LuckyItem label="عدد شانس" value={fa(daily.lucky.number)} />
          <LuckyItem label="ساعت شانس" value={daily.lucky.time} />
        </GlassCard>
      </section>

      {/* weekly teaser */}
      <section className="animate-fade-up" style={{ animationDelay: '180ms' }} aria-label="طالع هفته">
        <SectionTitle
          action={
            <button onClick={() => onOpen('weekly')} className="text-[11px] font-bold text-gold-300 light:text-gold-600">
              هفتهٔ کامل ←
            </button>
          }
        >
          نگاهی به هفتهٔ پیش رو
        </SectionTitle>
        <GlassCard>
          <div className="flex items-end justify-between gap-1.5" style={{ direction: 'rtl' }}>
            {weekly.days.map((day) => {
              const total = Math.round(
                (day.scores.love + day.scores.career + day.scores.finance +
                  day.scores.mood + day.scores.energy) / 5,
              );
              return (
                <div key={day.date.join('-')} className="flex flex-1 flex-col items-center gap-1.5">
                  <span className="text-[9px] font-bold text-gold-300 light:text-gold-600">{fa(total)}</span>
                  <div
                    className="w-full rounded-full bg-gradient-to-t from-gold-600/70 to-gold-300 transition-all duration-700"
                    style={{ height: `${18 + (total / 100) * 42}px` }}
                  />
                  <span className="text-[9px] text-slate-400">{weekdayShortLabel(day.date)}</span>
                </div>
              );
            })}
          </div>
          <p className="mt-4 text-[11px] leading-6 text-slate-400">{weekly.summaryText}</p>
        </GlassCard>
      </section>

      {/* monthly teaser */}
      <section className="animate-fade-up" style={{ animationDelay: '240ms' }} aria-label="طالع ماه">
        <SectionTitle
          action={
            <button onClick={() => onOpen('monthly')} className="text-[11px] font-bold text-gold-300 light:text-gold-600">
              ماهِ کامل ←
            </button>
          }
        >
          تم این ماه
        </SectionTitle>
        <GlassCard className="relative overflow-hidden">
          <div className="absolute -left-8 -top-8 h-28 w-28 rounded-full bg-gold-400/10 blur-2xl" />
          <p className="text-[12px] font-bold text-gold-200 light:text-gold-700">{monthly.focusText}</p>
          <p className="mt-2 text-[11px] leading-6 text-slate-400">{monthly.opportunityText}</p>
        </GlassCard>
      </section>

      <p className="px-2 pt-1 text-center text-[9px] leading-5 text-slate-600 light:text-slate-400">
        محتوای طالع بر اساس astrologی سنتی و برای سرگرمی است.
      </p>
    </div>
  );
}

function LuckyItem({ label, value }) {
  return (
    <div className="text-center">
      <p className="text-[10px] text-slate-400">{label}</p>
      <p className="mt-1.5 text-[13px] font-extrabold text-gold-200 light:text-gold-700">{value}</p>
    </div>
  );
}

/* ── Sheets ────────────────────────────────────────────────────────────── */

export function DailySheet({ profile }) {
  const today = todayJalali();
  const sign = profile.sign;
  const daily = generateDaily(sign, today);
  const cats = [
    ['generalText', 'پیام امروز', '✦'],
    ['loveText', 'عشق', '❤'],
    ['careerText', 'کار و پیشه', '◈'],
    ['financeText', 'مالی', '◉'],
    ['moodText', 'حال‌وهوا', '☾'],
  ];
  return (
    <div className="space-y-4">
      <p className="text-[11px] text-slate-400">{formatJalaliLong(today)} — برج {sign.nameFa}</p>
      <GlassCard className="space-y-2.5">
        {Object.entries(daily.scores).map(([k, v]) => (
          <ScoreBar key={k} label={SCORE_LABELS[k]} value={v} />
        ))}
      </GlassCard>
      {cats.map(([key, label, glyph], i) => (
        <GlassCard key={key} className="animate-fade-up" style={{ animationDelay: `${i * 60}ms` }}>
          <p className="mb-2 flex items-center gap-2 text-[12px] font-extrabold text-gold-200 light:text-gold-700">
            <span className="text-gold-400/70">{glyph}</span> {label}
          </p>
          <p className="text-[12px] leading-7 text-slate-300 light:text-slate-600">{daily[key]}</p>
        </GlassCard>
      ))}
      <GlassCard className="border-amber-300/20 bg-amber-300/[0.04]">
        <p className="mb-2 text-[12px] font-extrabold text-amber-200">مراقبِ امروز باش</p>
        <p className="text-[12px] leading-7 text-amber-100/80">{daily.warningText}</p>
      </GlassCard>
      <GlassCard className="border-emerald-300/20 bg-emerald-300/[0.04]">
        <p className="mb-2 text-[12px] font-extrabold text-emerald-200">فرصت امروز</p>
        <p className="text-[12px] leading-7 text-emerald-100/80">{daily.opportunityText}</p>
      </GlassCard>
      <GlassCard className="grid grid-cols-3 gap-2 py-4">
        <LuckyItem label="رنگ شانس" value={daily.lucky.color} />
        <LuckyItem label="عدد شانس" value={fa(daily.lucky.number)} />
        <LuckyItem label="ساعت شانس" value={daily.lucky.time} />
      </GlassCard>
    </div>
  );
}

export function WeeklySheet({ profile }) {
  const sign = profile.sign;
  const weekly = generateWeekly(sign, weekStartJalali());
  return (
    <div className="space-y-3">
      <p className="text-[11px] text-slate-400">
        هفتهٔ {formatJalaliShort(weekly.weekStart)} تا {formatJalaliShort(weekly.days[6].date)}
      </p>
      <GlassCard>
        <p className="text-[12px] leading-7 text-slate-300">{weekly.summaryText}</p>
      </GlassCard>
      {weekly.days.map((day, i) => {
        const total = Math.round(
          (day.scores.love + day.scores.career + day.scores.finance +
            day.scores.mood + day.scores.energy) / 5,
        );
        return (
          <GlassCard key={day.date.join('-')} className="flex items-center gap-3 py-3.5 animate-fade-up" style={{ animationDelay: `${i * 50}ms` }}>
            <div className="flex h-11 w-11 shrink-0 flex-col items-center justify-center rounded-2xl bg-white/[0.05] light:bg-white/70">
              <span className="text-[11px] font-extrabold text-gold-200 light:text-gold-700">{fa(day.date[2])}</span>
              <span className="text-[8px] text-slate-400">{weekdayShortLabel(day.date).split(' ')[0]}</span>
            </div>
            <div className="min-w-0 flex-1 space-y-1.5">
              <ScoreBar label="عشق" value={day.scores.love} />
              <ScoreBar label="کار" value={day.scores.career} />
              <ScoreBar label="انرژی" value={day.scores.energy} />
            </div>
            <div className="w-12 shrink-0 text-center">
              <p className="text-lg font-black text-gold-300 light:text-gold-600">{fa(total)}</p>
              <p className="text-[8px] text-slate-500">{shortScorePhrase(total)}</p>
            </div>
          </GlassCard>
        );
      })}
    </div>
  );
}

export function MonthlySheet({ profile }) {
  const sign = profile.sign;
  const [y, m] = todayJalali();
  const monthly = generateMonthly(sign, y, m);
  const sections = [
    ['focusText', 'تمرکز این ماه'],
    ['loveText', 'عشق'],
    ['careerText', 'کار'],
    ['financeText', 'مالی'],
    ['energyText', 'انرژی'],
    ['opportunityText', 'فرصت'],
    ['warningText', 'مراقب باش'],
  ];
  return (
    <div className="space-y-3">
      <p className="text-[11px] text-slate-400">{fa(m)} ماهِ {fa(y)} — برج {sign.nameFa}</p>
      <GlassCard className="space-y-2.5">
        {Object.entries(monthly.scores).map(([k, v]) => (
          <ScoreBar key={k} label={SCORE_LABELS[k]} value={v} />
        ))}
      </GlassCard>
      {sections.map(([key, label], i) => (
        <GlassCard key={key} className="animate-fade-up" style={{ animationDelay: `${i * 50}ms` }}>
          <p className="mb-2 text-[12px] font-extrabold text-gold-200 light:text-gold-700">{label}</p>
          <p className="text-[12px] leading-7 text-slate-300 light:text-slate-600">{monthly[key]}</p>
        </GlassCard>
      ))}
    </div>
  );
}
