import React from 'react';
import { X, CheckCircle2 } from 'lucide-react';

export default function OpenWindowsModal({
  isOpen,
  onClose,
  tabs,
  activeTabId,
  onSelectTab,
  onCloseTab
}) {
  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm animate-fade-in">
      <div className="w-full max-w-md bg-white dark:bg-slate-800 rounded-3xl p-6 shadow-2xl space-y-4 border border-slate-100 dark:border-slate-700">
        
        {/* Header */}
        <div className="flex items-center justify-between pb-2 border-b border-slate-100 dark:border-slate-700">
          <span className="text-xs text-slate-400 font-bold">
            {tabs.length} پنجره
          </span>
          <div className="flex items-center gap-2">
            <h3 className="font-extrabold text-base text-slate-800 dark:text-white">
              پنجره‌های باز
            </h3>
            <button onClick={onClose} className="p-1 text-slate-400 hover:text-slate-600 transition">
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        <p className="text-xs text-slate-500 dark:text-slate-400 leading-relaxed text-right">
          این فاکتورها موقتی هستند. برای جلوگیری از حذف شدن، آن‌ها را ذخیره کنید.
        </p>

        {/* Tab List */}
        <div className="space-y-2 max-h-60 overflow-y-auto pt-1">
          {tabs.map((tab) => {
            const isActive = tab.id === activeTabId;
            return (
              <div
                key={tab.id}
                className={`p-3.5 rounded-2xl border flex items-center justify-between gap-3 transition cursor-pointer ${
                  isActive
                    ? 'bg-blue-50 dark:bg-blue-900/40 border-blue-200 dark:border-blue-700 text-blue-700 dark:text-blue-300 font-bold'
                    : 'bg-slate-50 dark:bg-slate-900/50 border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-200'
                }`}
              >
                <button
                  onClick={(e) => {
                    e.stopPropagation();
                    onCloseTab(tab.id);
                  }}
                  className="p-1 text-slate-400 hover:text-rose-500 rounded-lg transition"
                  title="بستن این فاکتور"
                >
                  <X className="w-4 h-4" />
                </button>

                <div
                  onClick={() => {
                    onSelectTab(tab.id);
                    onClose();
                  }}
                  className="flex-1 text-right flex items-center justify-end gap-2"
                >
                  <span>{tab.title}</span>
                  {isActive && <CheckCircle2 className="w-5 h-5 text-blue-500 fill-blue-500 text-white shrink-0" />}
                </div>
              </div>
            );
          })}
        </div>

      </div>
    </div>
  );
}
