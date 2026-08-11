import React, { useState, useRef } from 'react';
import {
  X,
  Printer,
  Share2,
  Copy,
  Trash2,
  Edit,
  ArrowRightLeft,
  CreditCard,
  Image as ImageIcon,
  FileText,
  MessageSquare
} from 'lucide-react';
import html2canvas from 'html2canvas';
import { formatCurrency, toPersianDigits } from '../utils/helpers';

export default function InvoiceDetailModal({
  invoice,
  business,
  settings,
  isOpen,
  onClose,
  onEdit,
  onCopy,
  onDelete,
  onConvertProforma,
  onRecordPayment
}) {
  if (!isOpen || !invoice) return null;

  const printRef = useRef(null);
  const [paymentAmountInput, setPaymentAmountInput] = useState('');
  const [showPaymentModal, setShowPaymentModal] = useState(false);
  const [showShareMenu, setShowShareMenu] = useState(false);
  const [busy, setBusy] = useState('');

  const typeTitle =
    invoice.type === 'proforma'
      ? 'پیش‌فاکتور'
      : invoice.type === 'purchase'
        ? 'فاکتور خرید'
        : 'فاکتور فروش';

  const shareText = () => {
    const lines = [
      `${typeTitle} #${invoice.number}`,
      `فروشگاه: ${business?.shopName || 'روبی'}`,
      `مشتری: ${invoice.customerName}`,
      invoice.customerPhone ? `موبایل: ${invoice.customerPhone}` : '',
      `تاریخ: ${invoice.date}`,
      `مبلغ: ${formatCurrency(invoice.totalAmount)}`,
      invoice.notes ? `توضیحات: ${invoice.notes}` : '',
      '',
      '— فاکتور ساز روبی'
    ].filter(Boolean);
    return lines.join('\n');
  };

  const handlePrintPdf = () => {
    setShowShareMenu(false);
    // کمی تاخیر تا منو بسته شود
    setTimeout(() => window.print(), 80);
  };

  const captureInvoiceCanvas = async () => {
    const el = printRef.current || document.getElementById('printable-invoice');
    if (!el) throw new Error('عنصر فاکتور یافت نشد');
    return html2canvas(el, {
      scale: 2,
      useCORS: true,
      backgroundColor: '#ffffff',
      logging: false
    });
  };

  const handleShareImage = async () => {
    setBusy('image');
    try {
      const canvas = await captureInvoiceCanvas();
      const blob = await new Promise((resolve) => canvas.toBlob(resolve, 'image/png'));
      if (!blob) throw new Error('ساخت تصویر ناموفق بود');

      const file = new File([blob], `factor-${invoice.number}.png`, { type: 'image/png' });

      if (navigator.canShare && navigator.canShare({ files: [file] })) {
        await navigator.share({
          files: [file],
          title: `${typeTitle} ${invoice.number}`,
          text: shareText()
        });
      } else if (navigator.share) {
        // fallback: data url download + share text
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `factor-${invoice.number}.png`;
        a.click();
        URL.revokeObjectURL(url);
        await navigator.share({ title: `${typeTitle} ${invoice.number}`, text: shareText() });
      } else {
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `factor-${invoice.number}.png`;
        a.click();
        URL.revokeObjectURL(url);
        alert('تصویر فاکتور دانلود شد.');
      }
      setShowShareMenu(false);
    } catch (err) {
      if (err?.name !== 'AbortError') {
        console.error(err);
        alert('اشتراک تصویر انجام نشد. دوباره تلاش کنید.');
      }
    } finally {
      setBusy('');
    }
  };

  const handleSharePdf = async () => {
    setShowShareMenu(false);
    // در مرورگر: دیالوگ چاپ → ذخیره به‌صورت PDF
    setTimeout(() => window.print(), 80);
  };

  const handleShareText = async () => {
    setBusy('text');
    try {
      const text = shareText();
      if (navigator.share) {
        await navigator.share({
          title: `${typeTitle} ${invoice.number}`,
          text
        });
      } else {
        await navigator.clipboard.writeText(text);
        alert('متن فاکتور در حافظه کپی شد.');
      }
      setShowShareMenu(false);
    } catch (err) {
      if (err?.name !== 'AbortError') {
        try {
          await navigator.clipboard.writeText(shareText());
          alert('متن فاکتور در حافظه کپی شد.');
        } catch {
          alert('اشتراک متن ممکن نشد.');
        }
      }
    } finally {
      setBusy('');
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
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center sm:p-4 bg-slate-900/60 backdrop-blur-sm overflow-y-auto">
      <div className="w-full max-w-lg sm:max-w-2xl bg-[#F8FAFC] dark:bg-slate-900 sm:rounded-3xl shadow-2xl overflow-hidden flex flex-col min-h-[100dvh] sm:min-h-0 sm:max-h-[92vh] border border-slate-200 dark:border-slate-700">
        {/* Top bar */}
        <div className="sticky top-0 z-20 p-3 sm:p-4 bg-white dark:bg-slate-800 border-b border-slate-200 dark:border-slate-700 flex items-center justify-between no-print">
          <button
            onClick={onClose}
            className="p-2 rounded-xl bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-200"
            title="بستن"
          >
            <X className="w-5 h-5" />
          </button>

          <div className="text-center">
            <div className="font-black text-sm text-slate-800 dark:text-white">
              {typeTitle} #{toPersianDigits(invoice.number)}
            </div>
            <div className="text-[10px] text-emerald-600 font-bold">ذخیره شد ✓</div>
          </div>

          <button
            onClick={() => setShowShareMenu(true)}
            className="p-2 rounded-xl bg-[#F97316] text-white shadow-sm"
            title="اشتراک‌گذاری"
          >
            <Share2 className="w-5 h-5" />
          </button>
        </div>

        {/* Scrollable invoice body */}
        <div className="flex-1 overflow-y-auto p-3 sm:p-5">
          <div
            ref={printRef}
            id="printable-invoice"
            className="bg-white text-slate-900 font-vazir rounded-2xl border border-slate-200 shadow-sm p-5 sm:p-6 space-y-5"
            dir="rtl"
          >
            {/* Header */}
            <div className="flex items-start justify-between gap-3 border-b border-slate-200 pb-4">
              <div className="flex items-center gap-3 min-w-0">
                <div className="w-12 h-12 rounded-2xl bg-[#F97316] text-white font-black text-xl flex items-center justify-center shadow shrink-0">
                  ف
                </div>
                <div className="min-w-0">
                  <h1 className="font-black text-lg text-slate-900 truncate">
                    {business?.shopName || 'فروشگاه روبی'}
                  </h1>
                  {business?.phone && (
                    <p className="text-[11px] text-slate-500 mt-0.5" dir="ltr" style={{ textAlign: 'right' }}>
                      {business.phone}
                    </p>
                  )}
                  {business?.address && (
                    <p className="text-[11px] text-slate-500 mt-1 leading-relaxed">{business.address}</p>
                  )}
                </div>
              </div>
              <div className="text-left shrink-0 bg-slate-50 rounded-xl border border-slate-200 px-3 py-2 text-[11px] space-y-0.5">
                <div className="font-black text-[#F97316] text-sm">{typeTitle}</div>
                <div>
                  شماره: <b>{toPersianDigits(invoice.number)}</b>
                </div>
                <div>
                  تاریخ: <b>{toPersianDigits(invoice.date)}</b>
                </div>
              </div>
            </div>

            {/* Customer */}
            <div className="bg-slate-50 rounded-xl border border-slate-200 p-3 flex flex-wrap justify-between gap-2 text-xs">
              <div>
                <span className="text-slate-400">خریدار: </span>
                <span className="font-bold text-sm">{invoice.customerName}</span>
              </div>
              <div>
                <span className="text-slate-400">موبایل: </span>
                <span className="font-bold" dir="ltr">
                  {toPersianDigits(invoice.customerPhone || '—')}
                </span>
              </div>
            </div>

            {/* Items */}
            <div className="overflow-x-auto rounded-xl border border-slate-200">
              <table className="w-full text-right text-[11px]" dir="rtl">
                <thead className="bg-slate-100 text-slate-700 font-bold">
                  <tr>
                    <th className="p-2.5 text-center w-8">#</th>
                    <th className="p-2.5">عنوان</th>
                    <th className="p-2.5 text-center">مقدار</th>
                    <th className="p-2.5 text-center">واحد</th>
                    <th className="p-2.5 text-center">قیمت واحد</th>
                    <th className="p-2.5 text-left">قیمت کل</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {(invoice.items || []).map((item, idx) => (
                    <tr key={idx}>
                      <td className="p-2.5 text-center text-slate-400 font-bold">
                        {toPersianDigits(idx + 1)}
                      </td>
                      <td className="p-2.5 font-bold text-slate-800">{item.title}</td>
                      <td className="p-2.5 text-center font-bold">
                        {toPersianDigits(item.quantity)}
                      </td>
                      <td className="p-2.5 text-center text-slate-500">{item.unit}</td>
                      <td className="p-2.5 text-center">{formatCurrency(item.unitPrice)}</td>
                      <td className="p-2.5 text-left font-bold">{formatCurrency(item.totalPrice)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* Totals */}
            <div className="space-y-1.5 text-xs bg-slate-50 rounded-xl border border-slate-200 p-3">
              <div className="flex justify-between text-slate-600">
                <span>جمع اقلام</span>
                <span className="font-bold">{formatCurrency(invoice.subtotal)}</span>
              </div>
              {invoice.discountAmount > 0 && (
                <div className="flex justify-between text-emerald-600">
                  <span>
                    تخفیف
                    {invoice.discountPercent > 0
                      ? ` (${toPersianDigits(invoice.discountPercent)}٪)`
                      : ''}
                  </span>
                  <span className="font-bold">− {formatCurrency(invoice.discountAmount)}</span>
                </div>
              )}
              {invoice.shippingFee > 0 && (
                <div className="flex justify-between text-slate-600">
                  <span>هزینه ارسال</span>
                  <span className="font-bold">+ {formatCurrency(invoice.shippingFee)}</span>
                </div>
              )}
              {invoice.previousDebt > 0 && (
                <div className="flex justify-between text-rose-600">
                  <span>بدهی قبلی</span>
                  <span className="font-bold">+ {formatCurrency(invoice.previousDebt)}</span>
                </div>
              )}
              {invoice.deposit > 0 && (
                <div className="flex justify-between text-sky-600">
                  <span>بیعانه</span>
                  <span className="font-bold">− {formatCurrency(invoice.deposit)}</span>
                </div>
              )}
              <div className="flex justify-between text-sm font-black text-slate-900 pt-2 border-t border-slate-200">
                <span>مبلغ قابل پرداخت</span>
                <span className="text-[#F97316]">{formatCurrency(invoice.totalAmount)}</span>
              </div>
              {invoice.paidAmount > 0 && invoice.paymentType !== 'cash' && (
                <div className="flex justify-between text-emerald-600">
                  <span>پرداخت‌شده / بیعانه</span>
                  <span className="font-bold">{formatCurrency(invoice.paidAmount)}</span>
                </div>
              )}
              {invoice.remainingAmount > 0 && (
                <div className="flex justify-between text-rose-600 font-bold">
                  <span>باقی‌مانده</span>
                  <span>{formatCurrency(invoice.remainingAmount)}</span>
                </div>
              )}
            </div>

            {invoice.notes && (
              <div className="text-xs text-slate-600 bg-amber-50/60 border border-amber-100 rounded-xl p-3">
                <span className="font-bold text-slate-700">توضیحات: </span>
                {invoice.notes}
              </div>
            )}

            {invoice.cardNumber && (
              <div className="p-3 bg-sky-50 rounded-xl border border-sky-100 flex items-center gap-3 text-xs">
                <CreditCard className="w-5 h-5 text-sky-600 shrink-0" />
                <div>
                  <div className="text-[10px] text-sky-600 font-bold">شماره کارت جهت واریز</div>
                  <div className="font-mono font-bold text-base text-slate-900 tracking-wider" dir="ltr" style={{textAlign:'right', direction:'ltr'}}>
                    {toPersianDigits(String(invoice.cardNumber||'').replace(/\D/g,'').replace(/(.{4})/g,'$1 ').trim())}
                  </div>
                  {(invoice.cardBank || invoice.cardOwner) && (
                    <div className="text-[11px] text-slate-600 font-bold mt-1">
                      {[invoice.cardBank, invoice.cardOwner].filter(Boolean).join(' · ')}
                    </div>
                  )}
                </div>
              </div>
            )}

            {/* مهر و امضا */}
            <div className="grid grid-cols-3 gap-3 pt-2 border-t border-slate-100">
              <div className="flex flex-col items-center gap-1.5 min-h-[88px] justify-end">
                {settings?.showStamp !== false && business?.stampDataUrl ? (
                  <img
                    src={business.stampDataUrl}
                    alt="مهر"
                    className="h-[72px] w-auto max-w-full object-contain"
                  />
                ) : (
                  <div className="h-12" />
                )}
                <span className="text-[10px] text-slate-400">مهر فروشنده</span>
              </div>
              <div className="flex flex-col items-center gap-1.5 min-h-[88px] justify-end">
                {settings?.showSignature !== false && business?.signatureDataUrl ? (
                  <img
                    src={business.signatureDataUrl}
                    alt="امضا"
                    className="h-14 w-auto max-w-full object-contain"
                  />
                ) : (
                  <div className="h-12" />
                )}
                <span className="text-[10px] text-slate-400">امضای فروشنده</span>
              </div>
              <div className="flex flex-col items-center gap-1.5 min-h-[88px] justify-end">
                <div className="h-12 border-b border-dashed border-slate-300 w-full max-w-[90px]" />
                <span className="text-[10px] text-slate-400">امضای خریدار</span>
              </div>
            </div>
            <div className="text-center pt-3 text-[11px] font-extrabold text-slate-400">
              اپلیکیشن فاکتور ساز روبی
            </div>
          </div>
        </div>

        {/* Bottom action buttons — PDF & Image */}
        <div className="sticky bottom-0 z-20 p-3 sm:p-4 bg-white dark:bg-slate-800 border-t border-slate-200 dark:border-slate-700 space-y-2 no-print">
          <div className="grid grid-cols-2 gap-2">
            <button
              type="button"
              onClick={handleShareImage}
              disabled={busy === 'image'}
              className="h-12 rounded-2xl bg-[#F97316] hover:bg-[#EA580C] text-white font-extrabold text-xs sm:text-sm flex items-center justify-center gap-2 shadow-md shadow-orange-500/20 active:scale-[0.98] transition disabled:opacity-60"
            >
              <ImageIcon className="w-5 h-5" />
              <span>{busy === 'image' ? 'در حال ساخت…' : 'ارسال عکس فاکتور'}</span>
            </button>
            <button
              type="button"
              onClick={handlePrintPdf}
              className="h-12 rounded-2xl bg-sky-500 hover:bg-sky-600 text-white font-extrabold text-xs sm:text-sm flex items-center justify-center gap-2 shadow-md shadow-sky-500/20 active:scale-[0.98] transition"
            >
              <FileText className="w-5 h-5" />
              <span>ارسال PDF</span>
            </button>
          </div>

          <button
            type="button"
            onClick={() => setShowShareMenu(true)}
            className="w-full h-11 rounded-2xl bg-slate-100 dark:bg-slate-700 hover:bg-slate-200 dark:hover:bg-slate-600 text-slate-800 dark:text-white font-bold text-xs flex items-center justify-center gap-2 transition"
          >
            <Share2 className="w-4 h-4" />
            <span>منوی اشتراک‌گذاری فاکتور</span>
          </button>

          <div className="flex flex-wrap items-center justify-between gap-2 pt-1">
            <div className="flex items-center gap-1.5 flex-wrap">
              {invoice.type === 'proforma' && onConvertProforma && (
                <button
                  onClick={() => onConvertProforma(invoice.id)}
                  className="px-2.5 py-1.5 rounded-xl bg-amber-100 text-amber-700 font-bold text-[11px] flex items-center gap-1"
                >
                  <ArrowRightLeft className="w-3.5 h-3.5" />
                  تبدیل به فروش
                </button>
              )}
              {invoice.remainingAmount > 0 && (
                <button
                  onClick={() => setShowPaymentModal(true)}
                  className="px-2.5 py-1.5 rounded-xl bg-emerald-100 text-emerald-700 font-bold text-[11px] flex items-center gap-1"
                >
                  <CreditCard className="w-3.5 h-3.5" />
                  ثبت دریافت
                </button>
              )}
              {onCopy && (
                <button
                  onClick={() => onCopy(invoice)}
                  className="px-2.5 py-1.5 rounded-xl bg-slate-100 dark:bg-slate-700 text-slate-600 dark:text-slate-200 font-bold text-[11px] flex items-center gap-1"
                >
                  <Copy className="w-3.5 h-3.5" />
                  کپی
                </button>
              )}
            </div>
            <div className="flex items-center gap-1.5">
              {onEdit && (
                <button
                  onClick={() => onEdit(invoice)}
                  className="px-2.5 py-1.5 rounded-xl bg-blue-50 text-blue-600 font-bold text-[11px] flex items-center gap-1"
                >
                  <Edit className="w-3.5 h-3.5" />
                  ویرایش
                </button>
              )}
              {onDelete && (
                <button
                  onClick={() => {
                    if (window.confirm('آیا از حذف این فاکتور اطمینان دارید؟')) {
                      onDelete(invoice.id);
                      onClose();
                    }
                  }}
                  className="px-2.5 py-1.5 rounded-xl bg-rose-50 text-rose-600 font-bold text-[11px] flex items-center gap-1"
                >
                  <Trash2 className="w-3.5 h-3.5" />
                  حذف
                </button>
              )}
            </div>
          </div>
        </div>
      </div>

      {/* Share menu sheet */}
      {showShareMenu && (
        <div
          className="fixed inset-0 z-[60] flex items-end sm:items-center justify-center bg-slate-900/50 backdrop-blur-sm p-0 sm:p-4 no-print"
          onClick={() => setShowShareMenu(false)}
        >
          <div
            className="w-full max-w-md bg-white dark:bg-slate-800 rounded-t-3xl sm:rounded-3xl p-5 shadow-2xl space-y-3 border border-slate-200 dark:border-slate-700"
            onClick={(e) => e.stopPropagation()}
            dir="rtl"
          >
            <div className="flex items-center justify-between pb-1">
              <h3 className="font-black text-base text-slate-800 dark:text-white">
                اشتراک‌گذاری فاکتور
              </h3>
              <button
                onClick={() => setShowShareMenu(false)}
                className="p-1.5 rounded-lg text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-700"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <p className="text-[11px] text-slate-500">
              فاکتور #{toPersianDigits(invoice.number)} · {formatCurrency(invoice.totalAmount)}
            </p>

            <button
              type="button"
              onClick={handleShareImage}
              disabled={!!busy}
              className="w-full p-4 rounded-2xl bg-orange-50 dark:bg-orange-900/20 border border-orange-100 dark:border-orange-800 flex items-center gap-3 hover:bg-orange-100 transition text-right"
            >
              <div className="w-11 h-11 rounded-xl bg-[#F97316] text-white flex items-center justify-center shrink-0">
                <ImageIcon className="w-5 h-5" />
              </div>
              <div className="flex-1 min-w-0">
                <div className="font-extrabold text-sm text-slate-800 dark:text-white">
                  {busy === 'image' ? 'در حال ساخت تصویر…' : 'ارسال عکس فاکتور'}
                </div>
                <div className="text-[11px] text-slate-500">اشتراک تصویر PNG از طریق واتساپ و…</div>
              </div>
            </button>

            <button
              type="button"
              onClick={handleSharePdf}
              className="w-full p-4 rounded-2xl bg-sky-50 dark:bg-sky-900/20 border border-sky-100 dark:border-sky-800 flex items-center gap-3 hover:bg-sky-100 transition text-right"
            >
              <div className="w-11 h-11 rounded-xl bg-sky-500 text-white flex items-center justify-center shrink-0">
                <Printer className="w-5 h-5" />
              </div>
              <div className="flex-1 min-w-0">
                <div className="font-extrabold text-sm text-slate-800 dark:text-white">ارسال PDF</div>
                <div className="text-[11px] text-slate-500">چاپ یا ذخیره به‌صورت PDF</div>
              </div>
            </button>

            <button
              type="button"
              onClick={handleShareText}
              disabled={!!busy}
              className="w-full p-4 rounded-2xl bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-700 flex items-center gap-3 hover:bg-slate-100 dark:hover:bg-slate-700/60 transition text-right"
            >
              <div className="w-11 h-11 rounded-xl bg-slate-700 text-white flex items-center justify-center shrink-0">
                <MessageSquare className="w-5 h-5" />
              </div>
              <div className="flex-1 min-w-0">
                <div className="font-extrabold text-sm text-slate-800 dark:text-white">
                  اشتراک متن فاکتور
                </div>
                <div className="text-[11px] text-slate-500">ارسال خلاصه متنی یا کپی</div>
              </div>
            </button>

            <button
              type="button"
              onClick={() => setShowShareMenu(false)}
              className="w-full py-3 rounded-2xl text-slate-500 font-bold text-xs"
            >
              انصراف
            </button>
          </div>
        </div>
      )}

      {/* Payment sub-modal */}
      {showPaymentModal && (
        <div className="fixed inset-0 z-[60] flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm no-print">
          <div className="w-full max-w-md bg-white dark:bg-slate-800 rounded-3xl p-6 shadow-2xl space-y-4">
            <h3 className="font-bold text-base text-slate-800 dark:text-white">
              ثبت دریافت وجه برای فاکتور #{toPersianDigits(invoice.number)}
            </h3>
            <p className="text-xs text-slate-500">
              مانده فعلی:{' '}
              <span className="font-bold text-rose-600">
                {formatCurrency(invoice.remainingAmount)}
              </span>
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
