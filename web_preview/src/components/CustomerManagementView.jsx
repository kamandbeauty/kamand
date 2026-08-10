import React, { useState } from 'react';
import {
  Users,
  Search,
  Plus,
  Phone,
  MapPin,
  FileText,
  CreditCard,
  Send,
  Edit,
  Trash2,
  X,
  CheckCircle,
  AlertCircle
} from 'lucide-react';
import { formatCurrency, toPersianDigits } from '../utils/helpers';

export default function CustomerManagementView({
  customers,
  invoices,
  business,
  onAddCustomer,
  onEditCustomer,
  onDeleteCustomer,
  onRecordCustomerPayment,
  onViewInvoice
}) {
  const [searchTerm, setSearchTerm] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [editingCustomer, setEditingCustomer] = useState(null);

  // Form state
  const [name, setName] = useState('');
  const [mobile, setMobile] = useState('');
  const [phone, setPhone] = useState('');
  const [address, setAddress] = useState('');
  const [notes, setNotes] = useState('');
  const [balance, setBalance] = useState('0');

  // Reminder Modal
  const [reminderCustomer, setReminderCustomer] = useState(null);

  // Payment Modal
  const [paymentCustomer, setPaymentCustomer] = useState(null);
  const [paymentAmount, setPaymentAmount] = useState('');

  const openAddModal = () => {
    setEditingCustomer(null);
    setName('');
    setMobile('');
    setPhone('');
    setAddress('');
    setNotes('');
    setBalance('0');
    setShowModal(true);
  };

  const openEditModal = (c) => {
    setEditingCustomer(c);
    setName(c.name || '');
    setMobile(c.mobile || '');
    setPhone(c.phone || '');
    setAddress(c.address || '');
    setNotes(c.notes || '');
    setBalance((c.balance || 0).toString());
    setShowModal(true);
  };

  const handleSave = (e) => {
    e.preventDefault();
    if (!name.trim()) {
      alert('لطفا نام مشتری را وارد کنید.');
      return;
    }

    const customerData = {
      id: editingCustomer?.id || `c-${Date.now()}`,
      name: name.trim(),
      mobile: mobile.trim(),
      phone: phone.trim(),
      address: address.trim(),
      notes: notes.trim(),
      balance: parseFloat(balance) || 0,
      createdAt: editingCustomer?.createdAt || new Date().toISOString()
    };

    if (editingCustomer) {
      onEditCustomer(customerData);
    } else {
      onAddCustomer(customerData);
    }

    setShowModal(false);
  };

  const handlePaymentSubmit = () => {
    const amt = parseFloat(paymentAmount);
    if (!amt || amt <= 0) {
      alert('مبلغ معتبری وارد کنید.');
      return;
    }
    onRecordCustomerPayment(paymentCustomer.id, amt);
    setPaymentCustomer(null);
    setPaymentAmount('');
  };

  const filtered = customers.filter(c =>
    c.name.includes(searchTerm.trim()) ||
    c.mobile.includes(searchTerm.trim()) ||
    c.phone.includes(searchTerm.trim())
  );

  return (
    <div className="space-y-6 animate-fade-in pb-12">
      
      {/* Top Bar & Search */}
      <div className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm flex flex-col sm:flex-row items-center justify-between gap-4">
        
        <div className="flex items-center gap-3 w-full sm:w-auto">
          <div className="w-10 h-10 rounded-2xl bg-emerald-600 text-white flex items-center justify-center font-bold">
            <Users className="w-5 h-5" />
          </div>
          <div>
            <h2 className="font-bold text-lg text-slate-800 dark:text-white">
              مدیریت مشتریان و حساب‌ها
            </h2>
            <p className="text-xs text-slate-400">
              مجموع {toPersianDigits(customers.length)} مشتری ثبت‌شده
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 w-full sm:w-auto">
          <div className="relative flex-1 sm:w-64">
            <Search className="w-4 h-4 absolute right-3 top-3.5 text-slate-400" />
            <input
              type="text"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              placeholder="جستجوی نام یا تلفن..."
              className="w-full pr-9 pl-3 py-2.5 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white text-xs"
            />
          </div>

          <button
            onClick={openAddModal}
            className="px-4 py-2.5 rounded-2xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs shadow-md shadow-emerald-500/20 flex items-center gap-1.5 shrink-0 transition"
          >
            <Plus className="w-4 h-4" />
            <span>مشتری جدید</span>
          </button>
        </div>

      </div>

      {/* Customer List Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {filtered.length === 0 ? (
          <div className="col-span-full py-12 text-center text-slate-400 text-xs bg-white dark:bg-slate-800 rounded-3xl p-6">
            مشتری با این مشخصات یافت نشد.
          </div>
        ) : (
          filtered.map((customer) => {
            const customerInvoices = invoices.filter(inv => inv.customerId === customer.id);
            const hasDebt = (customer.balance || 0) > 0;

            return (
              <div
                key={customer.id}
                className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm hover:shadow-md transition space-y-4 flex flex-col justify-between"
              >
                <div className="space-y-3">
                  
                  {/* Name & Balance Status */}
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <h3 className="font-bold text-base text-slate-800 dark:text-white">
                        {customer.name}
                      </h3>
                      <div className="text-[11px] text-slate-400 flex items-center gap-1 mt-0.5">
                        <Phone className="w-3 h-3" />
                        <span>{toPersianDigits(customer.mobile || customer.phone || '---')}</span>
                      </div>
                    </div>

                    <div className="text-left">
                      {hasDebt ? (
                        <span className="px-2.5 py-1 rounded-full text-[11px] font-bold bg-rose-50 dark:bg-rose-900/30 text-rose-600 dark:text-rose-400 border border-rose-200 dark:border-rose-800 inline-block">
                          بدهکار: {formatCurrency(customer.balance)}
                        </span>
                      ) : (
                        <span className="px-2.5 py-1 rounded-full text-[11px] font-bold bg-emerald-50 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-800 inline-block">
                          تسویه کامل
                        </span>
                      )}
                    </div>
                  </div>

                  {/* Address & Notes */}
                  {customer.address && (
                    <div className="text-xs text-slate-500 dark:text-slate-400 flex items-start gap-1.5 bg-slate-50 dark:bg-slate-900/50 p-2.5 rounded-2xl">
                      <MapPin className="w-3.5 h-3.5 text-slate-400 shrink-0 mt-0.5" />
                      <span className="line-clamp-2">{customer.address}</span>
                    </div>
                  )}

                  {/* Customer Invoices count */}
                  <div className="text-[11px] text-slate-400 pt-1 border-t border-slate-100 dark:border-slate-700 flex justify-between items-center">
                    <span>تعداد فاکتورها: {toPersianDigits(customerInvoices.length)}</span>
                    <button
                      onClick={() => {
                        if (customerInvoices.length > 0) {
                          onViewInvoice(customerInvoices[0]);
                        } else {
                          alert('فاکتوری برای این مشتری ثبت نشده است.');
                        }
                      }}
                      className="text-blue-600 dark:text-blue-400 font-bold hover:underline"
                    >
                      مشاهده فاکتورها
                    </button>
                  </div>

                </div>

                {/* Actions */}
                <div className="pt-3 border-t border-slate-100 dark:border-slate-700 flex items-center justify-between gap-1">
                  {hasDebt && (
                    <>
                      <button
                        onClick={() => {
                          setPaymentCustomer(customer);
                          setPaymentAmount(customer.balance.toString());
                        }}
                        className="px-2.5 py-1.5 rounded-xl bg-emerald-50 dark:bg-emerald-900/30 text-emerald-600 dark:text-emerald-400 text-[11px] font-bold flex items-center gap-1 hover:bg-emerald-100 transition"
                      >
                        <CreditCard className="w-3.5 h-3.5" />
                        <span>ثبت دریافت</span>
                      </button>

                      <button
                        onClick={() => setReminderCustomer(customer)}
                        className="px-2.5 py-1.5 rounded-xl bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 text-[11px] font-bold flex items-center gap-1 hover:bg-blue-100 transition"
                      >
                        <Send className="w-3.5 h-3.5" />
                        <span>یادآوری بدهی</span>
                      </button>
                    </>
                  )}

                  <div className="flex items-center gap-1 mr-auto">
                    <button
                      onClick={() => openEditModal(customer)}
                      className="p-1.5 rounded-lg text-slate-400 hover:text-blue-600 hover:bg-slate-100 dark:hover:bg-slate-700 transition"
                      title="ویرایش"
                    >
                      <Edit className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => {
                        if (window.confirm(`آیا از حذف مشتری ${customer.name} اطمینان دارید؟`)) {
                          onDeleteCustomer(customer.id);
                        }
                      }}
                      className="p-1.5 rounded-lg text-slate-400 hover:text-rose-600 hover:bg-slate-100 dark:hover:bg-slate-700 transition"
                      title="حذف"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>

              </div>
            );
          })
        )}
      </div>

      {/* Add / Edit Customer Modal */}
      {showModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
          <div className="w-full max-w-lg bg-white dark:bg-slate-800 rounded-3xl p-6 shadow-2xl space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-slate-700">
              <h3 className="font-bold text-base text-slate-800 dark:text-white">
                {editingCustomer ? 'ویرایش اطلاعات مشتری' : 'افزودن مشتری جدید'}
              </h3>
              <button onClick={() => setShowModal(false)} className="p-1 text-slate-400">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSave} className="space-y-3 text-xs">
              <div>
                <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
                  نام و نام خانوادگی / شرکت *
                </label>
                <input
                  type="text"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="مثلا: رضا محمدی"
                  className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-medium"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
                    شماره همراه
                  </label>
                  <input
                    type="text"
                    value={mobile}
                    onChange={(e) => setMobile(e.target.value)}
                    placeholder="0912..."
                    className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-medium"
                  />
                </div>
                <div>
                  <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
                    تلفن ثابت
                  </label>
                  <input
                    type="text"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    placeholder="021..."
                    className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-medium"
                  />
                </div>
              </div>

              <div>
                <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
                  آدرس
                </label>
                <input
                  type="text"
                  value={address}
                  onChange={(e) => setAddress(e.target.value)}
                  placeholder="استان، شهر، خیابان..."
                  className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-medium"
                />
              </div>

              <div>
                <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
                  مانده بدهی اولیه (تومان)
                </label>
                <input
                  type="number"
                  value={balance}
                  onChange={(e) => setBalance(e.target.value)}
                  placeholder="0"
                  className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-bold"
                />
              </div>

              <div>
                <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
                  توضیحات
                </label>
                <textarea
                  rows="2"
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="یادداشت‌های مربوط به مشتری..."
                  className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-medium"
                />
              </div>

              <div className="flex gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  className="flex-1 py-3 rounded-2xl border border-slate-200 dark:border-slate-700 font-bold"
                >
                  انصراف
                </button>
                <button
                  type="submit"
                  className="flex-1 py-3 rounded-2xl bg-emerald-600 text-white font-bold shadow-md shadow-emerald-500/20"
                >
                  ذخیره اطلاعات
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Record Payment Modal */}
      {paymentCustomer && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
          <div className="w-full max-w-md bg-white dark:bg-slate-800 rounded-3xl p-6 shadow-2xl space-y-4">
            <h3 className="font-bold text-base text-slate-800 dark:text-white">
              ثبت دریافت وجه از {paymentCustomer.name}
            </h3>

            <p className="text-xs text-slate-500">
              مانده بدهی فعلی: <span className="font-bold text-rose-600">{formatCurrency(paymentCustomer.balance)}</span>
            </p>

            <input
              type="number"
              value={paymentAmount}
              onChange={(e) => setPaymentAmount(e.target.value)}
              placeholder="مبلغ پرداختی مشتری به تومان"
              className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 font-bold text-sm"
            />

            <div className="flex gap-2">
              <button
                onClick={() => setPaymentCustomer(null)}
                className="flex-1 py-2.5 rounded-xl border border-slate-200 text-xs font-bold"
              >
                انصراف
              </button>
              <button
                onClick={handlePaymentSubmit}
                className="flex-1 py-2.5 rounded-xl bg-emerald-600 text-white font-bold text-xs shadow"
              >
                ثبت و کسر از بدهی
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Debt Reminder Modal */}
      {reminderCustomer && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
          <div className="w-full max-w-md bg-white dark:bg-slate-800 rounded-3xl p-6 shadow-2xl space-y-4">
            <div className="flex items-center justify-between pb-2 border-b border-slate-100 dark:border-slate-700">
              <h3 className="font-bold text-base text-slate-800 dark:text-white">
                ارسال یادآوری بدهی
              </h3>
              <button onClick={() => setReminderCustomer(null)} className="p-1 text-slate-400">
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="p-4 bg-slate-50 dark:bg-slate-900/80 rounded-2xl border border-slate-200 dark:border-slate-700 text-xs space-y-2">
              <p className="font-bold text-slate-800 dark:text-white">
                متن پیش‌فرض پیامک / واتساپ:
              </p>
              <div className="p-3 bg-white dark:bg-slate-800 rounded-xl border border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-300 leading-relaxed font-sans">
                جناب آقای/خانم {reminderCustomer.name} محترم، سلام.<br />
                احتراماً مانده حساب شما در {business?.shopName || 'فروشگاه روبی'} مبلغ {formatCurrency(reminderCustomer.balance)} می‌باشد. خواهشمند است جهت تسویه حساب اقدام فرمایید. با تشکر.
              </div>
            </div>

            <div className="flex gap-2">
              <button
                onClick={() => {
                  navigator.clipboard.writeText(
                    `جناب آقای/خانم ${reminderCustomer.name} محترم، سلام. احتراماً مانده حساب شما در ${business?.shopName || 'فروشگاه روبی'} مبلغ ${formatCurrency(reminderCustomer.balance)} می‌باشد. خواهشمند است جهت تسویه حساب اقدام فرمایید. با تشکر.`
                  );
                  alert('متن یادآوری بدهی با موفقیت کپی شد.');
                }}
                className="flex-1 py-3 rounded-2xl bg-blue-600 text-white font-bold text-xs shadow flex items-center justify-center gap-1"
              >
                <Send className="w-4 h-4" />
                <span>کپی متن پیامک</span>
              </button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
}
