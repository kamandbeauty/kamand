import React from 'react';
import {
  Plus,
  TrendingUp,
  CreditCard,
  AlertCircle,
  FileCheck,
  UserPlus,
  PackagePlus,
  ChevronLeft,
  Search,
  Eye,
  ArrowUpRight,
  Receipt
} from 'lucide-react';
import { formatCurrency, toPersianDigits, getTodayJalali } from '../utils/helpers';

export default function DashboardView({
  invoices,
  customers,
  products,
  onNewInvoice,
  onNewCustomer,
  onNewProduct,
  onViewInvoice,
  onNavigateTab
}) {
  // Calculations
  const today = getTodayJalali();
  const todayInvoices = invoices.filter(inv => inv.date === today && inv.type === 'sale');
  const todaySales = todayInvoices.reduce((acc, inv) => acc + inv.totalAmount, 0);
  const todayReceived = todayInvoices.reduce((acc, inv) => acc + inv.paidAmount, 0);
  
  const totalCustomerDebt = customers.reduce((acc, c) => acc + (c.balance || 0), 0);
  const totalInvoicesCount = invoices.length;

  const recentInvoices = [...invoices].reverse().slice(0, 6);

  const getStatusBadge = (status, type) => {
    if (type === 'proforma') {
      return (
        <span className="px-2.5 py-1 rounded-full text-[11px] font-bold bg-amber-50 dark:bg-amber-900/30 text-amber-600 dark:text-amber-400 border border-amber-200 dark:border-amber-800">
          پیش‌فاکتور
        </span>
      );
    }
    if (status === 'paid') {
      return (
        <span className="px-2.5 py-1 rounded-full text-[11px] font-bold bg-emerald-50 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-800">
          پرداخت شده
        </span>
      );
    }
    if (status === 'unpaid' || status === 'partial') {
      return (
        <span className="px-2.5 py-1 rounded-full text-[11px] font-bold bg-rose-50 dark:bg-rose-900/30 text-rose-600 dark:text-rose-400 border border-rose-200 dark:border-rose-800">
          بدهکار / غیرنقدی
        </span>
      );
    }
    return (
      <span className="px-2.5 py-1 rounded-full text-[11px] font-bold bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-300">
        عادی
      </span>
    );
  };

  return (
    <div className="space-y-6 animate-fade-in pb-12">
      
      {/* Stat Cards Grid - Cards with Rounded 20-24px Corners */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        
        {/* Stat 1: Today Sale */}
        <div className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700/60 shadow-sm hover:shadow-md transition">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold text-slate-500 dark:text-slate-400">
              فروش امروز
            </span>
            <div className="w-10 h-10 rounded-2xl bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 flex items-center justify-center">
              <TrendingUp className="w-5 h-5" />
            </div>
          </div>
          <div className="text-xl lg:text-2xl font-black text-slate-800 dark:text-white">
            {formatCurrency(todaySales)}
          </div>
          <div className="mt-2 text-[11px] text-slate-400 flex items-center gap-1">
            <span>ثبت شده در امروز</span>
          </div>
        </div>

        {/* Stat 2: Today Received */}
        <div className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700/60 shadow-sm hover:shadow-md transition">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold text-slate-500 dark:text-slate-400">
              دریافت امروز
            </span>
            <div className="w-10 h-10 rounded-2xl bg-emerald-50 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400 flex items-center justify-center">
              <CreditCard className="w-5 h-5" />
            </div>
          </div>
          <div className="text-xl lg:text-2xl font-black text-slate-800 dark:text-white">
            {formatCurrency(todayReceived)}
          </div>
          <div className="mt-2 text-[11px] text-emerald-600 dark:text-emerald-400 font-medium">
            نقدی و واریزی دریافتی
          </div>
        </div>

        {/* Stat 3: Customer Debt */}
        <div className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700/60 shadow-sm hover:shadow-md transition">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold text-slate-500 dark:text-slate-400">
              بدهی مشتریان
            </span>
            <div className="w-10 h-10 rounded-2xl bg-rose-50 dark:bg-rose-900/30 text-rose-600 dark:text-rose-400 flex items-center justify-center">
              <AlertCircle className="w-5 h-5" />
            </div>
          </div>
          <div className="text-xl lg:text-2xl font-black text-rose-600 dark:text-rose-400">
            {formatCurrency(totalCustomerDebt)}
          </div>
          <div className="mt-2 text-[11px] text-slate-400 flex items-center justify-between">
            <span>مجموع طلبی از مشتریان</span>
            <button
              onClick={() => onNavigateTab('customers')}
              className="text-blue-600 dark:text-blue-400 font-bold hover:underline"
            >
              مشاهده
            </button>
          </div>
        </div>

        {/* Stat 4: Invoice Count */}
        <div className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700/60 shadow-sm hover:shadow-md transition">
          <div className="flex items-center justify-between mb-3">
            <span className="text-xs font-bold text-slate-500 dark:text-slate-400">
              تعداد فاکتورها
            </span>
            <div className="w-10 h-10 rounded-2xl bg-indigo-50 dark:bg-indigo-900/30 text-indigo-600 dark:text-indigo-400 flex items-center justify-center">
              <FileCheck className="w-5 h-5" />
            </div>
          </div>
          <div className="text-xl lg:text-2xl font-black text-slate-800 dark:text-white">
            {toPersianDigits(totalInvoicesCount)} <span className="text-xs font-normal text-slate-400">فقره</span>
          </div>
          <div className="mt-2 text-[11px] text-slate-400">
            شامل فروش، خرید و پیش‌فاکتور
          </div>
        </div>

      </div>

      {/* Main Quick Action Buttons */}
      <div className="grid grid-cols-3 gap-3">
        <button
          onClick={onNewInvoice}
          className="p-4 rounded-3xl bg-blue-600 hover:bg-blue-700 text-white shadow-lg shadow-blue-500/20 flex flex-col sm:flex-row items-center justify-center gap-2 font-bold text-xs sm:text-sm transition active:scale-95"
        >
          <div className="w-8 h-8 rounded-full bg-white/20 flex items-center justify-center">
            <Plus className="w-5 h-5" />
          </div>
          <span>فاکتور جدید</span>
        </button>

        <button
          onClick={onNewCustomer}
          className="p-4 rounded-3xl bg-white dark:bg-slate-800 hover:bg-slate-50 dark:hover:bg-slate-700/80 text-slate-800 dark:text-white border border-slate-200 dark:border-slate-700 shadow-sm flex flex-col sm:flex-row items-center justify-center gap-2 font-bold text-xs sm:text-sm transition active:scale-95"
        >
          <div className="w-8 h-8 rounded-full bg-emerald-100 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400 flex items-center justify-center">
            <UserPlus className="w-4 h-4" />
          </div>
          <span>مشتری جدید</span>
        </button>

        <button
          onClick={onNewProduct}
          className="p-4 rounded-3xl bg-white dark:bg-slate-800 hover:bg-slate-50 dark:hover:bg-slate-700/80 text-slate-800 dark:text-white border border-slate-200 dark:border-slate-700 shadow-sm flex flex-col sm:flex-row items-center justify-center gap-2 font-bold text-xs sm:text-sm transition active:scale-95"
        >
          <div className="w-8 h-8 rounded-full bg-purple-100 dark:bg-purple-900/30 text-purple-600 dark:text-purple-400 flex items-center justify-center">
            <PackagePlus className="w-4 h-4" />
          </div>
          <span>کالا جدید</span>
        </button>
      </div>

      {/* Recent Invoices List */}
      <div className="bg-white dark:bg-slate-800 rounded-3xl border border-slate-100 dark:border-slate-700/60 p-5 shadow-sm">
        
        <div className="flex items-center justify-between mb-4 pb-3 border-b border-slate-100 dark:border-slate-700">
          <div className="flex items-center gap-2">
            <Receipt className="w-5 h-5 text-blue-600 dark:text-blue-400" />
            <h2 className="font-bold text-slate-800 dark:text-white text-base">
              آخرین فاکتورها
            </h2>
          </div>
          <button
            onClick={() => onNavigateTab('invoices')}
            className="flex items-center gap-1 text-xs font-bold text-blue-600 dark:text-blue-400 hover:underline"
          >
            <span>مشاهده همه</span>
            <ChevronLeft className="w-4 h-4" />
          </button>
        </div>

        {recentInvoices.length === 0 ? (
          <div className="py-12 text-center text-slate-400 text-xs">
            هنوز فاکتوری ثبت نشده است. با دکمه بالا اولین فاکتور خود را ایجاد کنید.
          </div>
        ) : (
          <div className="space-y-3">
            {recentInvoices.map((inv) => (
              <div
                key={inv.id}
                onClick={() => onViewInvoice(inv)}
                className="p-3.5 rounded-2xl border border-slate-100 dark:border-slate-700/50 hover:border-blue-300 dark:hover:border-blue-700 hover:bg-slate-50/80 dark:hover:bg-slate-700/30 transition cursor-pointer flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3"
              >
                
                {/* Right side: Number & Customer & Date */}
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-200 flex items-center justify-center font-bold text-xs shrink-0">
                    #{toPersianDigits(inv.number)}
                  </div>
                  <div>
                    <h3 className="font-bold text-sm text-slate-800 dark:text-white">
                      {inv.customerName || 'مشتری عمومی'}
                    </h3>
                    <div className="text-[11px] text-slate-400 flex items-center gap-2">
                      <span>تاریخ: {toPersianDigits(inv.date)}</span>
                      <span>•</span>
                      <span>{inv.items.length} آیتم</span>
                    </div>
                  </div>
                </div>

                {/* Left side: Amount & Status & Arrow */}
                <div className="flex items-center justify-between sm:justify-end w-full sm:w-auto gap-4 pt-2 sm:pt-0 border-t sm:border-t-0 border-slate-100 dark:border-slate-800">
                  <div className="text-left">
                    <div className="font-black text-sm text-slate-800 dark:text-white">
                      {formatCurrency(inv.totalAmount)}
                    </div>
                    <div className="mt-0.5">
                      {getStatusBadge(inv.status, inv.type)}
                    </div>
                  </div>

                  <div className="p-2 rounded-xl bg-slate-100 dark:bg-slate-700 text-slate-400 group-hover:text-blue-600 transition">
                    <Eye className="w-4 h-4" />
                  </div>
                </div>

              </div>
            ))}
          </div>
        )}

      </div>

    </div>
  );
}
