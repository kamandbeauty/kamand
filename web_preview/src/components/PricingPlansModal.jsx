import React, { useState } from 'react';
import { X, Star, CheckCircle2 } from 'lucide-react';
import { toPersianDigits } from '../utils/helpers';

export default function PricingPlansModal({ isOpen, onClose }) {
  if (!isOpen) return null;

  const [selectedPlan, setSelectedPlan] = useState('year');

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6 bg-slate-900/60 backdrop-blur-md font-vazir animate-fade-in">
      <div className="w-full max-w-lg bg-white dark:bg-slate-800 rounded-3xl shadow-2xl overflow-hidden flex flex-col max-h-[92vh] border border-slate-100 dark:border-slate-700">
        
        {/* Header Close */}
        <div className="p-4 flex items-center justify-between no-print">
          <div className="w-6" />
          <button onClick={onClose} className="p-1.5 rounded-full text-slate-400 hover:text-slate-600 transition">
            <X className="w-6 h-6" />
          </button>
        </div>

        <div className="p-5 overflow-y-auto space-y-5 flex-1">
          
          {/* Owl Character & Header (Screenshot 1) */}
          <div className="text-center space-y-2">
            <div className="w-20 h-20 mx-auto bg-sky-100 dark:bg-sky-900/40 rounded-full flex items-center justify-center text-4xl">
              🦉
            </div>

            <h2 className="font-black text-2xl text-slate-900 dark:text-white">
              از محدودیت‌ها عبور کنید!
            </h2>

            <p className="text-xs text-slate-500 dark:text-slate-400 font-medium">
              با اشتراک طلایی، از امکانات پیشرفته بهره‌مند شوید.
            </p>
          </div>

          {/* Pricing Plans List (Screenshot 1) */}
          <div className="space-y-3 pt-2">
            
            {/* PLAN 1: 1 Year (Suggested) */}
            <div
              onClick={() => setSelectedPlan('year')}
              className={`p-4 rounded-3xl border-2 transition cursor-pointer relative ${
                selectedPlan === 'year'
                  ? 'border-amber-400 bg-amber-50/30 dark:bg-amber-900/20 shadow-xs'
                  : 'border-slate-200 dark:border-slate-700'
              }`}
            >
              <div className="flex items-center justify-between gap-2 pb-1">
                <div className="flex items-center gap-1.5 text-xs font-bold text-amber-600 bg-amber-100 px-2.5 py-0.5 rounded-full">
                  <Star className="w-3.5 h-3.5 fill-amber-500 text-amber-500" />
                  <span>پیشنهادی</span>
                </div>

                <div className="flex items-center gap-2">
                  <span className="font-extrabold text-slate-900 dark:text-white text-base">یک ساله</span>
                  <div className={`w-5 h-5 rounded-full border-2 flex items-center justify-center ${selectedPlan === 'year' ? 'border-amber-500 bg-amber-400' : 'border-slate-300'}`}>
                    {selectedPlan === 'year' && <div className="w-2 h-2 rounded-full bg-white" />}
                  </div>
                </div>
              </div>

              <div className="flex items-center justify-between pt-2">
                <div className="flex items-center gap-2">
                  <span className="px-2 py-0.5 rounded-lg bg-rose-500 text-white font-bold text-[10px]">
                    ۲۰% تخفیف
                  </span>
                  <span className="text-xs text-slate-400 line-through">
                    ۹۹۰ هزار تومان
                  </span>
                  <span className="font-black text-sm text-slate-900 dark:text-white">
                    ۷۹۰ هزار تومان
                  </span>
                </div>
              </div>

              <div className="text-[11px] text-amber-700 dark:text-amber-300 font-bold pt-2 text-right">
                ☀️ به صرفه‌ترین - ماهانه ۶۵ هزار تومان
              </div>
            </div>

            {/* PLAN 2: 6 Months */}
            <div
              onClick={() => setSelectedPlan('6months')}
              className={`p-4 rounded-3xl border-2 transition cursor-pointer relative ${
                selectedPlan === '6months'
                  ? 'border-amber-400 bg-amber-50/30 dark:bg-amber-900/20 shadow-xs'
                  : 'border-slate-200 dark:border-slate-700 bg-slate-50/60 dark:bg-slate-900/50'
              }`}
            >
              <div className="text-center text-[10px] text-slate-400 font-bold mb-1">شش ماهه</div>
              <div className="flex items-center justify-between">
                <div className="font-black text-sm text-slate-900 dark:text-white">
                  ۶۹۰ هزار تومان
                </div>

                <div className="flex items-center gap-2">
                  <span className="font-extrabold text-slate-900 dark:text-white text-sm">شش ماهه</span>
                  <div className={`w-5 h-5 rounded-full border-2 flex items-center justify-center ${selectedPlan === '6months' ? 'border-amber-500 bg-amber-400' : 'border-slate-300'}`}>
                    {selectedPlan === '6months' && <div className="w-2 h-2 rounded-full bg-white" />}
                  </div>
                </div>
              </div>

              <div className="text-[11px] text-slate-600 dark:text-slate-300 font-bold pt-2 text-right">
                💡 مقرون به صرفه‌تر - ماهانه ۱۱۵ هزار تومان
              </div>
            </div>

            {/* PLAN 3: 1 Month */}
            <div
              onClick={() => setSelectedPlan('1month')}
              className={`p-4 rounded-3xl border-2 transition cursor-pointer relative ${
                selectedPlan === '1month'
                  ? 'border-amber-400 bg-amber-50/30 dark:bg-amber-900/20 shadow-xs'
                  : 'border-slate-200 dark:border-slate-700 bg-slate-50/60 dark:bg-slate-900/50'
              }`}
            >
              <div className="text-center text-[10px] text-slate-400 font-bold mb-1">شروع</div>
              <div className="flex items-center justify-between">
                <div className="font-black text-sm text-slate-900 dark:text-white">
                  ۱۳۰ هزار تومان
                </div>

                <div className="flex items-center gap-2">
                  <span className="font-extrabold text-slate-900 dark:text-white text-sm">یک ماهه</span>
                  <div className={`w-5 h-5 rounded-full border-2 flex items-center justify-center ${selectedPlan === '1month' ? 'border-amber-500 bg-amber-400' : 'border-slate-300'}`}>
                    {selectedPlan === '1month' && <div className="w-2 h-2 rounded-full bg-white" />}
                  </div>
                </div>
              </div>

              <div className="text-[11px] text-slate-600 dark:text-slate-300 font-bold pt-2 text-right">
                🏆 پرفروش‌ترین
              </div>
            </div>

          </div>

        </div>

        {/* Footer Actions */}
        <div className="p-4 bg-slate-50 dark:bg-slate-900 border-t border-slate-100 dark:border-slate-700 space-y-3 text-center">
          <button
            onClick={() => {
              const planName = selectedPlan === 'year' ? 'یک ساله' : selectedPlan === '6months' ? 'شش ماهه' : 'یک ماهه';
              alert(`اشتراک ${planName} با موفقیت فعال گردید.`);
              onClose();
            }}
            className="w-full py-3.5 rounded-2xl bg-sky-500 hover:bg-sky-600 text-white font-black text-sm shadow-md transition active:scale-98"
          >
            {selectedPlan === 'year' ? 'فعالسازی یک ساله' : selectedPlan === '6months' ? 'فعالسازی شش ماهه' : 'فعالسازی یک ماهه'}
          </button>

          <button
            onClick={() => {
              alert('لطفا شماره همراه خود را وارد کنید.');
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
