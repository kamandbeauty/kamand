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
  const [userPhone, setUserPhone] = useState(user?.phone || '');
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
  const [showStamp, setShowStamp] = useState(settings?.showStamp !== false);
  const [showSignature, setShowSignature] = useState(settings?.showSignature !== false);
  const [stampDataUrl, setStampDataUrl] = useState(business?.stampDataUrl || '');
  const [signatureDataUrl, setSignatureDataUrl] = useState(business?.signatureDataUrl || '');
  const [cropModal, setCropModal] = useState(null); // { kind, src }

  const [savedSuccess, setSavedSuccess] = useState(false);
  const [dirty, setDirty] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');

  // Sync local form when parent props change (e.g. after restore / reset)
  useEffect(() => {
    setUserName(user?.name || '');
    setUserPhone(user?.phone || '');
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
    setStampDataUrl(business?.stampDataUrl || '');
    setSignatureDataUrl(business?.signatureDataUrl || '');
  }, [business]);

  useEffect(() => {
    setStartingNum(settings?.startingInvoiceNum ?? 1004);
    setTemplateStyle(settings?.templateStyle || 'modern');
    setShowLogo(settings?.showLogo !== false);
    setShowCardNum(settings?.showCardNum !== false);
    setShowStamp(settings?.showStamp !== false);
    setShowSignature(settings?.showSignature !== false);
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
      phone: String(userPhone || '').trim(),
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
      bankCards: bankCards || [],
      stampDataUrl: stampDataUrl || '',
      signatureDataUrl: signatureDataUrl || ''
    };

    const nextSettings = {
      ...(settings || {}),
      startingInvoiceNum: parseInt(startingNum, 10) || 1004,
      templateStyle,
      showLogo: Boolean(showLogo),
      showCardNum: Boolean(showCardNum),
      showStamp: Boolean(showStamp),
      showSignature: Boolean(showSignature)
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
            <label className={labelClass} htmlFor="user-phone">
              شماره تلفن / همراه
            </label>
            <input
              id="user-phone"
              name="userPhone"
              type="tel"
              autoComplete="tel"
              value={userPhone}
              onChange={(e) => {
                setUserPhone(e.target.value);
                markDirty();
              }}
              placeholder="۰۹۱۲…"
              className={fieldClass}
              dir="ltr"
              style={{ textAlign: 'right' }}
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


      {/* 3b. مهر و امضا */}
      <section className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm space-y-4">
        <div className="flex items-center gap-2 pb-2 border-b border-slate-100 dark:border-slate-700">
          <FileText className="w-5 h-5 text-rose-500" />
          <h3 className="font-bold text-sm text-slate-800 dark:text-white">مهر و امضای فروشنده</h3>
        </div>
        <p className="text-[11px] text-slate-500">
          عکس را انتخاب کنید، کراپ کنید؛ پس‌زمینه سفید خودکار حذف می‌شود و روی فاکتور نمایش داده می‌شود.
        </p>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          {[
            { key: 'stamp', label: 'مهر', value: stampDataUrl, set: setStampDataUrl },
            { key: 'signature', label: 'امضا', value: signatureDataUrl, set: setSignatureDataUrl }
          ].map((item) => (
            <div key={item.key} className="rounded-2xl border border-slate-200 dark:border-slate-600 p-3 space-y-2 bg-slate-50 dark:bg-slate-900">
              <div className="font-bold text-xs text-slate-700 dark:text-slate-200">{item.label}</div>
              <div className="h-28 rounded-xl border border-dashed border-slate-300 dark:border-slate-600 flex items-center justify-center overflow-hidden relative" style={{ backgroundImage: "linear-gradient(45deg,#e2e8f0 25%,transparent 25%),linear-gradient(-45deg,#e2e8f0 25%,transparent 25%),linear-gradient(45deg,transparent 75%,#e2e8f0 75%),linear-gradient(-45deg,transparent 75%,#e2e8f0 75%)", backgroundSize: "16px 16px", backgroundPosition: "0 0,0 8px,8px -8px,-8px 0", backgroundColor: "#f8fafc" }}>
                {item.value ? (
                  <>
                    <img src={item.value} alt={item.label} className="max-h-full max-w-full object-contain p-2" />
                    <button
                      type="button"
                      onClick={() => { item.set(''); markDirty(); }}
                      className="absolute top-1 left-1 text-[10px] bg-rose-500 text-white px-2 py-0.5 rounded-lg"
                    >
                      حذف
                    </button>
                  </>
                ) : (
                  <span className="text-[11px] text-slate-400">هنوز انتخاب نشده</span>
                )}
              </div>
              <label className="block w-full text-center py-2 rounded-xl bg-[#F97316] text-white text-xs font-bold cursor-pointer">
                انتخاب / کراپ {item.label}
                <input
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={(e) => {
                    const f = e.target.files?.[0];
                    if (!f) return;
                    const reader = new FileReader();
                    reader.onload = () => {
                      setCropModal({ kind: item.key, src: reader.result, set: item.set });
                    };
                    reader.readAsDataURL(f);
                    e.target.value = '';
                  }}
                />
              </label>
            </div>
          ))}
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1">
          <label className="flex items-center gap-2 cursor-pointer select-none">
            <input type="checkbox" checked={showStamp} onChange={(e) => { setShowStamp(e.target.checked); markDirty(); }} className="w-4 h-4 rounded accent-[#F97316]" />
            <span className="font-bold text-xs text-slate-700 dark:text-slate-300">نمایش مهر روی فاکتور</span>
          </label>
          <label className="flex items-center gap-2 cursor-pointer select-none">
            <input type="checkbox" checked={showSignature} onChange={(e) => { setShowSignature(e.target.checked); markDirty(); }} className="w-4 h-4 rounded accent-[#F97316]" />
            <span className="font-bold text-xs text-slate-700 dark:text-slate-300">نمایش امضا روی فاکتور</span>
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

      {cropModal && (
        <StampCropModal
          src={cropModal.src}
          title={cropModal.kind === 'stamp' ? 'کراپ مهر' : 'کراپ امضا'}
          onCancel={() => setCropModal(null)}
          onDone={(dataUrl) => {
            cropModal.set(dataUrl);
            setCropModal(null);
            markDirty();
          }}
        />
      )}
    </form>
  );
}

