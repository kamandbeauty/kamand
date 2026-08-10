import React, { useState } from 'react';
import {
  Settings,
  User,
  Building2,
  FileText,
  Palette,
  Info,
  Database,
  Save,
  Check,
  CreditCard,
  Plus,
  Trash2
} from 'lucide-react';
import { USAGE_TYPES, COUNTRIES } from '../utils/helpers';

export default function SettingsView({
  user,
  business,
  settings,
  onSaveUser,
  onSaveBusiness,
  onSaveSettings,
  isDarkMode,
  onToggleDarkMode
}) {
  // User Profile State
  const [userName, setUserName] = useState(user?.name || '');
  const [userCountry, setUserCountry] = useState(user?.country || 'ایران');
  const [userCity, setUserCity] = useState(user?.city || 'تهران');
  const [userUsage, setUserUsage] = useState(user?.usageType || 'store');

  // Business State
  const [shopName, setShopName] = useState(business?.shopName || '');
  const [phone, setPhone] = useState(business?.phone || '');
  const [address, setAddress] = useState(business?.address || '');
  const [taxId, setTaxId] = useState(business?.taxId || '');
  const [bankCards, setBankCards] = useState(business?.bankCards || []);

  // Card Inputs
  const [newBank, setNewBank] = useState('');
  const [newCardNum, setNewCardNum] = useState('');

  // Invoice Settings State
  const [startingNum, setStartingNum] = useState(settings?.startingInvoiceNum || 1004);
  const [templateStyle, setTemplateStyle] = useState(settings?.templateStyle || 'modern');
  const [showLogo, setShowLogo] = useState(settings?.showLogo !== false);
  const [showCardNum, setShowCardNum] = useState(settings?.showCardNum !== false);

  const [savedSuccess, setSavedSuccess] = useState(false);

  const handleSaveAll = () => {
    onSaveUser({
      ...user,
      name: userName,
      country: userCountry,
      city: userCity,
      usageType: userUsage
    });

    onSaveBusiness({
      ...business,
      shopName,
      phone,
      address,
      taxId,
      bankCards
    });

    onSaveSettings({
      ...settings,
      startingInvoiceNum: parseInt(startingNum) || 1004,
      templateStyle,
      showLogo,
      showCardNum
    });

    setSavedSuccess(true);
    setTimeout(() => setSavedSuccess(false), 3000);
  };

  const handleAddCard = () => {
    if (!newCardNum.trim()) return;
    setBankCards([
      ...bankCards,
      { id: Date.now().toString(), bank: newBank || 'بانک', number: newCardNum.trim(), owner: userName }
    ]);
    setNewBank('');
    setNewCardNum('');
  };

  const handleRemoveCard = (id) => {
    setBankCards(bankCards.filter(c => c.id !== id));
  };

  return (
    <div className="space-y-6 max-w-4xl mx-auto animate-fade-in pb-16">
      
      {/* Top Banner */}
      <div className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm flex items-center justify-between">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-2xl bg-blue-600 text-white flex items-center justify-center font-bold">
            <Settings className="w-5 h-5" />
          </div>
          <div>
            <h2 className="font-bold text-lg text-slate-800 dark:text-white">
              تنظیمات کامل برنامه
            </h2>
            <p className="text-xs text-slate-400">مدیریت پروفایل، مشخصات کسب و کار و قالب فاکتورها</p>
          </div>
        </div>

        <button
          onClick={handleSaveAll}
          className="px-5 py-2.5 rounded-2xl bg-blue-600 hover:bg-blue-700 text-white font-bold text-xs shadow-md shadow-blue-500/20 flex items-center gap-1.5 transition active:scale-95"
        >
          {savedSuccess ? <Check className="w-4 h-4 text-emerald-300" /> : <Save className="w-4 h-4" />}
          <span>{savedSuccess ? 'ذخیره شد!' : 'ذخیره تغییرات'}</span>
        </button>
      </div>

      {/* 1. User Profile Section */}
      <div className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm space-y-4">
        <div className="flex items-center gap-2 pb-2 border-b border-slate-100 dark:border-slate-700">
          <User className="w-5 h-5 text-blue-600" />
          <h3 className="font-bold text-sm text-slate-800 dark:text-white">
            پروفایل کاربر
          </h3>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
          <div>
            <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
              نام شما
            </label>
            <input
              type="text"
              value={userName}
              onChange={(e) => setUserName(e.target.value)}
              className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-bold"
            />
          </div>

          <div>
            <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
              کشور
            </label>
            <select
              value={userCountry}
              onChange={(e) => setUserCountry(e.target.value)}
              className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-medium"
            >
              {COUNTRIES.map(c => (
                <option key={c.id} value={c.name}>{c.name}</option>
              ))}
            </select>
          </div>

          <div>
            <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
              شهر
            </label>
            <input
              type="text"
              value={userCity}
              onChange={(e) => setUserCity(e.target.value)}
              className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-medium"
            />
          </div>

          <div>
            <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
              نوع فعالیت
            </label>
            <select
              value={userUsage}
              onChange={(e) => setUserUsage(e.target.value)}
              className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-medium"
            >
              {USAGE_TYPES.map(u => (
                <option key={u.id} value={u.id}>{u.title}</option>
              ))}
            </select>
          </div>
        </div>
      </div>

      {/* 2. Business Profile Section */}
      <div className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm space-y-4">
        <div className="flex items-center gap-2 pb-2 border-b border-slate-100 dark:border-slate-700">
          <Building2 className="w-5 h-5 text-indigo-600" />
          <h3 className="font-bold text-sm text-slate-800 dark:text-white">
            اطلاعات کسب و کار و سربرگ فاکتور
          </h3>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
          <div>
            <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
              نام فروشگاه / کسب و کار
            </label>
            <input
              type="text"
              value={shopName}
              onChange={(e) => setShopName(e.target.value)}
              className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-bold"
            />
          </div>

          <div>
            <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
              شماره تماس پشتیبانی
            </label>
            <input
              type="text"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-medium"
            />
          </div>

          <div className="sm:col-span-2">
            <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
              آدرس کامل کسب و کار
            </label>
            <input
              type="text"
              value={address}
              onChange={(e) => setAddress(e.target.value)}
              className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-medium"
            />
          </div>

          <div>
            <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
              شناسه ملی / کد اقتصادی
            </label>
            <input
              type="text"
              value={taxId}
              onChange={(e) => setTaxId(e.target.value)}
              className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-medium"
            />
          </div>
        </div>

        {/* Bank Cards Section */}
        <div className="pt-3 border-t border-slate-100 dark:border-slate-700 space-y-3">
          <label className="block font-bold text-xs text-slate-700 dark:text-slate-300">
            شماره کارت‌های بانکی ثبت‌شده
          </label>

          <div className="space-y-2">
            {bankCards.map((card) => (
              <div
                key={card.id}
                className="p-3 bg-slate-50 dark:bg-slate-900 rounded-2xl border border-slate-200 dark:border-slate-700 flex items-center justify-between text-xs"
              >
                <div className="flex items-center gap-2">
                  <CreditCard className="w-4 h-4 text-blue-600" />
                  <span className="font-bold text-slate-800 dark:text-white">{card.bank}:</span>
                  <span className="font-mono text-slate-700 dark:text-slate-300 dir-ltr">{card.number}</span>
                </div>
                <button
                  onClick={() => handleRemoveCard(card.id)}
                  className="p-1 text-rose-500 hover:bg-rose-50 dark:hover:bg-rose-900/20 rounded-lg"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            ))}
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-2">
            <input
              type="text"
              placeholder="نام بانک (مثلا ملی)"
              value={newBank}
              onChange={(e) => setNewBank(e.target.value)}
              className="p-2.5 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-xs"
            />
            <input
              type="text"
              placeholder="شماره کارت ۱۶ رقمی"
              value={newCardNum}
              onChange={(e) => setNewCardNum(e.target.value)}
              className="p-2.5 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-xs font-mono"
            />
            <button
              onClick={handleAddCard}
              className="p-2.5 rounded-xl bg-blue-600 hover:bg-blue-700 text-white font-bold text-xs flex items-center justify-center gap-1"
            >
              <Plus className="w-4 h-4" />
              <span>افزودن کارت</span>
            </button>
          </div>
        </div>

      </div>

      {/* 3. Invoice Settings Section */}
      <div className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm space-y-4">
        <div className="flex items-center gap-2 pb-2 border-b border-slate-100 dark:border-slate-700">
          <FileText className="w-5 h-5 text-emerald-600" />
          <h3 className="font-bold text-sm text-slate-800 dark:text-white">
            تنظیمات چاپ و ظاهر فاکتور
          </h3>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-xs">
          <div>
            <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
              شماره شروع فاکتور بعدی
            </label>
            <input
              type="number"
              value={startingNum}
              onChange={(e) => setStartingNum(e.target.value)}
              className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-bold text-center"
            />
          </div>

          <div>
            <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
              قالب فاکتور
            </label>
            <select
              value={templateStyle}
              onChange={(e) => setTemplateStyle(e.target.value)}
              className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-medium"
            >
              <option value="modern">مدرن آبی (پیش‌فرض)</option>
              <option value="classic">کلاسیک رسمی</option>
              <option value="simple">ساده و مینیمال</option>
            </select>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-2 text-xs">
          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={showLogo}
              onChange={(e) => setShowLogo(e.target.checked)}
              className="w-4 h-4 rounded text-blue-600"
            />
            <span className="font-bold text-slate-700 dark:text-slate-300">نمایش لوگوی فروشگاه روی فاکتور</span>
          </label>

          <label className="flex items-center gap-2 cursor-pointer">
            <input
              type="checkbox"
              checked={showCardNum}
              onChange={(e) => setShowCardNum(e.target.checked)}
              className="w-4 h-4 rounded text-blue-600"
            />
            <span className="font-bold text-slate-700 dark:text-slate-300">نمایش کادر شماره کارت بانکی جهت واریز</span>
          </label>
        </div>
      </div>

      {/* 4. Appearance & App Info */}
      <div className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm space-y-4">
        <div className="flex items-center gap-2 pb-2 border-b border-slate-100 dark:border-slate-700">
          <Palette className="w-5 h-5 text-purple-600" />
          <h3 className="font-bold text-sm text-slate-800 dark:text-white">
            ظاهر و اطلاعات برنامه
          </h3>
        </div>

        <div className="flex items-center justify-between text-xs">
          <div>
            <div className="font-bold text-slate-800 dark:text-white">حالت تاریک (Dark Mode)</div>
            <div className="text-slate-400">تغییر پوسته برنامه به حالت تاریک یا روشن</div>
          </div>

          <button
            onClick={onToggleDarkMode}
            className={`px-4 py-2 rounded-2xl font-bold transition ${isDarkMode ? 'bg-amber-500 text-slate-900' : 'bg-slate-200 text-slate-800'}`}
          >
            {isDarkMode ? 'روشن کن' : 'تاریک کن'}
          </button>
        </div>

        <div className="pt-3 border-t border-slate-100 dark:border-slate-700 text-xs text-slate-500 space-y-1">
          <div className="flex justify-between">
            <span>نسخه اپلیکیشن:</span>
            <span className="font-bold text-slate-800 dark:text-white">۱.۰.۰ release</span>
          </div>
          <div className="flex justify-between">
            <span>دیتابیس محلی:</span>
            <span className="font-bold text-emerald-600">SQLite / Offline-First</span>
          </div>
          <div className="flex justify-between">
            <span>سازنده:</span>
            <span className="font-bold text-blue-600">فاکتور فیدا (Fida Factor)</span>
          </div>
        </div>
      </div>

    </div>
  );
}
