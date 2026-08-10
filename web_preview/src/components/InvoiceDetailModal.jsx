import React, { useState } from 'react';
import {
  X,
  Printer,
  Share2,
  Copy,
  Trash2,
  Edit,
  ArrowRightLeft,
  CheckCircle,
  CreditCard,
  QrCode,
  Download,
  AlertCircle
} from 'lucide-react';
import { formatCurrency, toPersianDigits } from '../utils/helpers';

export default function InvoiceDetailModal({
  invoice,
  business,
  isOpen,
  onClose,
  onEdit,
  onCopy,
  onDelete,
  onConvertProforma,
  onRecordPayment
}) {
  if (!isOpen || !invoice) return null;

  const [paymentAmountInput, setPaymentAmountInput] = useState('');
  const [showPaymentModal, setShowPaymentModal] = useState(false);

  const handlePrint = () => {
    window.print();
  };

  const handleShare = () => {
    if (navigator.share) {
      navigator.share({
        title: `فاکتور شماره ${invoice.number} - ${business?.shopName || 'روبی'}`,
        text: `فاکتور شماره ${invoice.number} برای ${invoice.customerName} به مبلغ ${formatCurrency(invoice.totalAmount)} صادر شد.`,
        url: window.location.href
      }).catch(() => {});
    } else {
      navigator.clipboard.writeText(`فاکتور شماره ${invoice.number} - مبلغ: ${formatCurrency(invoice.totalAmount)}`);
      alert('متن فاکتور در حافظه کپی شد!');
    }
  };

  const handlePaymentSubmit = () => {
    const amt = parseFloat(paymentAmountInput);
    if (!amt || amt <= 0) {
      alert('لطفاً مبلغ دریافتی معتبری وارد کنید.');
      return;
    }
    onRecordPayment(invoice.id, amt);
    setShowPaymentModal(false);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-6 bg-slate-900/60 backdrop-blur-sm overflow-y-auto">
      <div className="w-full max-w-3xl bg-white dark:bg-slate-800 rounded-3xl shadow-2xl overflow-hidden flex flex-col my-auto border border-slate-200 dark:border-slate-700">
        
        {/* Top Action Bar (No Print) */}
        <div className="p-4 bg-slate-100 dark:bg-slate-900 border-b border-slate-200 dark:border-slate-700 flex items-center justify-between no-print">
          <div className="flex items-center gap-2">
            <span className="font-bold text-sm text-slate-800 dark:text-white">
              مشاهده فاکتور #{toPersianDigits(invoice.number)}
            </span>
            {invoice.type === 'proforma' && (
              <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-100 text-amber-700">
                پیش‌فاکتور
              </span>
            )}
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={handlePrint}
              className="p-2 rounded-xl bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 hover:bg-blue-50 dark:hover:bg-blue-900/30 font-medium text-xs flex items-center gap-1 shadow-sm transition"
              title="چاپ و خروجی PDF"
            >
              <Printer className="w-4 h-4 text-blue-600" />
              <span className="hidden sm:inline">چاپ / PDF</span>
            </button>

            <button
              onClick={handleShare}
              className="p-2 rounded-xl bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-200 hover:bg-emerald-50 font-medium text-xs flex items-center gap-1 shadow-sm transition"
              title="اشتراک‌گذاری"
            >
              <Share2 className="w-4 h-4 text-emerald-600" />
              <span className="hidden sm:inline">اشتراک</span>
            </button>

            <button
              onClick={onClose}
              className="p-2 rounded-xl bg-slate-200 dark:bg-slate-700 text-slate-600 dark:text-slate-300 hover:bg-slate-300 transition"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Printable Invoice Container */}
        <div id="printable-invoice" className="p-6 sm:p-8 bg-white text-slate-900 font-vazir space-y-6">
          
          {/* Header with Business & Logo */}
          <div className="flex items-start justify-between border-b-2 border-slate-200 pb-6 gap-4">
            <div>
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-2xl bg-blue-600 text-white font-black text-2xl flex items-center justify-center shadow">
                  ف
                </div>
                <div>
                  <h1 className="font-black text-2xl text-slate-900">
                    {business?.shopName || 'فروشگاه روبی'}
                  </h1>
                  <p className="text-xs text-slate-500 font-medium mt-0.5">
                    {business?.phone ? `تلفن: ${business.phone}` : ''}
                  </p>
                </div>
              </div>
              {business?.address && (
                <p className="text-xs text-slate-600 mt-2 max-w-md">
                  آدرس: {business.address}
                </p>
              )}
            </div>

            <div className="text-left bg-slate-50 p-4 rounded-2xl border border-slate-200 text-xs space-y-1">
              <div className="text-lg font-black text-blue-700">
                {invoice.type === 'proforma' ? 'پیش‌فاکتور فروش' : 'فاکتور فروش'}
              </div>
              <div>شماره: <span className="font-bold">{toPersianDigits(invoice.number)}</span></div>
              <div>تاریخ: <span className="font-bold">{toPersianDigits(invoice.date)}</span></div>
            </div>
          </div>

          {/* Customer Info Box */}
          <div className="bg-slate-50 p-4 rounded-2xl border border-slate-200 flex flex-col sm:flex-row justify-between gap-2 text-xs">
            <div>
              <span className="text-slate-400 font-medium">خریدار:</span>{' '}
              <span className="font-bold text-slate-900 text-sm">{invoice.customerName}</span>
            </div>
            <div>
              <span className="text-slate-400 font-medium">شماره تماس:</span>{' '}
              <span className="font-bold text-slate-800">{toPersianDigits(invoice.customerPhone || '---')}</span>
            </div>
          </div>

          {/* Items Table */}
          <div className="overflow-x-auto rounded-2xl border border-slate-200">
            <table className="w-full text-right text-xs">
              <thead className="bg-slate-100 text-slate-700 font-bold border-b border-slate-200">
                <tr>
                  <th className="p-3 text-center w-12">#</th>
                  <th className="p-3">عنوان کالا / خدمت</th>
                  <th className="p-3 text-center">مقدار</th>
                  <th className="p-3 text-center">واحد</th>
                  <th className="p-3 text-center">قیمت واحد</th>
                  <th className="p-3 text-left">قیمت کل</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200">
                {invoice.items.map((item, idx) => (
                  <tr key={idx} className="hover:bg-slate-50">
                    <td className="p-3 text-center font-bold text-slate-400">{toPersianDigits(idx + 1)}</td>
                    <td className="p-3 font-bold text-slate-800">{item.title}</td>
                    <td className="p-3 text-center font-bold">{toPersianDigits(item.quantity)}</td>
                    <td className="p-3 text-center text-slate-500">{item.unit}</td>
                    <td className="p-3 text-center font-medium">{formatCurrency(item.unitPrice)}</td>
                    <td className="p-3 text-left font-bold text-slate-900">{formatCurrency(item.totalPrice)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Bottom Grid: Notes & Card on Right, Calculation Summary on Left */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6 items-start pt-2">
            
            {/* Notes & Bank Card & QR */}
            <div className="space-y-4 text-xs">
              {invoice.notes && (
                <div className="p-3.5 bg-slate-50 rounded-2xl border border-slate-200">
                  <div className="font-bold text-slate-700 mb-1">توضیحات:</div>
                  <p className="text-slate-600 leading-relaxed">{invoice.notes}</p>
                </div>
              )}

              {invoice.cardNumber && (
                <div className="p-3.5 bg-blue-50/60 rounded-2xl border border-blue-200 flex items-center gap-3">
                  <CreditCard className="w-5 h-5 text-blue-600 shrink-0" />
                  <div>
                    <div className="text-[10px] text-blue-600 font-bold">شماره کارت بانکی جهت واریز:</div>
                    <div className="font-mono font-bold text-sm text-slate-900 dir-ltr">{invoice.cardNumber}</div>
                  </div>
                </div>
              )}

              <div className="flex items-center gap-3 p-3 border border-dashed border-slate-300 rounded-2xl bg-slate-50">
                <div className="w-12 h-12 bg-white p-1 rounded-lg border border-slate-200 flex items-center justify-center shrink-0">
                  <QrCode className="w-10 h-10 text-slate-800" />
                </div>
                <div className="text-[11px] text-slate-500">
                  صحت این فاکتور از طریق اسکن کیوآرکد و سامانه فاکتور ساز روبی قابل استعلام است.
                </div>
              </div>
            </div>

            {/* Calculations Card */}
            <div className="bg-slate-50 p-4 rounded-2xl border border-slate-200 text-xs space-y-2">
              <div className="flex justify-between text-slate-600">
                <span>جمع کل اقلام:</span>
                <span className="font-bold">{formatCurrency(invoice.subtotal)}</span>
              </div>

              {invoice.discountAmount > 0 && (
                <div className="flex justify-between text-emerald-600 font-medium">
                  <span>تخفیف:</span>
                  <span>- {formatCurrency(invoice.discountAmount)}</span>
                </div>
              )}

              {invoice.shippingFee > 0 && (
                <div className="flex justify-between text-slate-600">
                  <span>هزینه ارسال:</span>
                  <span>+ {formatCurrency(invoice.shippingFee)}</span>
                </div>
              )}

              {invoice.previousDebt > 0 && (
                <div className="flex justify-between text-rose-600">
                  <span>بدهی قبلی:</span>
                  <span>+ {formatCurrency(invoice.previousDebt)}</span>
                </div>
              )}

              <div className="flex justify-between text-sm font-black text-slate-900 pt-2 border-t border-slate-300">
                <span>مبلغ قابل پرداخت:</span>
                <span className="text-base text-blue-700">{formatCurrency(invoice.totalAmount)}</span>
              </div>

              <div className="flex justify-between text-slate-600 pt-1">
                <span>مبلغ پرداخت شده:</span>
                <span className="font-bold text-emerald-600">{formatCurrency(invoice.paidAmount)}</span>
              </div>

              {invoice.remainingAmount > 0 && (
                <div className="flex justify-between font-bold text-rose-600 pt-1 border-t border-dashed border-slate-300">
                  <span>باقی‌مانده بدهی:</span>
                  <span>{formatCurrency(invoice.remainingAmount)}</span>
                </div>
              )}
            </div>

          </div>

          {/* Footer Signature */}
          <div className="pt-6 border-t border-slate-200 flex items-center justify-between text-[11px] text-slate-400">
            <div>مهر و امضای فروشنده</div>
            <div>امضای خریدار</div>
          </div>

        </div>

        {/* Footer Smart Actions (No Print) */}
        <div className="p-4 bg-slate-50 dark:bg-slate-900 border-t border-slate-200 dark:border-slate-700 flex flex-wrap items-center justify-between gap-2 no-print">
          
          <div className="flex items-center gap-2">
            {invoice.type === 'proforma' && (
              <button
                onClick={() => onConvertProforma(invoice.id)}
                className="px-3 py-2 rounded-xl bg-amber-500 hover:bg-amber-600 text-white font-bold text-xs flex items-center gap-1 shadow transition"
              >
                <ArrowRightLeft className="w-4 h-4" />
                <span>تبدیل به فاکتور فروش</span>
              </button>
            )}

            {invoice.remainingAmount > 0 && (
              <button
                onClick={() => setShowPaymentModal(true)}
                className="px-3 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white font-bold text-xs flex items-center gap-1 shadow transition"
              >
                <CreditCard className="w-4 h-4" />
                <span>ثبت دریافت / تسویه</span>
              </button>
            )}

            <button
              onClick={() => onCopy(invoice)}
              className="px-3 py-2 rounded-xl bg-slate-200 dark:bg-slate-700 hover:bg-slate-300 text-slate-700 dark:text-slate-200 font-bold text-xs flex items-center gap-1 transition"
            >
              <Copy className="w-4 h-4" />
              <span>کپی فاکتور</span>
            </button>
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={() => onEdit(invoice)}
              className="px-3 py-2 rounded-xl bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 font-bold text-xs flex items-center gap-1 transition"
            >
              <Edit className="w-4 h-4" />
              <span>ویرایش</span>
            </button>

            <button
              onClick={() => {
                if (window.confirm('آیا از حذف این فاکتور اطمینان دارید؟')) {
                  onDelete(invoice.id);
                  onClose();
                }
              }}
              className="px-3 py-2 rounded-xl bg-rose-50 dark:bg-rose-900/30 text-rose-600 dark:text-rose-400 font-bold text-xs flex items-center gap-1 transition"
            >
              <Trash2 className="w-4 h-4" />
              <span>حذف</span>
            </button>
          </div>

        </div>

      </div>

      {/* Record Payment Sub-Modal */}
      {showPaymentModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
          <div className="w-full max-w-md bg-white dark:bg-slate-800 rounded-3xl p-6 shadow-2xl space-y-4">
            <h3 className="font-bold text-base text-slate-800 dark:text-white">
              ثبت دریافت وجه برای فاکتور #{toPersianDigits(invoice.number)}
            </h3>
            
            <p className="text-xs text-slate-500">
              مانده فعلی این فاکتور: <span className="font-bold text-rose-600">{formatCurrency(invoice.remainingAmount)}</span>
            </p>

            <input
              type="number"
              placeholder="مبلغ دریافتی به تومان"
              value={paymentAmountInput}
              onChange={(e) => setPaymentAmountInput(e.target.value)}
              className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 font-bold text-sm"
            />

            <div className="flex gap-2">
              <button
                onClick={() => setShowPaymentModal(false)}
                className="flex-1 py-2.5 rounded-xl border border-slate-200 dark:border-slate-700 text-xs font-bold"
              >
                انصراف
              </button>
              <button
                onClick={handlePaymentSubmit}
                className="flex-1 py-2.5 rounded-xl bg-emerald-600 text-white font-bold text-xs shadow"
              >
                ثبت پرداخت
              </button>
            </div>
          </div>
        </div>
      )}

    </div>
  );
}