function StampCropModal({ src, title, onCancel, onDone }) {
  const imgRef = React.useRef(null);
  const [box, setBox] = React.useState({ l: 0.08, t: 0.08, r: 0.92, b: 0.92 });
  const [dragging, setDragging] = React.useState(null);
  const [removeWhite, setRemoveWhite] = React.useState(true);
  const [busy, setBusy] = React.useState(false);

  const onPointer = (e, corner) => {
    e.preventDefault();
    e.stopPropagation();
    setDragging(corner);
  };

  React.useEffect(() => {
    if (!dragging) return;
    const move = (ev) => {
      const el = imgRef.current;
      if (!el) return;
      const rect = el.getBoundingClientRect();
      const clientX = ev.touches ? ev.touches[0].clientX : ev.clientX;
      const clientY = ev.touches ? ev.touches[0].clientY : ev.clientY;
      let x = (clientX - rect.left) / rect.width;
      let y = (clientY - rect.top) / rect.height;
      x = Math.min(1, Math.max(0, x));
      y = Math.min(1, Math.max(0, y));
      setBox((prev) => {
        const n = { ...prev };
        const min = 0.12;
        if (dragging === 'tl') { n.l = Math.min(x, n.r - min); n.t = Math.min(y, n.b - min); }
        if (dragging === 'tr') { n.r = Math.max(x, n.l + min); n.t = Math.min(y, n.b - min); }
        if (dragging === 'bl') { n.l = Math.min(x, n.r - min); n.b = Math.max(y, n.t + min); }
        if (dragging === 'br') { n.r = Math.max(x, n.l + min); n.b = Math.max(y, n.t + min); }
        return n;
      });
    };
    const up = () => setDragging(null);
    window.addEventListener('mousemove', move);
    window.addEventListener('mouseup', up);
    window.addEventListener('touchmove', move, { passive: false });
    window.addEventListener('touchend', up);
    return () => {
      window.removeEventListener('mousemove', move);
      window.removeEventListener('mouseup', up);
      window.removeEventListener('touchmove', move);
      window.removeEventListener('touchend', up);
    };
  }, [dragging]);

  const apply = async () => {
    setBusy(true);
    try {
      const image = new Image();
      image.src = src;
      await new Promise((res, rej) => { image.onload = res; image.onerror = rej; });
      const sx = Math.round(box.l * image.naturalWidth);
      const sy = Math.round(box.t * image.naturalHeight);
      const sw = Math.max(1, Math.round((box.r - box.l) * image.naturalWidth));
      const sh = Math.max(1, Math.round((box.b - box.t) * image.naturalHeight));
      const canvas = document.createElement('canvas');
      canvas.width = sw;
      canvas.height = sh;
      const ctx = canvas.getContext('2d');
      ctx.drawImage(image, sx, sy, sw, sh, 0, 0, sw, sh);
      if (removeWhite) {
        const id = ctx.getImageData(0, 0, sw, sh);
        const d = id.data;
        for (let i = 0; i < d.length; i += 4) {
          const r = d[i], g = d[i + 1], b = d[i + 2];
          const luma = 0.299 * r + 0.587 * g + 0.114 * b;
          const maxC = Math.max(r, g, b);
          const minC = Math.min(r, g, b);
          const sat = maxC - minC;
          // سفید / خاکستری خیلی روشن با اشباع کم → شفاف
          if ((luma >= 220 || minC >= 210) && sat < 40) {
            d[i + 3] = 0;
          } else if (luma >= 185 && sat < 28) {
            const t = Math.max(0, Math.min(1, (220 - luma) / 35));
            d[i + 3] = Math.round(t * d[i + 3]);
          }
        }
        ctx.putImageData(id, 0, 0);
      }
      // limit size
      let out = canvas;
      const maxSide = 800;
      if (sw > maxSide || sh > maxSide) {
        const scale = maxSide / Math.max(sw, sh);
        out = document.createElement('canvas');
        out.width = Math.round(sw * scale);
        out.height = Math.round(sh * scale);
        out.getContext('2d').drawImage(canvas, 0, 0, out.width, out.height);
      }
      onDone(out.toDataURL('image/png'));
    } catch (err) {
      console.error(err);
      alert('پردازش تصویر ناموفق بود');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="fixed inset-0 z-[80] bg-slate-900/80 backdrop-blur-sm flex items-end sm:items-center justify-center p-0 sm:p-4">
      <div className="w-full max-w-lg bg-slate-900 text-white rounded-t-3xl sm:rounded-3xl overflow-hidden shadow-2xl">
        <div className="p-4 border-b border-slate-700 flex items-center justify-between">
          <h3 className="font-black text-sm">{title}</h3>
          <button type="button" onClick={onCancel} className="text-slate-400 text-xs">انصراف</button>
        </div>
        <div className="p-4">
          <div className="relative w-full bg-slate-800 rounded-2xl overflow-hidden select-none" style={{ touchAction: 'none' }}>
            <img ref={imgRef} src={src} alt="crop" className="w-full h-auto block max-h-[50vh] object-contain mx-auto" draggable={false} />
            {/* overlay */}
            <div className="absolute inset-0 pointer-events-none">
              <div
                className="absolute border-2 border-orange-500 bg-orange-500/10"
                style={{
                  left: `${box.l * 100}%`,
                  top: `${box.t * 100}%`,
                  width: `${(box.r - box.l) * 100}%`,
                  height: `${(box.b - box.t) * 100}%`
                }}
              />
            </div>
            {['tl','tr','bl','br'].map((c) => {
              const style = {
                tl: { left: `calc(${box.l * 100}% - 10px)`, top: `calc(${box.t * 100}% - 10px)` },
                tr: { left: `calc(${box.r * 100}% - 10px)`, top: `calc(${box.t * 100}% - 10px)` },
                bl: { left: `calc(${box.l * 100}% - 10px)`, top: `calc(${box.b * 100}% - 10px)` },
                br: { left: `calc(${box.r * 100}% - 10px)`, top: `calc(${box.b * 100}% - 10px)` }
              }[c];
              return (
                <div
                  key={c}
                  onMouseDown={(e) => onPointer(e, c)}
                  onTouchStart={(e) => onPointer(e, c)}
                  className="absolute w-5 h-5 rounded-full bg-orange-500 border-2 border-white z-10"
                  style={style}
                />
              );
            })}
          </div>
          <label className="flex items-center gap-2 mt-3 text-xs">
            <input type="checkbox" checked={removeWhite} onChange={(e) => setRemoveWhite(e.target.checked)} className="accent-orange-500" />
            حذف پس‌زمینه سفید
          </label>
          <button
            type="button"
            disabled={busy}
            onClick={apply}
            className="w-full mt-3 h-12 rounded-2xl bg-[#F97316] font-black text-sm disabled:opacity-60"
          >
            {busy ? 'در حال پردازش…' : 'اعمال کراپ و ذخیره'}
          </button>
        </div>
      </div>
    </div>
  );
}

