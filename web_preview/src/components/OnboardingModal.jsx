import React, { useState } from 'react';
import {
  ChevronRight,
  ChevronLeft,
  Sparkles,
  Search,
  CheckCircle2,
  Check
} from 'lucide-react';
import { IRAN_LOCATION_DATA, USAGE_TYPES } from '../utils/helpers';

export default function OnboardingModal({ isOpen, onComplete, initialData }) {
  if (!isOpen) return null;

  const [step, setStep] = useState(1);
  const [name, setName] = useState(initialData?.name || '');
  const [currency, setCurrency] = useState(initialData?.currency || 'تومان');
  const [country, setCountry] = useState(initialData?.country || 'ایران');
  const [province, setProvince] = useState(initialData?.province || 'تهران');
  const [city, setCity] = useState(initialData?.city || 'تهران');
  const [citySearch, setCitySearch] = useState('');
  const [usageType, setUsageType] = useState(initialData?.usageType || 'store');

  const currencies = [
    { id: 'IRR', name: 'ریال', flag: '🇮🇷' },
    { id: 'IRT', name: 'تومان', flag: '🇮🇷' },
    { id: 'USD', name: 'دلار', flag: '🇺🇸' },
    { id: 'EUR', name: 'یورو', flag: '🇪🇺' },
    { id: 'CAD', name: 'دلار کانادا', flag: '🇨🇦' },
    { id: 'TRY', name: 'لیر', flag: '🇹🇷' },
    { id: 'AFN', name: 'افغانی', flag: '🇦🇫' }
  ];

  const provinces = Object.keys(IRAN_LOCATION_DATA);
  const currentCities = IRAN_LOCATION_DATA[province] || ['تهران'];

  const filteredCities = currentCities.filter(c =>
    c.includes(citySearch.trim())
  );

  const handleNext = () => {
    if (step === 1 && !name.trim()) return;
    if (step < 5) {
      setStep(step + 1);
    } else {
      onComplete({
        name,
        currency,
        country,
        province: country === 'ایران' ? province : '',
        city,
        usageType,
        isOnboarded: true
      });
    }
  };

  const handlePrev = () => {
    if (step > 1) setStep(step - 1);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-md animate-fade-in font-vazir">
      <div className="w-full max-w-lg bg-white dark:bg-slate-800 rounded-3xl shadow-2xl overflow-hidden flex flex-col border border-slate-100 dark:border-slate-700">
        
        {/* Top Indicator Header (Screenshot 11 & 9) */}
        <div className="p-4 flex items-center justify-between border-b border-slate-100 dark:border-slate-700 text-xs">
          {step > 1 ? (
            <button onClick={handlePrev} className="p-1 text-slate-500 hover:text-slate-800 transition">
              <ChevronRight className="w-5 h-5" />
            </button>
          ) : <div className="w-5" />}

          {/* Step Progress Bar */}
          <div className="flex gap-1 justify-center flex-1 max-w-xs mx-4">
            {[1, 2, 3, 4, 5].map(s => (
              <div
                key={s}
                className={`h-1 flex-1 rounded-full transition-all ${
                  s <= step ? 'bg-sky-500' : 'bg-slate-200 dark:bg-slate-700'
                }`}
              />
            ))}
          </div>

          <button
            onClick={() => handleNext()}
            className="text-slate-400 hover:text-slate-600 font-bold flex items-center gap-0.5"
          >
            <span>بعدا</span>
            <ChevronLeft className="w-4 h-4" />
          </button>
        </div>

        {/* Content by Step */}
        <div className="p-6 flex-1 overflow-y-auto max-h-[65vh]">
          
          {/* STEP 1: Name (Screenshot 11) */}
          {step === 1 && (
            <div className="space-y-6 text-center animate-fade-in">
              {/* Mascot */}
              <div className="w-28 h-28 mx-auto rounded-full bg-sky-100 dark:bg-sky-900/40 flex items-center justify-center text-6xl shadow-inner">
                🦉
              </div>

              <div>
                <h3 className="text-xl font-bold text-slate-800 dark:text-white">سلام!</h3>
                <h2 className="text-2xl font-black text-slate-900 dark:text-white mt-1 mb-2">
                  من فیدا هستم
                </h2>
                <p className="text-slate-500 dark:text-slate-300 text-xs leading-relaxed">
                  همراه همیشگی تو توی مسیر صدور فاکتور و مدیریت کارهات.
                </p>
                <p className="text-slate-700 dark:text-slate-200 font-bold text-xs mt-2">
                  برای شروع، اسمتو بهم بگو
                </p>
              </div>

              <div className="max-w-md mx-auto">
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="اینجا بنویس"
                  autoFocus
                  className="w-full px-4 py-3.5 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-100/70 dark:bg-slate-900 text-slate-800 dark:text-white text-center text-sm font-bold focus:border-sky-500 focus:bg-white focus:outline-none transition"
                />
              </div>
            </div>
          )}

          {/* STEP 2: Currency Selection (Screenshot 9) */}
          {step === 2 && (
            <div className="space-y-4 animate-fade-in">
              <div className="text-center">
                <div className="w-20 h-20 mx-auto rounded-full bg-sky-100 dark:bg-sky-900/40 flex items-center justify-center text-4xl mb-2">
                  🦉
                </div>
                <h2 className="text-lg font-bold text-slate-900 dark:text-white">
                  انتخاب ارز
                </h2>
              </div>

              <div className="space-y-2 max-h-64 overflow-y-auto">
                {currencies.map((c) => {
                  const isSelected = currency === c.name;
                  return (
                    <button
                      key={c.id}
                      onClick={() => setCurrency(c.name)}
                      className={`w-full p-3.5 rounded-2xl border text-right flex items-center justify-between transition ${
                        isSelected
                          ? 'border-sky-500 bg-sky-50/50 dark:bg-sky-900/30 text-slate-900 dark:text-white font-bold shadow-xs'
                          : 'border-slate-100 dark:border-slate-700 hover:bg-slate-50 dark:hover:bg-slate-700/50 text-slate-700 dark:text-slate-300'
                      }`}
                    >
                      <div className="flex items-center gap-2">
                        {isSelected && (
                          <CheckCircle2 className="w-5 h-5 text-sky-500 fill-sky-500 text-white shrink-0" />
                        )}
                      </div>

                      <div className="flex items-center gap-2">
                        <span className="text-sm font-bold">{c.name}</span>
                        <span className="text-lg">{c.flag}</span>
                      </div>
                    </button>
                  );
                })}
              </div>
            </div>
          )}

          {/* STEP 3: Province / City */}
          {step === 3 && (
            <div className="space-y-4 animate-fade-in">
              <div className="text-center">
                <h2 className="text-lg font-bold text-slate-900 dark:text-white">
                  انتخاب استان و شهر
                </h2>
              </div>

              <div className="space-y-3">
                <div>
                  <label className="block text-xs font-bold text-slate-600 dark:text-slate-400 mb-1">
                    استان
                  </label>
                  <select
                    value={province}
                    onChange={(e) => {
                      setProvince(e.target.value);
                      setCity(IRAN_LOCATION_DATA[e.target.value]?.[0] || '');
                    }}
                    className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-100/70 dark:bg-slate-900 text-slate-800 dark:text-white text-xs font-bold"
                  >
                    {provinces.map(p => (
                      <option key={p} value={p}>{p}</option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-600 dark:text-slate-400 mb-1">
                    شهر
                  </label>
                  <div className="relative mb-2">
                    <Search className="w-4 h-4 absolute right-3 top-3 text-slate-400" />
                    <input
                      type="text"
                      value={citySearch}
                      onChange={(e) => setCitySearch(e.target.value)}
                      placeholder="جستجوی شهر..."
                      className="w-full pr-9 pl-3 py-2 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-100/70 dark:bg-slate-900 text-xs"
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-2 max-h-36 overflow-y-auto">
                    {filteredCities.map(ct => (
                      <button
                        key={ct}
                        onClick={() => setCity(ct)}
                        className={`p-2 rounded-xl text-xs border text-center transition ${
                          city === ct
                            ? 'border-sky-500 bg-sky-500 text-white font-bold shadow-xs'
                            : 'border-slate-200 dark:border-slate-700 hover:bg-slate-100 text-slate-700 dark:text-slate-300'
                        }`}
                      >
                        {ct}
                      </button>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* STEP 4: Activity Type */}
          {step === 4 && (
            <div className="space-y-4 animate-fade-in">
              <div className="text-center">
                <h2 className="text-lg font-bold text-slate-900 dark:text-white">
                  نوع فعالیت شما
                </h2>
              </div>

              <div className="grid grid-cols-1 gap-2 max-h-60 overflow-y-auto">
                {USAGE_TYPES.map((u) => (
                  <button
                    key={u.id}
                    onClick={() => setUsageType(u.id)}
                    className={`p-3 rounded-2xl border text-right transition ${
                      usageType === u.id
                        ? 'border-sky-500 bg-sky-50/50 dark:bg-sky-900/30 text-sky-600 dark:text-sky-300 font-bold'
                        : 'border-slate-100 dark:border-slate-700 hover:bg-slate-50 text-slate-700 dark:text-slate-300'
                    }`}
                  >
                    <div className="text-sm font-bold">{u.title}</div>
                    <div className="text-[11px] text-slate-400">{u.desc}</div>
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* STEP 5: Welcome Final */}
          {step === 5 && (
            <div className="space-y-4 text-center animate-fade-in py-2">
              <div className="w-16 h-16 mx-auto rounded-full bg-emerald-100 text-emerald-600 flex items-center justify-center font-bold text-2xl shadow-md">
                <Check className="w-10 h-10" />
              </div>

              <h2 className="text-xl font-black text-slate-900 dark:text-white">
                خوش آمدید، {name}! 🎉
              </h2>

              <p className="text-xs text-slate-500 leading-relaxed">
                تنظیمات شما با ارز ({currency}) ثبت گردید. هم‌اکنون می‌توانید فاکتورهای خود را صادر کنید.
              </p>
            </div>
          )}

        </div>

        {/* Footer Button (Screenshot 11 & 9) */}
        <div className="p-4 bg-slate-50 dark:bg-slate-900 border-t border-slate-100 dark:border-slate-700">
          <button
            onClick={handleNext}
            disabled={step === 1 && !name.trim()}
            className={`w-full py-3.5 rounded-2xl font-bold text-xs shadow-md transition active:scale-98 ${
              step === 1 && !name.trim()
                ? 'bg-slate-300 text-slate-500 cursor-not-allowed'
                : 'bg-sky-500 hover:bg-sky-600 text-white shadow-sky-500/20'
            }`}
          >
            {step === 5 ? 'شروع استفاده از فاکتورساز جاوید' : (step === 1 ? 'بعدی' : 'ادامه')}
          </button>
        </div>

      </div>
    </div>
  );
}
