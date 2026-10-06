import { useCallback, useEffect, useMemo, useState } from 'react';

import {
  signById,
  zodiacForGregorian,
  jalaliToGregorian,
  engineSelfCheckOk,
} from './engine.js';

import PhoneFrame from './components/PhoneFrame.jsx';
import Onboarding from './components/Onboarding.jsx';
import HomeTab, { DailySheet, WeeklySheet, MonthlySheet } from './components/HomeTab.jsx';
import ZodiacTab from './components/ZodiacTab.jsx';
import LoveTab, { CompatSheet, CoupleSheet } from './components/LoveTab.jsx';
import ProfileTab, { PartnerSheet } from './components/ProfileTab.jsx';
import { PartnerForm, EditProfileSheet } from './components/PartnerForm.jsx';
import { PremiumSheet } from './components/PremiumSheet.jsx';
import { Sheet } from './components/Glass.jsx';

const LS_KEY = 'tale_man_preview_v1';

function loadState() {
  try {
    const raw = localStorage.getItem(LS_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

const TABS = [
  { id: 'home', label: 'خانه', icon: homeIcon },
  { id: 'zodiac', label: 'برج من', icon: zodiacIcon },
  { id: 'love', label: 'عشق', icon: loveIcon },
  { id: 'profile', label: 'پروفایل', icon: personIcon },
];

export default function App() {
  const saved = useMemo(loadState, []);
  const [profile, setProfile] = useState(saved?.profile ?? null);
  const [partner, setPartner] = useState(saved?.partner ?? null);
  const [settings, setSettings] = useState(
    saved?.settings ?? { theme: 'dark', notifications: false, premium: false },
  );
  const [tab, setTab] = useState('home');
  const [sheet, setSheet] = useState(null); // {kind, param}
  const [toast, setToast] = useState(null);

  useEffect(() => {
    try {
      localStorage.setItem(LS_KEY, JSON.stringify({ profile, partner, settings }));
    } catch {
      /* storage full/blocked — preview still works in-memory */
    }
  }, [profile, partner, settings]);

  const showToast = useCallback((text) => {
    setToast(text);
    window.setTimeout(() => setToast(null), 2600);
  }, []);

  const enrichedProfile = useMemo(() => {
    if (!profile) return null;
    const g = jalaliToGregorian([profile.y, profile.m, profile.d]);
    const sign = zodiacForGregorian(g.getMonth() + 1, g.getDate());
    return { ...profile, sign, id: 'preview-profile' };
  }, [profile]);

  const closeSheet = useCallback(() => setSheet(null), []);

  const resetAll = () => {
    setProfile(null);
    setPartner(null);
    setSettings({ theme: 'dark', notifications: false, premium: false });
    setTab('home');
    setSheet(null);
    try {
      localStorage.removeItem(LS_KEY);
    } catch { /* ignore */ }
  };

  const light = settings.theme === 'light';

  return (
    <div className="min-h-screen bg-[#05070f] px-4 py-8" dir="rtl">
      {engineSelfCheckOk ? null : (
        <p className="mx-auto mb-4 max-w-[400px] rounded-xl bg-rose-500/20 p-3 text-center text-[11px] text-rose-200">
          هشدار فنی: وکتورهای موتور قطعی با نسخهٔ اصلی هم‌خوانی ندارند.
        </p>
      )}

      {/* header (outside the phone) */}
      <div className="mx-auto mb-6 max-w-[400px] text-center">
        <h1 className="gold-text text-2xl font-black">طالع من</h1>
        <p className="mt-1.5 text-[11px] text-slate-500">
          پیش‌نمایش وب — همان موتور قطعی نسخهٔ اندروید، کاملاً آفلاین روی دستگاه تو
        </p>
      </div>

      <PhoneFrame light={light}>
        {!enrichedProfile ? (
          <Onboarding
            onFinish={(p) => {
              setProfile({ name: p.name, y: p.y, m: p.m, d: p.d, time: p.time, city: p.city });
              setSettings((s) => ({ ...s, notifications: p.notifications }));
              setTab('home');
            }}
          />
        ) : (
          <div className="flex min-h-0 flex-1 flex-col">
            {/* content */}
            <main className="min-h-0 flex-1 overflow-y-auto" aria-live="polite">
              {tab === 'home' && (
                <HomeTab profile={enrichedProfile} onOpen={(kind) => setSheet({ kind })} />
              )}
              {tab === 'zodiac' && <ZodiacTab profile={enrichedProfile} />}
              {tab === 'love' && (
                <LoveTab
                  profile={enrichedProfile}
                  partner={partner ? { ...partner, sign: signById(partner.signId) } : null}
                  onOpen={(kind, param) => setSheet({ kind, param })}
                />
              )}
              {tab === 'profile' && (
                <ProfileTab
                  profile={enrichedProfile}
                  partner={partner ? { ...partner, sign: signById(partner.signId) } : null}
                  settings={settings}
                  onOpen={(kind) => setSheet({ kind })}
                  onSetTheme={(theme) => setSettings((s) => ({ ...s, theme }))}
                  onToggleNotifications={(v) => {
                    setSettings((s) => ({ ...s, notifications: v }));
                    showToast(v ? 'اطلاع‌رسانی روزانه فعال شد' : 'اطلاع‌رسانی خاموش شد');
                  }}
                  onResetAll={resetAll}
                />
              )}
            </main>

            {/* bottom nav */}
            <nav
              className="relative z-10 grid grid-cols-4 border-t border-white/[0.07] bg-midnight-900/80 backdrop-blur-xl light:border-slate-900/[0.07] light:bg-white/80"
              role="tablist"
              aria-label="ناوبری اصلی"
            >
              {TABS.map((t) => {
                const active = tab === t.id;
                return (
                  <button
                    key={t.id}
                    role="tab"
                    aria-selected={active}
                    onClick={() => setTab(t.id)}
                    className={`flex flex-col items-center gap-1 py-2.5 transition-colors ${
                      active ? 'text-gold-300' : 'text-slate-500 hover:text-slate-300'
                    }`}
                  >
                    {t.icon(active)}
                    <span className={`text-[10px] ${active ? 'font-bold' : 'font-medium'}`}>{t.label}</span>
                  </button>
                );
              })}
            </nav>

            {/* sheets */}
            {sheet?.kind === 'daily' && (
              <Sheet title="طالع کامل امروز" onClose={closeSheet}>
                <DailySheet profile={enrichedProfile} />
              </Sheet>
            )}
            {sheet?.kind === 'weekly' && (
              <Sheet title="طالع هفته" onClose={closeSheet}>
                <WeeklySheet profile={enrichedProfile} />
              </Sheet>
            )}
            {sheet?.kind === 'monthly' && (
              <Sheet title="طالع ماه" onClose={closeSheet}>
                <MonthlySheet profile={enrichedProfile} />
              </Sheet>
            )}
            {sheet?.kind === 'compat' && (
              <Sheet title={`سازگاری برج ${enrichedProfile.sign.nameFa} و ${signById(sheet.param).nameFa}`} onClose={closeSheet}>
                <CompatSheet profile={enrichedProfile} otherId={sheet.param} onClose={closeSheet} />
              </Sheet>
            )}
            {sheet?.kind === 'couple' && partner && (
              <Sheet title="تحلیل رابطهٔ شما" onClose={closeSheet}>
                <CoupleSheet
                  profile={enrichedProfile}
                  partner={partner}
                  onEditPartner={() => setSheet({ kind: 'partner' })}
                  onRemovePartner={() => {
                    setPartner(null);
                    setSheet(null);
                    showToast('شریک عاطفی حذف شد');
                  }}
                />
              </Sheet>
            )}
            {sheet?.kind === 'partner' && (
              <Sheet title={partner ? 'ویرایش شریک عاطفی' : 'افزودن شریک عاطفی'} onClose={closeSheet}>
                <PartnerSheet
                  partner={partner}
                  onClose={closeSheet}
                  onSave={(p) => {
                    setPartner(p);
                    setSheet({ kind: 'couple' });
                    showToast('شریک عاطفی ذخیره شد');
                  }}
                  onRemove={() => {
                    setPartner(null);
                    setSheet(null);
                    showToast('شریک عاطفی حذف شد');
                  }}
                />
              </Sheet>
            )}
            {sheet?.kind === 'edit-profile' && (
              <Sheet title="ویرایش پروفایل" onClose={closeSheet}>
                <EditProfileSheet
                  profile={enrichedProfile}
                  onSave={(p) => {
                    setProfile((old) => ({ ...old, name: p.name, y: p.y, m: p.m, d: p.d }));
                    setSheet(null);
                    showToast('پروفایل به‌روزرسانی شد');
                  }}
                />
              </Sheet>
            )}
            {sheet?.kind === 'premium' && (
              <Sheet title="طالع من ویژه" onClose={closeSheet}>
                <PremiumSheet
                  premium={settings.premium}
                  onSubscribe={(plan) => {
                    setSettings((s) => ({ ...s, premium: true }));
                    setSheet(null);
                    showToast(`اشتراک ${plan === 'lifetime' ? 'همیشگی' : plan === 'yearly' ? 'سالانه' : 'ماهانه'} فعال شد (نمایشی)`);
                  }}
                />
              </Sheet>
            )}

            {/* toast */}
            {toast && (
              <div className="pointer-events-none absolute bottom-24 left-1/2 z-50 -translate-x-1/2 animate-fade-up">
                <p className="rounded-full border border-white/10 bg-midnight-800/95 px-4 py-2 text-[11px] font-semibold text-slate-100 shadow-xl backdrop-blur">
                  {toast}
                </p>
              </div>
            )}
          </div>
        )}
      </PhoneFrame>

      <p className="mx-auto mt-6 max-w-[420px] text-center text-[10px] leading-6 text-slate-600">
        این پیش‌نمایش برای نمایش تجربهٔ اپلیکیشن است؛ نسخهٔ اصلی یک اپلیکیشن
        اندرویدی بومی است. محتوای طالع‌بینی بر پایهٔ astrologی سنتی و برای
        سرگرمی ارائه می‌شود و توصیهٔ قطعی در زمینهٔ سلامت، مالی یا حقوقی نیست.
      </p>
    </div>
  );
}

/* ── tab icons (inline SVG, no extra deps) ────────────────────────────── */

function homeIcon(active) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden>
      <path d="M3 10.5 12 3l9 7.5" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" />
      <path d="M5 9.5V21h5v-6h4v6h5V9.5" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" />
      {active && <circle cx="12" cy="12" r="1.4" fill="currentColor" />}
    </svg>
  );
}

function zodiacIcon(active) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden>
      <circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="1.5" opacity="0.5" />
      <circle cx="12" cy="12" r="5.2" stroke="currentColor" strokeWidth="1.5" opacity="0.8" />
      {active
        ? <circle cx="12" cy="12" r="1.8" fill="currentColor" />
        : <circle cx="12" cy="12" r="1.2" fill="currentColor" opacity="0.6" />}
    </svg>
  );
}

function loveIcon(active) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill={active ? 'currentColor' : 'none'} aria-hidden>
      <path
        d="M12 20.5s-7.5-4.6-9.3-9.3C1.4 7.7 3.6 4.5 7 4.5c2.2 0 3.9 1.2 5 3 1.1-1.8 2.8-3 5-3 3.4 0 5.6 3.2 4.3 6.7-1.8 4.7-9.3 9.3-9.3 9.3z"
        stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round"
      />
    </svg>
  );
}

function personIcon(active) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden>
      <circle cx="12" cy="8" r="4" stroke="currentColor" strokeWidth="1.7" />
      <path d="M4.5 20.5c1.2-3.5 4-5.5 7.5-5.5s6.3 2 7.5 5.5" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
      {active && <circle cx="12" cy="8" r="1.5" fill="currentColor" />}
    </svg>
  );
}
