import React from 'react';
import { Menu, Sparkles, Lock, Moon, Sun, Search, Wrench } from 'lucide-react';

export default function Navbar({
  onOpenSidebar,
  onOpenGoldenModal,
  onOpenGlobalSearch,
  onOpenSmartTools,
  isDarkMode,
  onToggleDarkMode,
  onLockApp
}) {
  return (
    <header className="sticky top-0 z-30 bg-white/95 dark:bg-slate-800/95 backdrop-blur-md border-b border-slate-200 dark:border-slate-700 px-4 py-3 shadow-xs">
      <div className="max-w-4xl mx-auto flex items-center justify-between">
        
        {/* Right side: Hamburger menu button */}
        <div className="flex items-center gap-2">
          <button
            onClick={onOpenSidebar}
            className="p-1.5 rounded-xl text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700 transition"
            title="منوی اصلی"
          >
            <Menu className="w-6 h-6" />
          </button>
          <button
            onClick={onOpenGlobalSearch}
            className="p-1.5 rounded-xl text-slate-700 dark:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-700 transition"
            title="جستجوی سراسری"
          >
            <Search className="w-5 h-5" />
          </button>
        </div>

        {/* Center: App Title */}
        <div className="flex items-center gap-1.5">
          <h1 className="font-extrabold text-xl text-slate-900 dark:text-white tracking-tight">
            فاکتور روبی
          </h1>
        </div>

        {/* Left side: Sparkle / Golden icon button */}
        <div className="flex items-center gap-2">
          <button
            onClick={onOpenSmartTools}
            className="p-1.5 rounded-xl text-blue-500 hover:bg-blue-50 dark:hover:bg-blue-900/20 transition"
            title="ابزارهای هوشمند"
          >
            <Wrench className="w-5 h-5 text-blue-500" />
          </button>

          <button
            onClick={onOpenGoldenModal}
            className="p-1.5 rounded-xl text-amber-500 hover:bg-amber-50 dark:hover:bg-amber-900/20 transition"
            title="نسخه طلایی"
          >
            <Sparkles className="w-6 h-6 text-amber-400" />
          </button>

          <button
            onClick={onToggleDarkMode}
            className="p-1.5 rounded-xl text-slate-500 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 transition"
            title={isDarkMode ? "حالت روشن" : "حالت تاریک"}
          >
            {isDarkMode ? <Sun className="w-5 h-5 text-amber-400" /> : <Moon className="w-5 h-5" />}
          </button>

          <button
            onClick={onLockApp}
            className="p-1.5 rounded-xl text-slate-500 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-700 transition"
            title="قفل برنامه"
          >
            <Lock className="w-5 h-5" />
          </button>
        </div>

      </div>
    </header>
  );
}
