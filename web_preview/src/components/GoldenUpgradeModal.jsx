import React from 'react';
import {
  X,
  Send,
  Palette,
  Layers,
  FileCheck,
  Award,
  FileDown,
  ChevronLeft,
  Check
} from 'lucide-react';

export default function GoldenUpgradeModal({ isOpen, onClose }) {
  if (!isOpen) return null;

  const goldenFeatures = [
    {
      title: 'شخصی سازی فاکتور ها',
      desc: 'امکان تغییر رنگ سربرگ، افزودن لوگو، مهر و امضا در فاکتور',
      icon: Palette
    },
    {
      title: 'افزودن نامحدود سطر در فاکتور',
      desc: 'افزودن تعداد نامحدود ردیف به فاکتور، ویژه کاربران نسخه حرفه‌ای',
      icon: Layers
    },
    {
      title: 'دسترسی به اضافات فاکتور',
      desc: 'هزینه‌ی ارسال، تخفیف، مالیات، بیعانه و بدهی قبلی را با جزئیات کامل به فاکتور اضافه کنید.',
      icon: FileCheck
    },
    {
      title: 'حذف لیبل فاکتور در اشتراک گذاری',
      desc: 'امکان حذف برچسب تبلیغاتی پایین فاکتور در اشتراک‌گذاری',
      icon: Award
    },
    {
      title: 'خروجی PDF از فاکتور ها',
      desc: 'دریافت خروجی PDF استاندارد و با کیفیت از فاکتورها',
      icon: FileDown
    }
  ];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6 bg-slate-900/60 backdrop-blur-md animate-fade-in">
      <div className="w-full max-w-lg bg-white dark:bg-slate-800 rounded-3xl shadow-2xl overflow-hidden flex flex-col max-h-[92vh] border border-slate-100 dark:border-slate-700">
        
        {/* Header Bar */}
        <div className="p-4 bg-white dark:bg-slate-800 border-b border-slate-100 dark:border-slate-700 flex items-center justify-between no-print">
          <span className="font-bold text-sm text-slate-800 dark:text-white">
            خرید و فعال‌سازی نسخه طلایی
          </span>
          <button onClick={onClose} className="p-1.5 rounded-full text-slate-400 hover:text-slate-600 transition">
            <X className="w-6 h-6" />
          </button>
        </div>

        <div className="p-5 overflow-y-auto space-y-5 flex-1">
          
          {/* Telegram Gift Banner (Screenshot 6) */}
          <div className="bg-gradient-to-r from-sky-100 via-blue-50 to-sky-100 dark:from-slate-700 dark:to-slate-800 p-5 rounded-3xl border border-sky-200 dark:border-slate-600 flex items-center justify-between">
            <div className="space-y-1">
              <span className="text-[11px] font-bold text-blue-600 dark:text-blue-300">
                اشتراک هدایت
              </span>
              <h3 className="font-black text-lg text-slate-900 dark:text-white">
                یک روز اشتراک رایگان
              </h3>
              <p className="text-xs text-slate-600 dark:text-slate-300">
                با عضو شدن در کانال تلگرام
              </p>
            </div>

            <div className="w-16 h-16 rounded-2xl bg-sky-400 text-white flex items-center justify-center shadow-md shrink-0">
              <Send className="w-9 h-9" />
            </div>
          </div>

          {/* Golden Features List (Screenshot 6) */}
          <div className="space-y-3">
            <h4 className="text-xs font-bold text-slate-400 dark:text-slate-400 pr-1">
              ویژگی‌های نسخه طلایی
            </h4>

            <div className="space-y-3">
              {goldenFeatures.map((feat, idx) => {
                const Icon = feat.icon;
                return (
                  <div
                    key={idx}
                    className="p-4 rounded-3xl bg-slate-50 dark:bg-slate-900/60 border border-slate-100 dark:border-slate-700/60 flex items-start justify-between gap-3 hover:border-amber-400 transition"
                  >
                    <div className="flex items-start gap-3">
                      <div className="w-10 h-10 rounded-2xl bg-amber-400 text-slate-900 flex items-center justify-center shrink-0 shadow-xs">
                        <Icon className="w-5 h-5" />
                      </div>
                      <div>
                        <h5 className="font-bold text-sm text-slate-900 dark:text-white mb-0.5">
                          {feat.title}
                        </h5>
                        <p className="text-[11px] text-slate-500 dark:text-slate-400 leading-relaxed">
                          {feat.desc}
                        </p>
                      </div>
                    </div>

                    <ChevronLeft className="w-4 h-4 text-slate-400 shrink-0 mt-2" />
                  </div>
                );
              })}
            </div>
          </div>

        </div>

        {/* Footer Actions */}
        <div className="p-4 bg-slate-50 dark:bg-slate-900 border-t border-slate-100 dark:border-slate-700 space-y-3 text-center">
          <button
            onClick={() => {
              alert('نسخه طلایی با موفقیت روی حساب کاربری شما فعال شد!');
              onClose();
            }}
            className="w-full py-3.5 rounded-2xl bg-blue-500 hover:bg-blue-600 text-white font-black text-sm shadow-md shadow-blue-500/20 transition active:scale-95"
          >
            فعالسازی یک ساله
          </button>

          <button
            onClick={() => {
              alert('لطفا شماره همراه ثبت شده خود را وارد نمایید.');
            }}
            className="text-xs font-bold text-slate-600 dark:text-slate-300 hover:underline block mx-auto"
          >
            اشتراک داری؟ ورود به حساب کاربری
          </button>
        </div>

      </div>
    </div>
  );
}
