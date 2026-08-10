import React, { useState } from 'react';
import {
  TrendingUp,
  TrendingDown,
  DollarSign,
  Plus,
  Calendar,
  PieChart,
  Wallet,
  Scale,
  Receipt,
  AlertCircle
} from 'lucide-react';
import { formatCurrency, toPersianDigits } from '../utils/helpers';

export default function FinancialView({
  invoices,
  customers,
  expenses,
  incomes,
  onAddExpense,
  onAddIncome
}) {
  const [dateFilter, setDateFilter] = useState('month'); // today, week, month, custom
  const [showExpenseModal, setShowExpenseModal] = useState(false);
  const [showIncomeModal, setShowIncomeModal] = useState(false);

  // New Income / Expense Form
  const [title, setTitle] = useState('');
  const [category, setCategory] = useState('عمومی');
  const [amount, setAmount] = useState('');
  const [notes, setNotes] = useState('');

  // Income calculations
  const totalSalesRevenue = invoices
    .filter(inv => inv.type === 'sale')
    .reduce((sum, inv) => sum + inv.totalAmount, 0);

  const totalOtherIncome = incomes.reduce((sum, inc) => sum + inc.amount, 0);

  // Expense calculations
  const totalExpensesAmount = expenses.reduce((sum, exp) => sum + exp.amount, 0);

  // Cost of goods estimation (roughly 60% of sales or based on buy prices)
  const estimatedCOGS = Math.round(totalSalesRevenue * 0.6);

  // Profit calculation
  const totalIncome = totalSalesRevenue + totalOtherIncome;
  const netProfit = totalIncome - estimatedCOGS - totalExpensesAmount;

  // Debt calculations
  const totalCustomerDebt = customers.reduce((sum, c) => sum + (c.balance || 0), 0);
  const totalSupplierDebt = invoices
    .filter(inv => inv.type === 'purchase' && inv.remainingAmount > 0)
    .reduce((sum, inv) => sum + inv.remainingAmount, 0);

  const handleExpenseSubmit = (e) => {
    e.preventDefault();
    if (!title.trim() || !amount) return;

    onAddExpense({
      id: `exp-${Date.now()}`,
      title: title.trim(),
      category,
      amount: parseFloat(amount) || 0,
      date: '1405/05/20',
      notes: notes.trim()
    });

    setShowExpenseModal(false);
    setTitle('');
    setAmount('');
    setNotes('');
  };

  const handleIncomeSubmit = (e) => {
    e.preventDefault();
    if (!title.trim() || !amount) return;

    onAddIncome({
      id: `inc-${Date.now()}`,
      title: title.trim(),
      category,
      amount: parseFloat(amount) || 0,
      date: '1405/05/20',
      notes: notes.trim()
    });

    setShowIncomeModal(false);
    setTitle('');
    setAmount('');
    setNotes('');
  };

  return (
    <div className="space-y-6 animate-fade-in pb-12">
      
      {/* Top Bar with Filter */}
      <div className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm flex flex-col sm:flex-row items-center justify-between gap-4">
        
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-2xl bg-gradient-to-tr from-emerald-500 to-teal-600 text-white flex items-center justify-center font-bold">
            <PieChart className="w-5 h-5" />
          </div>
          <div>
            <h2 className="font-bold text-lg text-slate-800 dark:text-white">
              مدیریت مالی و سود و زیان
            </h2>
            <p className="text-xs text-slate-400">تحلیل کامل درآمد، هزینه و مانده‌ها</p>
          </div>
        </div>

        {/* Range Selector */}
        <div className="flex items-center gap-1 bg-slate-100 dark:bg-slate-900 p-1 rounded-2xl text-xs font-bold w-full sm:w-auto justify-center">
          <button
            onClick={() => setDateFilter('today')}
            className={`px-3 py-2 rounded-xl transition ${dateFilter === 'today' ? 'bg-white dark:bg-slate-800 text-blue-600 shadow' : 'text-slate-500'}`}
          >
            امروز
          </button>
          <button
            onClick={() => setDateFilter('week')}
            className={`px-3 py-2 rounded-xl transition ${dateFilter === 'week' ? 'bg-white dark:bg-slate-800 text-blue-600 shadow' : 'text-slate-500'}`}
          >
            این هفته
          </button>
          <button
            onClick={() => setDateFilter('month')}
            className={`px-3 py-2 rounded-xl transition ${dateFilter === 'month' ? 'bg-white dark:bg-slate-800 text-blue-600 shadow' : 'text-slate-500'}`}
          >
            این ماه
          </button>
          <button
            onClick={() => setDateFilter('custom')}
            className={`px-3 py-2 rounded-xl transition ${dateFilter === 'custom' ? 'bg-white dark:bg-slate-800 text-blue-600 shadow' : 'text-slate-500'}`}
          >
            دلخواه
          </button>
        </div>

      </div>

      {/* Profit & Loss Main Summary Box */}
      <div className="bg-gradient-to-br from-slate-900 via-blue-950 to-indigo-950 text-white p-6 rounded-3xl shadow-xl space-y-6">
        
        <div className="flex items-center justify-between pb-4 border-b border-white/10">
          <div className="flex items-center gap-2">
            <Scale className="w-5 h-5 text-emerald-400" />
            <h3 className="font-extrabold text-base">گزارش سود و زیان دوره</h3>
          </div>
          <span className="text-xs text-blue-200 bg-white/10 px-3 py-1 rounded-full">
            مبنای محاسبه: {dateFilter === 'month' ? 'ماه جاری (مرداد)' : 'دوره انتخاب شده'}
          </span>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          
          <div className="p-4 rounded-2xl bg-white/5 border border-white/10">
            <div className="text-xs text-slate-300 mb-1 flex items-center gap-1">
              <TrendingUp className="w-4 h-4 text-emerald-400" />
              <span>کل درآمدها (فروش + سایر)</span>
            </div>
            <div className="text-xl font-black text-emerald-400">
              {formatCurrency(totalIncome)}
            </div>
          </div>

          <div className="p-4 rounded-2xl bg-white/5 border border-white/10">
            <div className="text-xs text-slate-300 mb-1 flex items-center gap-1">
              <TrendingDown className="w-4 h-4 text-rose-400" />
              <span>کل هزینه‌ها و بهای خرید</span>
            </div>
            <div className="text-xl font-black text-rose-400">
              {formatCurrency(estimatedCOGS + totalExpensesAmount)}
            </div>
          </div>

          <div className="p-4 rounded-2xl bg-white/10 border border-white/20">
            <div className="text-xs text-slate-300 mb-1 flex items-center gap-1">
              <Wallet className="w-4 h-4 text-blue-400" />
              <span>سود خالص تخمینی</span>
            </div>
            <div className={`text-2xl font-black ${netProfit >= 0 ? 'text-blue-300' : 'text-rose-400'}`}>
              {formatCurrency(netProfit)}
            </div>
          </div>

        </div>

      </div>

      {/* Financial Breakdown Cards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        
        {/* Expenses Card */}
        <div className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm space-y-4">
          
          <div className="flex items-center justify-between pb-2 border-b border-slate-100 dark:border-slate-700">
            <div className="flex items-center gap-2">
              <TrendingDown className="w-5 h-5 text-rose-500" />
              <h3 className="font-bold text-sm text-slate-800 dark:text-white">
                هزینه‌های ثبت‌شده ({toPersianDigits(expenses.length)})
              </h3>
            </div>
            <button
              onClick={() => setShowExpenseModal(true)}
              className="px-3 py-1.5 rounded-xl bg-rose-50 dark:bg-rose-900/30 text-rose-600 dark:text-rose-400 font-bold text-xs flex items-center gap-1"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>ثبت هزینه جدید</span>
            </button>
          </div>

          <div className="space-y-2 max-h-56 overflow-y-auto">
            {expenses.map((e) => (
              <div
                key={e.id}
                className="p-3 rounded-2xl bg-slate-50 dark:bg-slate-900/50 border border-slate-100 dark:border-slate-700 flex items-center justify-between text-xs"
              >
                <div>
                  <div className="font-bold text-slate-800 dark:text-white">{e.title}</div>
                  <div className="text-[10px] text-slate-400">{e.category} • {toPersianDigits(e.date)}</div>
                </div>
                <div className="font-bold text-rose-600 dark:text-rose-400">
                  {formatCurrency(e.amount)}
                </div>
              </div>
            ))}
          </div>

        </div>

        {/* Other Incomes Card */}
        <div className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm space-y-4">
          
          <div className="flex items-center justify-between pb-2 border-b border-slate-100 dark:border-slate-700">
            <div className="flex items-center gap-2">
              <TrendingUp className="w-5 h-5 text-emerald-500" />
              <h3 className="font-bold text-sm text-slate-800 dark:text-white">
                سایر درآمدها ({toPersianDigits(incomes.length)})
              </h3>
            </div>
            <button
              onClick={() => setShowIncomeModal(true)}
              className="px-3 py-1.5 rounded-xl bg-emerald-50 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400 font-bold text-xs flex items-center gap-1"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>ثبت درآمد جدید</span>
            </button>
          </div>

          <div className="space-y-2 max-h-56 overflow-y-auto">
            {incomes.map((inc) => (
              <div
                key={inc.id}
                className="p-3 rounded-2xl bg-slate-50 dark:bg-slate-900/50 border border-slate-100 dark:border-slate-700 flex items-center justify-between text-xs"
              >
                <div>
                  <div className="font-bold text-slate-800 dark:text-white">{inc.title}</div>
                  <div className="text-[10px] text-slate-400">{inc.category} • {toPersianDigits(inc.date)}</div>
                </div>
                <div className="font-bold text-emerald-600 dark:text-emerald-400">
                  {formatCurrency(inc.amount)}
                </div>
              </div>
            ))}
          </div>

        </div>

      </div>

      {/* Debt Summary Box */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm flex items-center justify-between">
          <div>
            <span className="text-xs text-slate-400 font-bold block mb-1">
              کل بدهی مشتریان به شما
            </span>
            <span className="text-xl font-black text-rose-600 dark:text-rose-400">
              {formatCurrency(totalCustomerDebt)}
            </span>
          </div>
          <div className="w-10 h-10 rounded-2xl bg-rose-50 dark:bg-rose-900/30 text-rose-600 flex items-center justify-center">
            <AlertCircle className="w-5 h-5" />
          </div>
        </div>

        <div className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm flex items-center justify-between">
          <div>
            <span className="text-xs text-slate-400 font-bold block mb-1">
              کل بدهی شما به تامین کنندگان
            </span>
            <span className="text-xl font-black text-amber-600 dark:text-amber-400">
              {formatCurrency(totalSupplierDebt)}
            </span>
          </div>
          <div className="w-10 h-10 rounded-2xl bg-amber-50 dark:bg-amber-900/30 text-amber-600 flex items-center justify-center">
            <Wallet className="w-5 h-5" />
          </div>
        </div>
      </div>

      {/* Add Expense Modal */}
      {showExpenseModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
          <div className="w-full max-w-md bg-white dark:bg-slate-800 rounded-3xl p-6 shadow-2xl space-y-4">
            <h3 className="font-bold text-base text-slate-800 dark:text-white">
              ثبت هزینه جدید
            </h3>
            <form onSubmit={handleExpenseSubmit} className="space-y-3 text-xs">
              <input
                type="text"
                required
                placeholder="عنوان هزینه (مثلا اجاره مغازه)"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 font-medium"
              />
              <input
                type="number"
                required
                placeholder="مبلغ به تومان"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 font-bold text-rose-600"
              />
              <select
                value={category}
                onChange={(e) => setCategory(e.target.value)}
                className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 font-medium"
              >
                <option value="اجاره">اجاره</option>
                <option value="قبوض">قبوض و انرژی</option>
                <option value="حقوق و دستمزد">حقوق و پرسنل</option>
                <option value="ملزومات">ملزومات و بسته بندی</option>
                <option value="تبلیغات">تبلیغات و بازاریابی</option>
                <option value="عمومی">سایر هزینه ها</option>
              </select>
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => setShowExpenseModal(false)}
                  className="flex-1 py-3 rounded-2xl border border-slate-200 font-bold"
                >
                  انصراف
                </button>
                <button
                  type="submit"
                  className="flex-1 py-3 rounded-2xl bg-rose-600 text-white font-bold shadow"
                >
                  ثبت هزینه
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Add Income Modal */}
      {showIncomeModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
          <div className="w-full max-w-md bg-white dark:bg-slate-800 rounded-3xl p-6 shadow-2xl space-y-4">
            <h3 className="font-bold text-base text-slate-800 dark:text-white">
              ثبت درآمد جدید
            </h3>
            <form onSubmit={handleIncomeSubmit} className="space-y-3 text-xs">
              <input
                type="text"
                required
                placeholder="عنوان درآمد (مثلا مشاوره یا خدمات)"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 font-medium"
              />
              <input
                type="number"
                required
                placeholder="مبلغ به تومان"
                value={amount}
                onChange={(e) => setAmount(e.target.value)}
                className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 font-bold text-emerald-600"
              />
              <div className="flex gap-2">
                <button
                  type="button"
                  onClick={() => setShowIncomeModal(false)}
                  className="flex-1 py-3 rounded-2xl border border-slate-200 font-bold"
                >
                  انصراف
                </button>
                <button
                  type="submit"
                  className="flex-1 py-3 rounded-2xl bg-emerald-600 text-white font-bold shadow"
                >
                  ثبت درآمد
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
}
