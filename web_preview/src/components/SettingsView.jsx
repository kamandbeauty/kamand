import React, { useState, useEffect } from 'react';
import {
  Settings,
  User,
  Building2,
  FileText,
  Palette,
  Save,
  Check,
  CreditCard,
  Plus,
  Trash2,
  ArrowRight
} from 'lucide-react';
import { USAGE_TYPES, COUNTRIES, IRAN_LOCATION_DATA } from '../utils/helpers';

export default function SettingsView({
  user,
  business,
  settings,
  onSaveUser,
  onSaveBusiness,
  onSaveSettings,
  isDarkMode,
  onToggleDarkMode,
  onBack
}) {
  // ── User Profile ──
  const [userName, setUserName] = useState(user?.name || '');
  const [userCountry, setUserCountry] = useState(user?.country || 'ایران');
  const [userProvince, setUserProvince] = useState(user?.province || 'تهران');
  const [userCity, setUserCity] = useState(user?.city || 'تهران');
  const [userUsage, setUserUsage] = useState(user?.usageType || 'store');
  const [userCurrency, setUserCurrency] = useState(user?.currency || 'تومان');

  // ── Business ──
  const [shopName, setShopName] = useState(business?.shopName || '');
  const [phone, setPhone] = useState(business?.phone || '');
  const [address, setAddress] = useState(business?.address || '');
  const [taxId, setTaxId] = useState(business?.taxId || '');
  const [bankCards, setBankCards] = useState(business?.bankCards || []);

  const [newBank, setNewBank] = useState('');
  const [newCardNum, setNewCardNum] = useState('');
  const [newCardOwner, setNewCardOwner] = useState('');

  // ── Invoice Settings ──
  const [startingNum, setStartingNum] = useState(settings?.startingInvoiceNum ?? 1004);
  const [templateStyle, setTemplateStyle] = useState(settings?.templateStyle || 'modern');
  const [showLogo, setShowLogo] = useState(settings?.showLogo !== false);
  const [showCardNum, setShowCardNum] = useState(settings?.showCardNum !== false);

  const [savedSuccess, setSavedSuccess] = useState(false);
  const [dirty, setDirty] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');

  // Sync local form when parent props change (e.g. after restore / reset)
  useEffect(() => {
    setUserName(user?.name || '');
    setUserCountry(user?.country || 'ایران');
    setUserProvince(user?.province || 'تهران');
    setUserCity(user?.city || 'تهران');
    setUserUsage(user?.usageType || 'store');
    setUserCurrency(user?.currency || 'تومان');
  }, [user]);

  useEffect(() => {
    setShopName(business?.shopName || '');
    setPhone(business?.phone || '');
    setAddress(business?.address || '');
    setTaxId(business?.taxId || '');
    setBankCards(business?.bankCards || []);
  }, [business]);

  useEffect(() => {
    setStartingNum(settings?.startingInvoiceNum ?? 1004);
    setTemplateStyle(settings?.templateStyle || 'modern');
    setShowLogo(settings?.showLogo !== false);
    setShowCardNum(settings?.showCardNum !== false);
  }, [settings]);

  const markDirty = () => {
    setDirty(true);
    setSavedSuccess(false);
    setErrorMsg('');
  };

  const provinces = Object.keys(IRAN_LOCATION_DATA || {});
  const cities =
    userCountry === 'ایران' && IRAN_LOCATION_DATA[userProvince]
      ? IRAN_LOCATION_DATA[userProvince]
      : [];

  const handleSaveAll = (e) => {
    if (e) e.preventDefault();
    setErrorMsg('');

    const name = String(userName || '').trim();
    if (!name) {
      setErrorMsg('نام کاربر نمی‌تواند خالی باشد.');
      return;
    }

    const nextUser = {
      ...(user || {}),
      name,
      country: userCountry,
      province: userProvince,
      city: userCity,
      usageType: userUsage,
      currency: userCurrency,
      isOnboarded: true
    };

    const nextBusiness = {
      ...(business || {}),
      shopName: String(shopName || '').trim() || 'فروشگاه روبی',
      phone: String(phone || '').trim(),
      address: String(address || '').trim(),
      taxId: String(taxId || '').trim(),
      bankCards: bankCards || []
    };

    const nextSettings = {
      ...(settings || {}),
      startingInvoiceNum: parseInt(startingNum, 10) || 1004,
      templateStyle,
      showLogo: Boolean(showLogo),
      showCardNum: Boolean(showCardNum)
    };

    try {
      if (typeof onSaveUser === 'function') onSaveUser(nextUser);
      if (typeof onSaveBusiness === 'function') onSaveBusiness(nextBusiness);
      if (typeof onSaveSettings === 'function') onSaveSettings(nextSettings);

      setDirty(false);
      setSavedSuccess(true);
      setTimeout(() => setSavedSuccess(false), 2500);
    } catch (err) {
      console.error(err);
      setErrorMsg('خطا در ذخیره تنظیمات. دوباره تلاش کنید.');
    }
  };

  const handleAddCard = () => {
    const num = String(newCardNum || '').trim();
    if (!num) {
      setErrorMsg('شماره کارت را وارد کنید.');
      return;
    }
    setBankCards([
      ...(bankCards || []),
      {
        id: Date.now().toString(),
        bank: String(newBank || '').trim() || 'بانک',
        number: num,
        owner: String(newCardOwner || userName || '').trim()
      }
    ]);
    setNewBank('');
    setNewCardNum('');
    setNewCardOwner('');
    markDirty();
  };

  const handleRemoveCard = (id) => {
    setBankCards((bankCards || []).filter((c) => c.id !== id));
    markDirty();
  };

  const fieldClass =
    'w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-slate-800 dark:text-white font-bold text-sm outline-none focus:border-[#F97316] focus:ring-2 focus:ring-orange-200 dark:focus:ring-orange-900/40 transition disabled:opacity-60';
  const labelClass = 'block font-bold text-slate-700 dark:text-slate-300 mb-1.5 text-xs';

  return (
    <form
      onSubmit={handleSaveAll}
      className="space-y-5 max-w-4xl mx-auto animate-fade-in pb-28"
      dir="rtl"
    >
      {/* Top Banner */}
      <div className="bg-white dark:bg-slate-800 p-4 sm:p-5 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm flex items-center justify-between gap-3">
        <div className="flex items-center gap-3 min-w-0">
          {onBack && (
            <button
              type="button"
              onClick={onBack}
              className="p-2 rounded-xl bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-200 shrink-0"
              title="بازگشت"
            >
              <ArrowRight className="w-5 h-5" />
            </button>
          )}
          <div className="w-10 h-10 rounded-2xl bg-[#F97316] text-white flex items-center justify-center font-bold shrink-0">
            <Settings className="w-5 h-5" />
          </div>
          <div className="min-w-0">
            <h2 className="font-bold text-base sm:text-lg text-slate-800 dark:text-white truncate">
              تنظیمات برنامه
            </h2>
            <p className="text-[11px] text-slate-400">
              ویرایش مشخصات کاربر، کسب‌وکار و ظاهر فاکتور
            </p>
          </div>
        </div>

        <button
          type="submit"
          className="px-4 sm:px-5 py-2.5 rounded-2xl bg-[#F97316] hover:bg-[#EA580C] text-white font-bold text-xs shadow-md shadow-orange-500/20 flex items-center gap-1.5 transition active:scale-95 shrink-0"
        >
          {savedSuccess ? <Check className="w-4 h-4" /> : <Save className="w-4 h-4" />}
          <span>{savedSuccess ? 'ذخیره شد!' : 'ذخیره'}</span>
        </button>
      </div>

      {errorMsg && (
        <div className="p-3 rounded-2xl bg-rose-50 dark:bg-rose-900/30 border border-rose-200 dark:border-rose-800 text-rose-600 dark:text-rose-300 text-xs font-bold">
          {errorMsg}
        </div>
      )}

      {dirty && !savedSuccess && (
        <div className="p-3 rounded-2xl bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 text-amber-700 dark:text-amber-300 text-xs font-bold">
          تغییراتی دارید که هنوز ذخیره نشده‌اند. روی «ذخیره» بزنید.
        </div>
      )}

      {/* 1. User Profile */}
      <section className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm space-y-4">
        <div className="flex items-center gap-2 pb-2 border-b border-slate-100 dark:border-slate-700">
          <User className="w-5 h-5 text-[#F97316]" />
          <h3 className="font-bold text-sm text-slate-800 dark:text-white">پروفایل کاربر</h3>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className={labelClass} htmlFor="user-name">
              نام شما *
            </label>
            <input
              id="user-name"
              name="userName"
              type="text"
              autoComplete="name"
              value={userName}
              onChange={(e) => {
                setUserName(e.target.value);
                markDirty();
              }}
              placeholder="مثلاً: علی علوی"
              className={fieldClass}
            />
          </div>

          <div>
            <label className={labelClass} htmlFor="user-currency">
              واحد پول
            </label>
            <select
              id="user-currency"
              name="currency"
              value={userCurrency}
              onChange={(e) => {
                setUserCurrency(e.target.value);
                markDirty();
              }}
              className={`${fieldClass} font-medium`}
            >
              {['تومان', 'ریال', 'دلار', 'یورو', 'دلار کانادا', 'لیر', 'افغانی'].map((c) => (
                <option key={c} value={c}>
                  {c}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className={labelClass} htmlFor="user-country">
              کشور
            </label>
            <select
              id="user-country"
              name="country"
              value={userCountry}
              onChange={(e) => {
                setUserCountry(e.target.value);
                markDirty();
              }}
              className={`${fieldClass} font-medium`}
            >
              {COUNTRIES.map((c) => (
                <option key={c.id} value={c.name}>
                  {c.flag} {c.name}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className={labelClass} htmlFor="user-province">
              استان
            </label>
            {userCountry === 'ایران' && provinces.length > 0 ? (
              <select
                id="user-province"
                name="province"
                value={userProvince}
                onChange={(e) => {
                  const p = e.target.value;
                  setUserProvince(p);
                  const list = IRAN_LOCATION_DATA[p] || [];
                  if (list.length && !list.includes(userCity)) {
                    setUserCity(list[0]);
                  }
                  markDirty();
                }}
                className={`${fieldClass} font-medium`}
              >
                {provinces.map((p) => (
                  <option key={p} value={p}>
                    {p}
                  </option>
                ))}
              </select>
            ) : (
              <input
                id="user-province"
                name="province"
                type="text"
                value={userProvince}
                onChange={(e) => {
                  setUserProvince(e.target.value);
                  markDirty();
                }}
                className={fieldClass}
              />
            )}
          </div>

          <div>
            <label className={labelClass} htmlFor="user-city">
              شهر
            </label>
            {userCountry === 'ایران' && cities.length > 0 ? (
              <select
                id="user-city"
                name="city"
                value={userCity}
                onChange={(e) => {
                  setUserCity(e.target.value);
                  markDirty();
                }}
                className={`${fieldClass} font-medium`}
              >
                {cities.map((c) => (
                  <option key={c} value={c}>
                    {c}
                  </option>
                ))}
              </select>
            ) : (
              <input
                id="user-city"
                name="city"
                type="text"
                value={userCity}
                onChange={(e) => {
                  setUserCity(e.target.value);
                  markDirty();
                }}
                className={fieldClass}
              />
            )}
          </div>

          <div>
            <label className={labelClass} htmlFor="user-usage">
              نوع فعالیت
            </label>
            <select
              id="user-usage"
              name="usageType"
              value={userUsage}
              onChange={(e) => {
                setUserUsage(e.target.value);
                markDirty();
              }}
              className={`${fieldClass} font-medium`}
            >
              {USAGE_TYPES.map((u) => (
                <option key={u.id} value={u.id}>
                  {u.title}
                </option>
              ))}
            </select>
          </div>
        </div>
      </section>

      {/* 2. Business Profile */}
      <section className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm space-y-4">
        <div className="flex items-center gap-2 pb-2 border-b border-slate-100 dark:border-slate-700">
          <Building2 className="w-5 h-5 text-indigo-500" />
          <h3 className="font-bold text-sm text-slate-800 dark:text-white">
            اطلاعات کسب‌وکار و سربرگ فاکتور
          </h3>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className={labelClass} htmlFor="shop-name">
              نام فروشگاه / کسب‌وکار
            </label>
            <input
              id="shop-name"
              name="shopName"
              type="text"
              value={shopName}
              onChange={(e) => {
                setShopName(e.target.value);
                markDirty();
              }}
              placeholder="مثلاً: فروشگاه روبی"
              className={fieldClass}
            />
          </div>

          <div>
            <label className={labelClass} htmlFor="shop-phone">
              شماره تماس پشتیبانی
            </label>
            <input
              id="shop-phone"
              name="phone"
              type="tel"
              value={phone}
              onChange={(e) => {
                setPhone(e.target.value);
                markDirty();
              }}
              className={fieldClass}
              dir="ltr"
              style={{ textAlign: 'right' }}
            />
          </div>

          <div className="sm:col-span-2">
            <label className={labelClass} htmlFor="shop-address">
              آدرس کامل کسب‌وکار
            </label>
            <input
              id="shop-address"
              name="address"
              type="text"
              value={address}
              onChange={(e) => {
                setAddress(e.target.value);
                markDirty();
              }}
              className={fieldClass}
            />
          </div>

          <div>
            <label className={labelClass} htmlFor="shop-tax">
              شناسه ملی / کد اقتصادی
            </label>
            <input
              id="shop-tax"
              name="taxId"
              type="text"
              value={taxId}
              onChange={(e) => {
                setTaxId(e.target.value);
                markDirty();
              }}
              className={fieldClass}
            />
          </div>
        </div>

        {/* Bank Cards */}
        <div className="pt-3 border-t border-slate-100 dark:border-slate-700 space-y-3">
          <label className="block font-bold text-xs text-slate-700 dark:text-slate-300">
            شماره کارت‌های بانکی ثبت‌شده
          </label>

          <div className="space-y-2">
            {(bankCards || []).length === 0 && (
              <div className="text-[11px] text-slate-400 py-2">هنوز کارتی ثبت نشده است.</div>
            )}
            {(bankCards || []).map((card) => (
              <div
                key={card.id}
                className="p-3 bg-slate-50 dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-700 flex items-center justify-between text-xs gap-2"
              >
                <div className="flex items-center gap-2 min-w-0 flex-wrap">
                  <CreditCard className="w-4 h-4 text-[#F97316] shrink-0" />
                  <span className="font-bold text-slate-800 dark:text-white">{card.bank}:</span>
                  <span className="font-mono text-slate-700 dark:text-slate-300" dir="ltr">
                    {card.number}
                  </span>
                  {card.owner && (
                    <span className="text-slate-400">({card.owner})</span>
                  )}
                </div>
                <button
                  type="button"
                  onClick={() => handleRemoveCard(card.id)}
                  className="p-1.5 text-rose-500 hover:bg-rose-50 dark:hover:bg-rose-900/20 rounded-lg shrink-0"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            ))}
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-4 gap-2">
            <input
              type="text"
              placeholder="نام بانک"
              value={newBank}
              onChange={(e) => setNewBank(e.target.value)}
              className="p-2.5 rounded-xl border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-xs outline-none focus:border-[#F97316]"
            />
            <input
              type="text"
              placeholder="شماره کارت ۱۶ رقمی"
              value={newCardNum}
              onChange={(e) => setNewCardNum(e.target.value)}
              className="p-2.5 rounded-xl border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-xs font-mono outline-none focus:border-[#F97316]"
              dir="ltr"
            />
            <input
              type="text"
              placeholder="نام صاحب کارت"
              value={newCardOwner}
              onChange={(e) => setNewCardOwner(e.target.value)}
              className="p-2.5 rounded-xl border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-xs outline-none focus:border-[#F97316]"
            />
            <button
              type="button"
              onClick={handleAddCard}
              className="p-2.5 rounded-xl bg-[#F97316] hover:bg-[#EA580C] text-white font-bold text-xs flex items-center justify-center gap-1"
            >
              <Plus className="w-4 h-4" />
              <span>افزودن کارت</span>
            </button>
          </div>
        </div>
      </section>

      {/* 3. Invoice Settings */}
      <section className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm space-y-4">
        <div className="flex items-center gap-2 pb-2 border-b border-slate-100 dark:border-slate-700">
          <FileText className="w-5 h-5 text-emerald-600" />
          <h3 className="font-bold text-sm text-slate-800 dark:text-white">
            تنظیمات چاپ و ظاهر فاکتور
          </h3>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div>
            <label className={labelClass} htmlFor="start-num">
              شماره شروع فاکتور بعدی
            </label>
            <input
              id="start-num"
              type="number"
              value={startingNum}
              onChange={(e) => {
                setStartingNum(e.target.value);
                markDirty();
              }}
              className={`${fieldClass} text-center`}
            />
          </div>

          <div>
            <label className={labelClass} htmlFor="template">
              قالب فاکتور
            </label>
            <select
              id="template"
              value={templateStyle}
              onChange={(e) => {
                setTemplateStyle(e.target.value);
                markDirty();
              }}
              className={`${fieldClass} font-medium`}
            >
              <option value="modern">مدرن (پیش‌فرض)</option>
              <option value="classic">کلاسیک رسمی</option>
              <option value="simple">ساده و مینیمال</option>
            </select>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-1">
          <label className="flex items-center gap-2 cursor-pointer select-none">
            <input
              type="checkbox"
              checked={showLogo}
              onChange={(e) => {
                setShowLogo(e.target.checked);
                markDirty();
              }}
              className="w-4 h-4 rounded accent-[#F97316]"
            />
            <span className="font-bold text-xs text-slate-700 dark:text-slate-300">
              نمایش لوگوی فروشگاه روی فاکتور
            </span>
          </label>

          <label className="flex items-center gap-2 cursor-pointer select-none">
            <input
              type="checkbox"
              checked={showCardNum}
              onChange={(e) => {
                setShowCardNum(e.target.checked);
                markDirty();
              }}
              className="w-4 h-4 rounded accent-[#F97316]"
            />
            <span className="font-bold text-xs text-slate-700 dark:text-slate-300">
              نمایش کادر شماره کارت بانکی جهت واریز
            </span>
          </label>
        </div>
      </section>

      {/* 4. Appearance */}
      <section className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm space-y-4">
        <div className="flex items-center gap-2 pb-2 border-b border-slate-100 dark:border-slate-700">
          <Palette className="w-5 h-5 text-purple-600" />
          <h3 className="font-bold text-sm text-slate-800 dark:text-white">ظاهر و اطلاعات برنامه</h3>
        </div>

        <div className="flex items-center justify-between gap-3 text-xs">
          <div>
            <div className="font-bold text-slate-800 dark:text-white">حالت تاریک (Dark Mode)</div>
            <div className="text-slate-400">تغییر پوسته برنامه به حالت تاریک یا روشن</div>
          </div>
          <button
            type="button"
            onClick={onToggleDarkMode}
            className={`px-4 py-2 rounded-2xl font-bold transition shrink-0 ${
              isDarkMode ? 'bg-amber-500 text-slate-900' : 'bg-slate-200 text-slate-800'
            }`}
          >
            {isDarkMode ? 'روشن کن' : 'تاریک کن'}
          </button>
        </div>

        <div className="pt-3 border-t border-slate-100 dark:border-slate-700 text-xs text-slate-500 space-y-1">
          <div className="flex justify-between">
            <span>نسخه اپلیکیشن:</span>
            <span className="font-bold text-slate-800 dark:text-white">۵.۸.۰ release</span>
          </div>
          <div className="flex justify-between">
            <span>ذخیره‌سازی:</span>
            <span className="font-bold text-emerald-600">localStorage / Offline</span>
          </div>
        </div>
      </section>

      {/* Sticky save bar */}
      <div className="fixed bottom-0 left-0 right-0 z-40 bg-white/95 dark:bg-slate-900/95 backdrop-blur border-t border-slate-200 dark:border-slate-700 p-3">
        <div className="max-w-4xl mx-auto flex items-center justify-between gap-3">
          <span className="text-[11px] text-slate-500 dark:text-slate-400">
            {savedSuccess
              ? '✓ مشخصات با موفقیت ذخیره شد'
              : dirty
                ? 'تغییرات ذخیره نشده'
                : 'پس از ویرایش، ذخیره را بزنید'}
          </span>
          <button
            type="submit"
            className="px-6 py-3 rounded-2xl bg-[#F97316] hover:bg-[#EA580C] text-white font-extrabold text-sm shadow-lg shadow-orange-500/25 flex items-center gap-2 active:scale-95 transition"
          >
            {savedSuccess ? <Check className="w-5 h-5" /> : <Save className="w-5 h-5" />}
            <span>{savedSuccess ? 'ذخیره شد!' : 'ذخیره تغییرات'}</span>
          </button>
        </div>
      </div>
    </form>
  );
}
