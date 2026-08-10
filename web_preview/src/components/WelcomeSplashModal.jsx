import React from 'react';
import { Calendar, ShoppingBag, Globe, MessageSquare, ArrowLeft } from 'lucide-react';

export default function WelcomeSplashModal({ isOpen, onStart, onSkip }) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 bg-gradient-to-b from-sky-400 via-blue-500 to-blue-600 text-white flex flex-col justify-between p-6 dir-rtl font-vazir animate-fade-in">
      
      {/* Top indicator bar */}
      <div className="flex gap-1.5 justify-center max-w-xs mx-auto w-full pt-2">
        <div className="flex-1 h-1 bg-white rounded-full"></div>
        <div className="flex-1 h-1 bg-white/40 rounded-full"></div>
        <div className="flex-1 h-1 bg-white/40 rounded-full"></div>
        <div className="flex-1 h-1 bg-white/40 rounded-full"></div>
      </div>

      {/* Mascot Illustration Area (Screenshot 1) */}
      <div className="flex-1 flex flex-col items-center justify-center relative py-6">
        
        {/* Floating Icons Background */}
        <div className="relative w-64 h-64 flex items-center justify-center">
          
          {/* Calendar Icon Top Left */}
          <div className="absolute top-2 left-2 p-3 bg-white text-rose-500 rounded-2xl shadow-xl transform -rotate-12 animate-bounce">
            <Calendar className="w-8 h-8" />
          </div>

          {/* Flag Top Far Left */}
          <div className="absolute top-0 right-4 p-2.5 bg-white rounded-2xl shadow-xl transform rotate-6">
            <span className="text-2xl">🇺🇸</span>
          </div>

          {/* Speech Bubble Top Right */}
          <div className="absolute top-4 left-36 p-3 bg-amber-400 text-slate-900 font-black text-xl rounded-2xl shadow-xl transform rotate-12">
            Aa
          </div>

          {/* Shopping Bag Mid Right */}
          <div className="absolute bottom-8 right-2 p-3 bg-rose-500 text-white rounded-2xl shadow-xl transform -rotate-6">
            <ShoppingBag className="w-8 h-8" />
          </div>

          {/* Owl Character Center */}
          <div className="w-44 h-44 rounded-full bg-sky-300/30 backdrop-blur-md flex items-center justify-center p-4 relative border-4 border-white/20 shadow-2xl">
            <div className="text-8xl select-none">
              🦉
            </div>
          </div>

        </div>

      </div>

      {/* Text Content (Screenshot 1) */}
      <div className="text-center space-y-3 max-w-sm mx-auto pb-4">
        <h2 className="text-2xl font-black text-white tracking-tight">
          همیشه کنارت هستم
        </h2>
        
        <p className="text-xs text-blue-100 font-medium leading-relaxed px-4">
          چه آنلاین باشی چه آفلاین، می‌تونی فاکتور بزنی، ذخیره کنی و هر وقت لازم شد ارسالش کنی.
        </p>
      </div>

      {/* Buttons Footer (Screenshot 1) */}
      <div className="space-y-4 max-w-sm mx-auto w-full pb-2">
        <button
          onClick={onSkip}
          className="text-xs font-bold text-blue-100 hover:text-white transition block mx-auto"
        >
          رد کردن
        </button>

        <button
          onClick={onStart}
          className="w-full py-4 rounded-3xl bg-white hover:bg-slate-100 text-blue-600 font-black text-sm shadow-2xl transition active:scale-98"
        >
          بزن بریم
        </button>
      </div>

    </div>
  );
}
