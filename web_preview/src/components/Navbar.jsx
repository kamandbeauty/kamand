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
    <header className="sticky top-0 z-30 bg-[#F97316] shadow-md px-4 py-3">
      <div className="max-w-4xl mx-auto flex items-center justify-between">
        
        {/* Right side: Hamburger menu button */}
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

        {/* Center: App Title */}
        <div className="flex items-center gap-1.5">
          <h1 className="font-extrabold text-xl text-white tracking-tight">
            فاکتور ساز روبی
          </h1>
        </div>

        {/* Left side: Sparkle / Golden icon button */}
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
            title={isDarkMode ? "حالت روشن" : "حالت تاریک"}
          >
            {isDarkMode ? <Sun className="w-5 h-5 text-amber-300" /> : <Moon className="w-5 h-5" />}
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
