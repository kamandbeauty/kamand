import React from 'react';

/**
 * اسپلش اسکرین برند روبی — تصویر کامل rubilogo.jpg به‌صورت تمام‌صفحه
 */
export default function WelcomeSplashModal({ isOpen, onStart, onSkip }) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 bg-[#FFF9F3] dir-rtl font-vazir animate-fade-in">
      {/* تصویر کامل اسپلش برند روبی */}
      <img
        src="/rubilogo.jpg"
        alt="فاکتور ساز روبی"
        className="absolute inset-0 w-full h-full object-cover select-none pointer-events-none"
        draggable={false}
      />

      {/* دکمه‌های ورود */}
      <div className="absolute inset-x-0 bottom-0 p-6 pb-8 space-y-4 max-w-sm mx-auto w-full">
        <button
          onClick={onStart}
          className="w-full py-4 rounded-3xl bg-white hover:bg-slate-100 text-red-600 font-black text-sm shadow-2xl transition active:scale-98"
        >
          بزن بریم
        </button>

        <button
          onClick={onSkip}
          className="text-xs font-bold text-white/90 hover:text-white transition block mx-auto"
        >
          رد کردن
        </button>
      </div>
    </div>
  );
}
