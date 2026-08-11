import React from 'react';
import { Menu, Sparkles, Lock, Moon, Sun, Search, Wrench } from 'lucide-react';

export default function Navbar({
  onOpenSidebar,
  onOpenGoldenModal,
  onOpenGlobalSearch,
  onOpenSmartTools,
  isDarkMode,
  onToggleDarkMode,
  onLockApp,
  /** وقتی true باشد هدر سفید سبک فیدا/فلاتر برای صفحه فاکتور نمایش داده می‌شود */
  invoiceHomeMode = false,
  shopName = 'فاکتور ساز روبی'
}) {
  // هدر صفحه اصلی فاکتور — سفید، لوگو چپ، عنوان وسط، منو راست (مثل فلاتر)
  if (invoiceHomeMode) {
    return (
      <header className="sticky top-0 z-30 bg-white dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700">
        <div className="max-w-lg mx-auto h-14 px-2 flex items-center justify-between" dir="rtl">
          {/* راست: منو */}
          <button
            onClick={onOpenSidebar}
            className="w-11 h-11 flex items-center justify-center rounded-xl text-slate-700 dark:text-white hover:bg-slate-100 dark:hover:bg-slate-700 transition"
            title="منوی اصلی"
          >
            <Menu className="w-6 h-6" />
          </button>

          {/* وسط: نام فروشگاه */}
          <h1 className="font-black text-[16px] text-slate-800 dark:text-white truncate max-w-[55%] text-center">
            {shopName}
          </h1>

          {/* چپ: لوگو / نسخه طلایی */}
          <div className="flex items-center">
            <button
              onClick={onOpenGoldenModal}
              className="w-11 h-11 flex items-center justify-center rounded-xl hover:bg-amber-50 dark:hover:bg-amber-900/20 transition"
              title="نسخه طلایی"
            >
              <div className="w-7 h-7 rounded-md bg-gradient-to-br from-amber-400 to-orange-500 flex items-center justify-center shadow-sm">
                <Sparkles className="w-4 h-4 text-white" />
              </div>
            </button>
          </div>
        </div>
      </header>
    );
  }

  // هدر عمومی (سایر صفحات)
  return (
    <header className="sticky top-0 z-30 bg-[#F97316] shadow-md px-4 py-3">
      <div className="max-w-4xl mx-auto flex items-center justify-between">
        <div className="flex items-center gap-2">
          <button
            onClick={onOpenSidebar}
            className="p-1.5 rounded-xl text-white hover:bg-white/20 transition"
            title="منوی اصلی"
          >
            <Menu className="w-6 h-6" />
          </button>
          <button
            onClick={onOpenGlobalSearch}
            className="p-1.5 rounded-xl text-white hover:bg-white/20 transition"
            title="جستجوی سراسری"
          >
            <Search className="w-5 h-5" />
          </button>
        </div>

        <div className="flex items-center gap-1.5">
          <h1 className="font-extrabold text-xl text-white tracking-tight">فاکتور ساز روبی</h1>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={onOpenSmartTools}
            className="p-1.5 rounded-xl text-white hover:bg-white/20 transition"
            title="ابزارهای هوشمند"
          >
            <Wrench className="w-5 h-5" />
          </button>

          <button
            onClick={onOpenGoldenModal}
            className="p-1.5 rounded-xl text-amber-300 hover:bg-white/20 transition"
            title="نسخه طلایی"
          >
            <Sparkles className="w-6 h-6 text-amber-300" />
          </button>

          <button
            onClick={onToggleDarkMode}
            className="p-1.5 rounded-xl text-white hover:bg-white/20 transition"
            title={isDarkMode ? 'حالت روشن' : 'حالت تاریک'}
          >
            {isDarkMode ? (
              <Sun className="w-5 h-5 text-amber-300" />
            ) : (
              <Moon className="w-5 h-5" />
            )}
          </button>

          <button
            onClick={onLockApp}
            className="p-1.5 rounded-xl text-white hover:bg-white/20 transition"
            title="قفل برنامه"
          >
            <Lock className="w-5 h-5" />
          </button>
        </div>
      </div>
    </header>
  );
}
