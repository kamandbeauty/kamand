import React from 'react';
import {
  X,
  Settings,
  Package,
  Users,
  FileText,
  ShoppingBag,
  Sparkles,
  Wrench
} from 'lucide-react';

export default function Sidebar({
  isOpen,
  onClose,
  onNavigateTab,
  onOpenGoldenModal,
  onOpenSettings,
  onOpenSmartTools,
  onResetData
}) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center p-3 pt-4 sm:p-6 bg-slate-900/60 backdrop-blur-sm animate-fade-in">
      <div className="w-full max-w-lg bg-white dark:bg-slate-800 rounded-3xl shadow-2xl p-5 space-y-5 border border-slate-100 dark:border-slate-700 max-h-[90vh] overflow-y-auto">
        
        {/* Top Header Actions */}
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <button
              onClick={() => {
                onOpenSettings();
                onClose();
              }}
              className="w-10 h-10 rounded-full bg-slate-100 dark:bg-slate-700 flex items-center justify-center text-slate-700 dark:text-slate-200 hover:bg-slate-200 transition"
              title="تنظیمات"
            >
              <Settings className="w-5 h-5" />
            </button>

            <button
              onClick={() => {
                alert('جهت ورود به حساب کاربری، شماره همراه خود را وارد کنید.');
              }}
              className="px-4 py-2 rounded-full bg-blue-500 hover:bg-blue-600 text-white font-bold text-xs flex items-center gap-1.5 shadow-sm transition"
            >
              <div className="w-4 h-4 rounded-full bg-white/20 flex items-center justify-center text-[10px]">
                !
              </div>
              <span>ورود</span>
            </button>
          </div>

          <button
            onClick={onClose}
            className="p-2 rounded-full text-slate-400 hover:text-slate-600 dark:hover:text-white transition"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        {/* Big Golden Upgrade Banner (Screenshot 4) */}
        <div
          onClick={() => {
            onOpenGoldenModal();
            onClose();
          }}
          className="bg-gradient-to-r from-amber-400 via-amber-300 to-yellow-400 p-5 rounded-3xl text-slate-900 shadow-md cursor-pointer hover:shadow-lg transition relative overflow-hidden group"
        >
          <div className="flex items-center justify-between relative z-10">
            <div>
              <div className="flex items-center gap-1.5 text-slate-900 font-black text-lg mb-1">
                <span>خرید نسخه طلایی</span>
                <Sparkles className="w-5 h-5 text-amber-700" />
              </div>
              <p className="text-xs text-slate-800 font-medium">
                از امکانات پیشرفته بهره‌مند شوید
              </p>
            </div>

            <div className="w-12 h-12 rounded-full bg-white text-amber-500 flex items-center justify-center text-xl font-bold shadow-sm group-hover:scale-110 transition transform">
              👉
            </div>
          </div>
        </div>

        {/* 4 Main Grid Navigation Cards (Screenshot 4) */}
        <div className="grid grid-cols-2 gap-3">
          
          {/* Packages */}
          <button
            onClick={() => {
              onOpenGoldenModal();
              onClose();
            }}
            className="p-5 rounded-3xl bg-slate-100 dark:bg-slate-700/60 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-800 dark:text-white flex items-center justify-center gap-3 transition"
          >
            <span className="font-bold text-sm">پکیج ها</span>
            <Package className="w-6 h-6 text-slate-600 dark:text-slate-300" />
          </button>

          {/* Customers / People */}
          <button
            onClick={() => {
              onNavigateTab('customers');
              onClose();
            }}
            className="p-5 rounded-3xl bg-slate-100 dark:bg-slate-700/60 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-800 dark:text-white flex items-center justify-center gap-3 transition"
          >
            <span className="font-bold text-sm">افراد</span>
            <Users className="w-6 h-6 text-slate-600 dark:text-slate-300" />
          </button>

          {/* Invoices */}
          <button
            onClick={() => {
              onNavigateTab('invoices');
              onClose();
            }}
            className="p-5 rounded-3xl bg-slate-100 dark:bg-slate-700/60 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-800 dark:text-white flex items-center justify-center gap-3 transition"
          >
            <span className="font-bold text-sm">فاکتور ها</span>
            <FileText className="w-6 h-6 text-slate-600 dark:text-slate-300" />
          </button>

          {/* Products / Items */}
          <button
            onClick={() => {
              onNavigateTab('products');
              onClose();
            }}
            className="p-5 rounded-3xl bg-slate-100 dark:bg-slate-700/60 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-800 dark:text-white flex items-center justify-center gap-3 transition"
          >
            <span className="font-bold text-sm">آیتم‌ها</span>
            <ShoppingBag className="w-6 h-6 text-slate-600 dark:text-slate-300" />
          </button>

          {/* Smart Tools */}
          <button
            onClick={() => {
              if (onOpenSmartTools) onOpenSmartTools();
              onClose();
            }}
            className="p-5 rounded-3xl bg-slate-100 dark:bg-slate-700/60 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-800 dark:text-white flex items-center justify-center gap-3 transition"
          >
            <span className="font-bold text-sm">ابزارها</span>
            <Wrench className="w-6 h-6 text-slate-600 dark:text-slate-300" />
          </button>

          {/* Financial */}
          <button
            onClick={() => {
              onNavigateTab('financial');
              onClose();
            }}
            className="p-5 rounded-3xl bg-slate-100 dark:bg-slate-700/60 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-800 dark:text-white flex items-center justify-center gap-3 transition"
          >
            <span className="font-bold text-sm">امور مالی</span>
            <Sparkles className="w-6 h-6 text-slate-600 dark:text-slate-300" />
          </button>

        </div>

        {/* Direct APK Download Banner */}
        <a
          href="/FactorRuby-v5.8.0.apk"
          download
          className="p-4 rounded-3xl bg-gradient-to-r from-emerald-500 to-teal-600 text-white font-bold text-xs flex items-center justify-between shadow-md hover:shadow-lg transition block"
        >
          <span>دانلود مستقیم فایل APK (نسخه ۵.۸.۰)</span>
          <span className="w-8 h-8 rounded-full bg-white/20 flex items-center justify-center text-base">📲</span>
        </a>

        {/* Footer Version & Reset */}
        <div className="pt-3 border-t border-slate-100 dark:border-slate-700 text-center space-y-2">
          <button
            onClick={() => {
              if (window.confirm('بازنشانی به داده‌های نمونه اولیه؟')) {
                onResetData();
                onClose();
              }
            }}
            className="text-xs text-rose-500 hover:underline font-medium"
          >
            بازنشانی داده‌های اولیه
          </button>

          <p className="text-xs text-slate-400 font-medium">
            فاکتور روبی - نسخه ۵.۸.۰
          </p>
        </div>

      </div>
    </div>
  );
}
