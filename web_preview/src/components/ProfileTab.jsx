import { fa, JALALI_MONTHS } from '../persian.js';
import { GlassCard, SectionTitle } from './Glass.jsx';
import { PartnerForm } from './PartnerForm.jsx';

export default function ProfileTab({
  profile,
  partner,
  settings,
  onOpen,
  onSetTheme,
  onToggleNotifications,
  onResetAll,
}) {
  const birthLabel = `${fa(profile.d)} ${JALALI_MONTHS[profile.m - 1]} ${fa(profile.y)}`;
  return (
    <div className="space-y-5 px-4 pb-6 pt-4">
      {/* profile card */}
      <GlassCard className="animate-fade-up text-center">
        <span className="block text-5xl text-gold-300">{profile.sign.symbol}</span>
        <h1 className="mt-2 text-lg font-black text-slate-100 light:text-slate-900">
          {profile.name || 'کاربر طالع من'}
        </h1>
        <p className="mt-1 text-[11px] text-slate-400">برج {profile.sign.nameFa} — {profile.sign.nameEn}</p>
        <div className="mt-3 flex flex-wrap justify-center gap-1.5">
          <InfoPill label="تاریخ تولد" value={birthLabel} />
          {profile.time && <InfoPill label="ساعت تولد" value={`${fa(profile.time[0])}:${fa(String(profile.time[1]).padStart(2, '0'))}`} />}
          {profile.city && <InfoPill label="شهر تولد" value={profile.city} />}
        </div>
        <button
          className="btn-ghost mt-4 w-full"
          onClick={() => onOpen('edit-profile')}
        >
          ویرایش پروفایل
        </button>
      </GlassCard>

      {/* premium */}
      <section className="animate-fade-up" style={{ animationDelay: '80ms' }}>
        <SectionTitle>اشتراک ویژه</SectionTitle>
        <button onClick={() => onOpen('premium')} className="w-full text-right">
          <GlassCard className="relative overflow-hidden border-gold-400/30 bg-gradient-to-bl from-gold-400/[0.12] to-transparent">
            <div className="absolute -left-8 -top-8 h-24 w-24 rounded-full bg-gold-400/15 blur-2xl" />
            <p className="text-[13px] font-extrabold text-gold-200">
              {settings.premium ? 'اشتراک ویژه فعال است' : 'طالع من ویژه'}
            </p>
            <p className="mt-1 text-[11px] leading-6 text-slate-400">
              {settings.premium
                ? 'همهٔ قابلیت‌های ویژه در دسترس توست.'
                : 'تحلیل عمیق‌تر رابطه، چارت تولد، طالع ماهانهٔ پیشرفته و بدون محدودیت'}
            </p>
          </GlassCard>
        </button>
      </section>

      {/* settings */}
      <section className="animate-fade-up" style={{ animationDelay: '140ms' }}>
        <SectionTitle>تنظیمات</SectionTitle>
        <GlassCard className="divide-y divide-white/[0.06] light:divide-slate-900/[0.06] p-0">
          <ToggleRow
            label="حالت روشن"
            hint="پس‌زمینهٔ روشن با عناصر نجومی ظریف"
            checked={settings.theme === 'light'}
            onChange={(v) => onSetTheme(v ? 'light' : 'dark')}
          />
          <ToggleRow
            label="اطلاع‌رسانی روزانه"
            hint="هر روز ساعت ۸ صبح — «طالع امروزت آماده است»"
            checked={settings.notifications}
            onChange={onToggleNotifications}
          />
        </GlassCard>
      </section>

      {/* partner quick view */}
      {partner && (
        <section className="animate-fade-up" style={{ animationDelay: '200ms' }}>
          <SectionTitle>شریک عاطفی</SectionTitle>
          <GlassCard className="flex items-center gap-3">
            <span className="text-3xl text-gold-300">{partner.sign?.symbol ?? ''}</span>
            <div className="min-w-0 flex-1">
              <p className="text-[13px] font-bold text-slate-100">{partner.name || 'شریک من'}</p>
              <p className="text-[11px] text-slate-400">برج {partner.sign?.nameFa}</p>
            </div>
            <button
              onClick={() => onOpen('partner')}
              className="text-[11px] font-bold text-gold-300"
            >
              ویرایش
            </button>
          </GlassCard>
        </section>
      )}

      {/* danger zone */}
      <section className="animate-fade-up" style={{ animationDelay: '260ms' }}>
        <SectionTitle>حریم خصوصی و داده‌ها</SectionTitle>
        <GlassCard>
          <p className="text-[11px] leading-6 text-slate-400">
            همهٔ داده‌های تو (پروفایل، شریک، تنظیمات) فقط روی همین دستگاه ذخیره
            می‌شود؛ هیچ چیزی به سروری ارسال نمی‌شود.
          </p>
          <button
            className="mt-3 w-full rounded-2xl border border-rose-400/30 bg-rose-400/10 px-5 py-3 text-[13px] font-bold text-rose-300 transition active:scale-[0.98]"
            onClick={() => {
              if (window.confirm('همهٔ اطلاعات تو حذف شود؟ این کار قابل بازگشت نیست.')) onResetAll();
            }}
          >
            حذف تمام اطلاعات من
          </button>
        </GlassCard>
      </section>

      <p className="pb-2 text-center text-[10px] text-slate-600 light:text-slate-400">
        طالع من — نسخهٔ پیش‌نمایش ۱.۰.۰
      </p>
    </div>
  );
}

function InfoPill({ label, value }) {
  return (
    <span className="chip flex-col items-center gap-0 px-3 py-1">
      <span className="text-[9px] text-slate-500">{label}</span>
      <span className="text-[11px] font-bold text-gold-200 light:text-gold-700">{value}</span>
    </span>
  );
}

function ToggleRow({ label, hint, checked, onChange }) {
  return (
    <label className="flex cursor-pointer items-center gap-3 px-4 py-3.5">
      <input
        type="checkbox"
        className="sr-only"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
      />
      <span className="min-w-0 flex-1">
        <span className="block text-[13px] font-bold text-slate-100 light:text-slate-800">{label}</span>
        <span className="mt-0.5 block text-[10px] leading-4 text-slate-400">{hint}</span>
      </span>
      <span
        role="switch"
        aria-checked={checked}
        aria-label={label}
        className={`relative h-6 w-11 shrink-0 rounded-full transition ${checked ? 'bg-gold-400' : 'bg-white/15 light:bg-slate-900/15'}`}
      >
        <span className={`absolute top-0.5 h-5 w-5 rounded-full bg-white shadow transition-all ${checked ? 'right-0.5' : 'right-[22px]'}`} />
      </span>
    </label>
  );
}

/* ── Sheets ────────────────────────────────────────────────────────────── */

export function PartnerSheet({ partner, onSave, onClose, onRemove }) {
  return (
    <PartnerForm partner={partner} onSave={onSave} onClose={onClose} onRemove={onRemove} />
  );
}
