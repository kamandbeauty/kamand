import React, { useState } from 'react';
import {
  Check,
  ChevronLeft,
  ChevronRight,
  Sparkles,
  MapPin,
  Store,
  Wrench,
  PackageCheck,
  Laptop,
  User,
  Calculator,
  Briefcase,
  Search,
  CheckCircle2
} from 'lucide-react';
import { COUNTRIES, IRAN_LOCATION_DATA, USAGE_TYPES } from '../utils/helpers';

export default function OnboardingModal({ isOpen, onComplete, initialData }) {
  if (!isOpen) return null;

  const [step, setStep] = useState(1);
  const [name, setName] = useState(initialData?.name || '');
  const [country, setCountry] = useState(initialData?.country || 'ایران');
  const [province, setProvince] = useState(initialData?.province || 'تهران');
  const [city, setCity] = useState(initialData?.city || 'تهران');
  const [citySearch, setCitySearch] = useState('');
  const [usageType, setUsageType] = useState(initialData?.usageType || 'store');

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

  const getUsageIcon = (iconName) => {
    switch (iconName) {
      case 'Store': return <Store className="w-6 h-6" />;
      case 'Wrench': return <Wrench className="w-6 h-6" />;
      case 'PackageCheck': return <PackageCheck className="w-6 h-6" />;
      case 'Laptop': return <Laptop className="w-6 h-6" />;
      case 'User': return <User className="w-6 h-6" />;
      case 'Calculator': return <Calculator className="w-6 h-6" />;
      default: return <Briefcase className="w-6 h-6" />;
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-md animate-fade-in">
      <div className="w-full max-w-xl bg-white dark:bg-slate-800 rounded-3xl shadow-2xl overflow-hidden flex flex-col border border-slate-100 dark:border-slate-700">
        
        {/* Progress Bar */}
        <div className="bg-slate-100 dark:bg-slate-700 h-2 w-full">
          <div
            className="bg-blue-600 h-2 transition-all duration-300 ease-out"
            style={{ width: `${(step / 5) * 100}%` }}
          />
        </div>

        {/* Card Header */}
        <div className="p-6 text-center pb-2">
          <div className="inline-flex items-center justify-center w-14 h-14 rounded-2xl bg-blue-50 dark:bg-blue-900/40 text-blue-600 dark:text-blue-400 mb-3 shadow-inner">
            <Sparkles className="w-7 h-7" />
          </div>
          <span className="text-xs font-bold text-blue-600 dark:text-blue-400 block mb-1">
            مرحله {step} از ۵
          </span>
        </div>

        {/* Card Body by Step */}
        <div className="px-6 py-4 flex-1 overflow-y-auto max-h-[60vh]">
          
          {/* STEP 1: Name */}
          {step === 1 && (
            <div className="space-y-6 text-center animate-fade-in">
              <div>
                <h2 className="text-2xl font-black text-slate-800 dark:text-white mb-2">
                  سلام! من فیدا هستم 👋
                </h2>
                <p className="text-slate-500 dark:text-slate-300 text-sm">
                  اسم شما چیه؟
                </p>
              </div>

              <div className="max-w-md mx-auto">
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="مثلاً: علی رضایی..."
                  autoFocus
                  className="w-full px-4 py-3.5 rounded-2xl border-2 border-slate-200 dark:border-slate-600 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white text-center text-lg font-bold focus:border-blue-600 focus:bg-white focus:outline-none transition"
                />
                {!name.trim() && (
                  <p className="text-xs text-amber-500 mt-2">
                    لطفا نام خود را وارد کنید تا ادامه دهیم
                  </p>
                )}
              </div>
            </div>
          )}

          {/* STEP 2: Country Selection */}
          {step === 2 && (
            <div className="space-y-4 animate-fade-in">
              <div className="text-center mb-4">
                <h2 className="text-xl font-bold text-slate-800 dark:text-white">
                  کشور محل فعالیت خود را انتخاب کنید
                </h2>
                <p className="text-xs text-slate-500 dark:text-slate-400">
                  کشور پیش‌فرض برای صدور فاکتور و واحد مالی
                </p>
              </div>

              <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                {COUNTRIES.map((c) => (
                  <button
                    key={c.id}
                    onClick={() => setCountry(c.name)}
                    className={`p-3.5 rounded-2xl border-2 text-right flex items-center gap-3 transition ${
                      country === c.name
                        ? 'border-blue-600 bg-blue-50/50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 font-bold shadow-sm'
                        : 'border-slate-200 dark:border-slate-700 hover:border-slate-300 dark:hover:border-slate-600 text-slate-700 dark:text-slate-300'
                    }`}
                  >
                    <span className="text-2xl">{c.flag}</span>
                    <span className="text-sm">{c.name}</span>
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* STEP 3: City/Province Selection */}
          {step === 3 && (
            <div className="space-y-4 animate-fade-in">
              <div className="text-center mb-4">
                <h2 className="text-xl font-bold text-slate-800 dark:text-white">
                  انتخاب استان و شهر
                </h2>
                <p className="text-xs text-slate-500 dark:text-slate-400">
                  {country === 'ایران' ? 'استان و شهر محل کسب و کار شما' : 'شهر محل استقرار شما'}
                </p>
              </div>

              {country === 'ایران' ? (
                <div className="space-y-4">
                  {/* Province Dropdown */}
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
                      className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-medium focus:border-blue-600 focus:outline-none"
                    >
                      {provinces.map(p => (
                        <option key={p} value={p}>{p}</option>
                      ))}
                    </select>
                  </div>

                  {/* City Search & Select */}
                  <div>
                    <label className="block text-xs font-bold text-slate-600 dark:text-slate-400 mb-1">
                      شهر (با قابلیت جستجو)
                    </label>
                    <div className="relative mb-2">
                      <Search className="w-4 h-4 absolute right-3 top-3.5 text-slate-400" />
                      <input
                        type="text"
                        value={citySearch}
                        onChange={(e) => setCitySearch(e.target.value)}
                        placeholder="جستجوی شهر..."
                        className="w-full pr-9 pl-3 py-2.5 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white text-xs"
                      />
                    </div>

                    <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 max-h-44 overflow-y-auto p-1">
                      {filteredCities.map(ct => (
                        <button
                          key={ct}
                          onClick={() => setCity(ct)}
                          className={`p-2.5 rounded-xl text-xs text-center border transition ${
                            city === ct
                              ? 'border-blue-600 bg-blue-600 text-white font-bold shadow'
                              : 'border-slate-200 dark:border-slate-700 hover:bg-slate-100 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300'
                          }`}
                        >
                          {ct}
                        </button>
                      ))}
                    </div>
                  </div>
                </div>
              ) : (
                <div className="max-w-md mx-auto">
                  <label className="block text-xs font-bold text-slate-600 dark:text-slate-400 mb-1">
                    نام شهر
                  </label>
                  <input
                    type="text"
                    value={city}
                    onChange={(e) => setCity(e.target.value)}
                    placeholder="مثال: استانبول، تورنتو..."
                    className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white text-sm font-medium focus:border-blue-600 focus:outline-none"
                  />
                </div>
              )}
            </div>
          )}

          {/* STEP 4: Usage Type */}
          {step === 4 && (
            <div className="space-y-4 animate-fade-in">
              <div className="text-center mb-4">
                <h2 className="text-xl font-bold text-slate-800 dark:text-white">
                  نوع فعالیت شما چیست؟
                </h2>
                <p className="text-xs text-slate-500 dark:text-slate-400">
                  برای شخصی‌سازی فاکتورها و گزارش‌های شما
                </p>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 max-h-60 overflow-y-auto p-1">
                {USAGE_TYPES.map((u) => (
                  <button
                    key={u.id}
                    onClick={() => setUsageType(u.id)}
                    className={`p-3.5 rounded-2xl border-2 text-right flex items-start gap-3 transition ${
                      usageType === u.id
                        ? 'border-blue-600 bg-blue-50/50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 shadow-sm'
                        : 'border-slate-200 dark:border-slate-700 hover:border-slate-300 dark:hover:border-slate-600 text-slate-700 dark:text-slate-300'
                    }`}
                  >
                    <div className={`p-2 rounded-xl ${usageType === u.id ? 'bg-blue-600 text-white' : 'bg-slate-100 dark:bg-slate-700 text-slate-500'}`}>
                      {getUsageIcon(u.icon)}
                    </div>
                    <div>
                      <h3 className="font-bold text-sm text-slate-800 dark:text-white mb-0.5">{u.title}</h3>
                      <p className="text-[11px] text-slate-500 dark:text-slate-400 leading-tight">{u.desc}</p>
                    </div>
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* STEP 5: Welcome Final */}
          {step === 5 && (
            <div className="space-y-6 text-center animate-fade-in py-2">
              <div className="w-16 h-16 mx-auto rounded-full bg-emerald-100 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400 flex items-center justify-center shadow-lg">
                <CheckCircle2 className="w-10 h-10" />
              </div>

              <div>
                <h2 className="text-2xl font-black text-slate-800 dark:text-white mb-2">
                  خوش آمدید، {name}! 🎉
                </h2>
                <p className="text-slate-500 dark:text-slate-300 text-sm">
                  همه چیز برای شروع صدور آسان فاکتور و مدیریت مالی آماده است.
                </p>
              </div>

              <div className="bg-slate-50 dark:bg-slate-900/80 rounded-2xl p-4 border border-slate-200 dark:border-slate-700 text-right space-y-2 text-xs text-slate-600 dark:text-slate-300">
                <div className="flex justify-between border-b border-slate-200 dark:border-slate-800 pb-1.5">
                  <span className="text-slate-400">نام:</span>
                  <span className="font-bold text-slate-800 dark:text-white">{name}</span>
                </div>
                <div className="flex justify-between border-b border-slate-200 dark:border-slate-800 pb-1.5">
                  <span className="text-slate-400">موقعیت:</span>
                  <span className="font-bold text-slate-800 dark:text-white">{country} - {city}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-400">نوع فعالیت:</span>
                  <span className="font-bold text-slate-800 dark:text-white">
                    {USAGE_TYPES.find(u => u.id === usageType)?.title || 'کسب و کار'}
                  </span>
                </div>
              </div>
            </div>
          )}

        </div>

        {/* Card Footer Actions */}
        <div className="p-4 bg-slate-50 dark:bg-slate-900/50 border-t border-slate-100 dark:border-slate-700/50 flex items-center justify-between">
          {step > 1 && step < 5 ? (
            <button
              onClick={handlePrev}
              className="flex items-center gap-1 px-4 py-2.5 rounded-xl border border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300 font-medium text-xs hover:bg-slate-100 dark:hover:bg-slate-700 transition"
            >
              <ChevronRight className="w-4 h-4" />
              <span>قبلی</span>
            </button>
          ) : <div />}

          <button
            onClick={handleNext}
            disabled={step === 1 && !name.trim()}
            className={`flex items-center gap-1.5 px-6 py-2.5 rounded-xl font-bold text-xs shadow-lg transition active:scale-95 ${
              step === 1 && !name.trim()
                ? 'bg-slate-300 text-slate-500 cursor-not-allowed shadow-none'
                : 'bg-blue-600 hover:bg-blue-700 text-white shadow-blue-500/25'
            }`}
          >
            <span>{step === 5 ? 'شروع استفاده از فاکتور فیدا' : 'بعدی'}</span>
            {step < 5 && <ChevronLeft className="w-4 h-4" />}
          </button>
        </div>

      </div>
    </div>
  );
}
