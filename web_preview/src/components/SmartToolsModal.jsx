import React, { useState } from 'react';
import {
  Sparkles,
  Search,
  Lock,
  QrCode,
  Database,
  Smartphone,
  Copy,
  ArrowRightLeft,
  CreditCard,
  Bell,
  Palette,
  Image,
  RotateCcw,
  Download,
  Upload,
  CheckCircle,
  X
} from 'lucide-react';
import { formatCurrency, toPersianDigits } from '../utils/helpers';

export default function SmartToolsModal({
  isOpen,
  onClose,
  invoices,
  customers,
  products,
  business,
  settings,
  onUpdateSettings,
  onOpenGlobalSearch,
  onRestoreData,
  onLockApp
}) {
  if (!isOpen) return null;

  const [activeTab, setActiveTab] = useState('features'); // features, backup, migration, pin
  const [pinInput, setPinInput] = useState('');
  const [pinConfirm, setPinInputConfirm] = useState('');

  // Backup JSON download
  const handleExportJSON = () => {
    const data = {
      version: '5.8.0',
      exportedAt: new Date().toISOString(),
      invoices,
      customers,
      products,
      business,
      settings
    };
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `FactorRuby_Backup_${new Date().toISOString().slice(0, 10)}.json`;
    a.click();
  };

  // Restore JSON upload
  const handleImportJSON = (e) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (event) => {
      try {
        const parsed = JSON.parse(event.target.result);
        if (parsed.invoices && parsed.customers && parsed.products) {
          onRestoreData(parsed);
          alert('اطلاعات پشتیبان با موفقیت بازیابی شد!');
          onClose();
        } else {
          alert('فایل فایل پشتیبان معتبری نیست.');
        }
      } catch (err) {
        alert('خطا در خواندن فایل پشتیبان.');
      }
    };
    reader.readAsText(file);
  };

  const handleSavePin = () => {
    if (pinInput.length !== 4) {
      alert('رمز عبور باید ۴ رقم باشد.');
      return;
    }
    if (pinInput !== pinConfirm) {
      alert('تکرار رمز عبور مطابقت ندارد.');
      return;
    }
    onUpdateSettings({ ...settings, pinCode: pinInput, pinEnabled: true });
    alert('قفل رمز عبور با موفقیت فعال شد.');
  };

  const smartFeaturesList = [
    { title: 'کپی سریع فاکتور', desc: 'تکثیر دقیق فاکتورهای قبلی با یک کلیک', icon: Copy },
    { title: 'تبدیل پیش‌فاکتور به فاکتور', desc: 'تغییر فوری وضعیت پیش‌فاکتور به فاکتور فروش نهایی', icon: ArrowRightLeft },
    { title: 'ثبت دریافت اقساطی', desc: 'کسر اتوماتیک و مدیریت مانده فاکتورهای بدهکار', icon: CreditCard },
    { title: 'ارسال یادآوری بدهی', desc: 'تولید متن آماده پیامک و ارسال هوشمند به مشتریان بدهکار', icon: Bell },
    { title: 'جستجوی سراسری پیشرفته', desc: 'میانبر Ctrl+K برای جستجوی لحظه‌ای کل داده‌ها', icon: Search },
    { title: 'QR Code روی فاکتور', desc: 'تولید کیوآرکد اختصاصی جهت استعلام صحت فاکتور', icon: QrCode },
    { title: 'مدیریت چند شماره کارت', desc: 'پشتیبانی از چندین حساب بانکی و انتخاب بر روی فاکتور', icon: CreditCard },
    { title: 'قالب‌های متنوع فاکتور', desc: 'انتخاب سبک‌های کلاسیک، مدرن و ساده', icon: Palette },
    { title: 'لوگوی اختصاصی فروشگاه', desc: 'نمایش لوگو در بالاسر فاکتور و خروجی PDF', icon: Image },
    { title: 'قفل امنیتی PIN', desc: 'حفاظت از اطلاعات مالی با رمز عبور و بیومتریک', icon: Lock },
    { title: 'بکاپ و بازیابی محلی', desc: 'پشتیبان‌گیری کاملاً آفلاین و ایمن بدون نیاز به اینترنت', icon: Database },
    { title: 'Export/Import کامل', desc: 'استخراج داده‌ها به فرمت استاندارد JSON', icon: Download },
    { title: 'انتقال به گوشی جدید', desc: 'انتقال ۱۰۰٪ اطلاعات به تلفن همراه جدید با یک فایل', icon: Smartphone },
    { title: 'پشتیبان‌گیری خودکار', desc: 'تنظیم زمان‌بندی روزانه جهت ذخیره بکاپ', icon: RotateCcw },
    { title: 'بازگردانی حذف اشتباهی (Undo)', desc: 'فرصت بازگرداندن داده‌های حذف شده با بازخورد سریع', icon: Sparkles },
  ];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-md">
      <div className="w-full max-w-2xl bg-white dark:bg-slate-800 rounded-3xl shadow-2xl overflow-hidden flex flex-col max-h-[85vh] border border-slate-200 dark:border-slate-700">
        
        {/* Header */}
        <div className="p-5 bg-gradient-to-r from-blue-600 to-indigo-600 text-white flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-white/20 flex items-center justify-center">
              <Sparkles className="w-5 h-5 text-amber-300" />
            </div>
            <div>
              <h2 className="font-extrabold text-base">قابلیت‌های هوشمند فاکتور روبی</h2>
              <p className="text-xs text-blue-100 opacity-90">۱۵ قابلیت پیشرفته برای سرعت و سهولت کاری شما</p>
            </div>
          </div>
          <button onClick={onClose} className="p-1.5 rounded-xl bg-white/10 hover:bg-white/20 transition">
            <X className="w-5 h-5 text-white" />
          </button>
        </div>

        {/* Tab Navigation */}
        <div className="flex border-b border-slate-100 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-xs font-bold">
          <button
            onClick={() => setActiveTab('features')}
            className={`flex-1 py-3 text-center transition border-b-2 ${
              activeTab === 'features'
                ? 'border-blue-600 text-blue-600 dark:text-blue-400 bg-white dark:bg-slate-800'
                : 'border-transparent text-slate-500'
            }`}
          >
            لیست قابلیت‌ها (۱۵)
          </button>
          <button
            onClick={() => setActiveTab('backup')}
            className={`flex-1 py-3 text-center transition border-b-2 ${
              activeTab === 'backup'
                ? 'border-blue-600 text-blue-600 dark:text-blue-400 bg-white dark:bg-slate-800'
                : 'border-transparent text-slate-500'
            }`}
          >
            بکاپ و بازیابی
          </button>
          <button
            onClick={() => setActiveTab('migration')}
            className={`flex-1 py-3 text-center transition border-b-2 ${
              activeTab === 'migration'
                ? 'border-blue-600 text-blue-600 dark:text-blue-400 bg-white dark:bg-slate-800'
                : 'border-transparent text-slate-500'
            }`}
          >
            انتقال به گوشی جدید
          </button>
          <button
            onClick={() => setActiveTab('pin')}
            className={`flex-1 py-3 text-center transition border-b-2 ${
              activeTab === 'pin'
                ? 'border-blue-600 text-blue-600 dark:text-blue-400 bg-white dark:bg-slate-800'
                : 'border-transparent text-slate-500'
            }`}
          >
            قفل برنامه
          </button>
        </div>

        {/* Body Content */}
        <div className="p-6 flex-1 overflow-y-auto">
          
          {/* TAB 1: Smart Features List */}
          {activeTab === 'features' && (
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
              {smartFeaturesList.map((item, idx) => {
                const Icon = item.icon;
                return (
                  <div
                    key={idx}
                    className="p-3.5 rounded-2xl bg-slate-50 dark:bg-slate-900/50 border border-slate-100 dark:border-slate-700/60 flex items-start gap-3"
                  >
                    <div className="p-2 rounded-xl bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 shrink-0">
                      <Icon className="w-4 h-4" />
                    </div>
                    <div>
                      <div className="font-bold text-xs text-slate-800 dark:text-white mb-0.5">
                        {toPersianDigits(idx + 1)}. {item.title}
                      </div>
                      <div className="text-[11px] text-slate-400 leading-snug">
                        {item.desc}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          {/* TAB 2: Backup & Restore */}
          {activeTab === 'backup' && (
            <div className="space-y-6">
              <div className="p-4 bg-blue-50 dark:bg-blue-900/30 rounded-2xl border border-blue-200 dark:border-blue-800 text-xs text-slate-700 dark:text-slate-200 leading-relaxed">
                تمام داده‌های شما به صورت آفلاین روی دستگاه ذخیره می‌شود. می‌توانید در هر زمان از کلیه اطلاعات (فاکتورها، مشتریان، کالاها، تنظیمات) خروجی نسخه پشتیبان تهیه کنید.
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <button
                  onClick={handleExportJSON}
                  className="p-5 rounded-3xl bg-blue-600 hover:bg-blue-700 text-white font-bold text-xs shadow-lg shadow-blue-500/20 flex flex-col items-center justify-center gap-2 transition"
                >
                  <Download className="w-8 h-8 text-blue-200" />
                  <span>دانلود فایل پشتیبان (Export JSON)</span>
                </button>

                <label className="p-5 rounded-3xl bg-slate-100 dark:bg-slate-700 hover:bg-slate-200 text-slate-800 dark:text-white font-bold text-xs border border-dashed border-slate-300 dark:border-slate-600 flex flex-col items-center justify-center gap-2 cursor-pointer transition">
                  <Upload className="w-8 h-8 text-slate-400" />
                  <span>بازیابی از فایل پشتیبان (Restore JSON)</span>
                  <input
                    type="file"
                    accept=".json"
                    onChange={handleImportJSON}
                    className="hidden"
                  />
                </label>
              </div>
            </div>
          )}

          {/* TAB 3: Phone Migration */}
          {activeTab === 'migration' && (
            <div className="space-y-4 text-xs text-slate-700 dark:text-slate-300 leading-relaxed">
              <div className="p-4 bg-emerald-50 dark:bg-emerald-900/30 rounded-2xl border border-emerald-200 dark:border-emerald-800">
                <h4 className="font-bold text-sm text-emerald-800 dark:text-emerald-300 mb-1">
                  راهنمای انتقال به گوشی جدید:
                </h4>
                <ol className="list-decimal list-inside space-y-1 text-slate-600 dark:text-slate-300">
                  <li>روی گوشی فعلی، دکمه «دانلود فایل پشتیبان» را بزنید.</li>
                  <li>فایل JSON ایجاد شده را از طریق ایتا، روبیکا یا تلگرام به گوشی جدید بفرستید.</li>
                  <li>در گوشی جدید، اپلیکیشن «فاکتور روبی» را نصب کرده و گزینه «بازیابی از فایل پشتیبان» را انتخاب کنید.</li>
                </ol>
              </div>

              <button
                onClick={handleExportJSON}
                className="w-full py-3.5 rounded-2xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs shadow transition flex items-center justify-center gap-2"
              >
                <Smartphone className="w-4 h-4" />
                <span>شروع ایجاد فایل انتقال داده</span>
              </button>
            </div>
          )}

          {/* TAB 4: PIN Lock */}
          {activeTab === 'pin' && (
            <div className="space-y-4 max-w-sm mx-auto text-xs">
              <div className="text-center">
                <Lock className="w-10 h-10 mx-auto text-blue-600 mb-2" />
                <h4 className="font-bold text-sm text-slate-800 dark:text-white">
                  تنظیم قفل رمز عبور (PIN)
                </h4>
                <p className="text-slate-400">ورود به برنامه را مشروط به رمز ۴ رقمی کنید</p>
              </div>

              <div className="space-y-3">
                <input
                  type="password"
                  maxLength={4}
                  placeholder="رمز ۴ رقمی جدید"
                  value={pinInput}
                  onChange={(e) => setPinInput(e.target.value)}
                  className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 text-center font-mono text-lg font-bold"
                />

                <input
                  type="password"
                  maxLength={4}
                  placeholder="تکرار رمز ۴ رقمی"
                  value={pinConfirm}
                  onChange={(e) => setPinInputConfirm(e.target.value)}
                  className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 text-center font-mono text-lg font-bold"
                />

                <button
                  onClick={handleSavePin}
                  className="w-full py-3 rounded-2xl bg-blue-600 hover:bg-blue-700 text-white font-bold shadow"
                >
                  فعال‌سازی قفل برنامه
                </button>
              </div>
            </div>
          )}

        </div>

      </div>
    </div>
  );
}
