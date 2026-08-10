import React, { useState, useEffect } from 'react';
import {
  Plus,
  Trash2,
  Calendar,
  User,
  Phone,
  FileText,
  Share2,
  Package,
  X,
  Search,
  ChevronLeft,
  Menu,
  Check
} from 'lucide-react';
import { UNITS, formatCurrency, getTodayJalali, toPersianDigits } from '../utils/helpers';

export default function InvoiceCreatorView({
  customers,
  products,
  business,
  editingInvoice,
  onSaveInvoice,
  onCancel,
  onNewCustomerModal,
  tabs,
  activeTabId,
  onSelectTab,
  onAddTab,
  onOpenWindowsModal,
  onUpdateTabState
}) {
  // Form State
  const [number, setNumber] = useState(editingInvoice?.number || '۱');
  const [customerName, setCustomerName] = useState(editingInvoice?.customerName || '');
  const [customerPhone, setCustomerPhone] = useState(editingInvoice?.customerPhone || '');
  const [date, setDate] = useState(editingInvoice?.date || getTodayJalali());

  const [type, setType] = useState(editingInvoice?.type || 'proforma'); // sale, purchase, proforma
  const [paymentType, setPaymentType] = useState(editingInvoice?.paymentType || 'non_cash'); // cash, non_cash

  const [items, setItems] = useState(editingInvoice?.items || [
    { id: '1', title: '- ۱', quantity: 1, unit: 'عدد', unitPrice: 0, totalPrice: 0 }
  ]);

  const [hasDiscount, setHasDiscount] = useState(Boolean(editingInvoice?.discountAmount));
  const [discountType, setDiscountType] = useState('fixed'); // percent, fixed
  const [discountValue, setDiscountValue] = useState(editingInvoice?.discountAmount || 0);

  const [hasShipping, setHasShipping] = useState(Boolean(editingInvoice?.shippingFee));
  const [shippingFee, setShippingFee] = useState(editingInvoice?.shippingFee || 0);

  const [hasDeposit, setHasDeposit] = useState(Boolean(editingInvoice?.deposit));
  const [deposit, setDeposit] = useState(editingInvoice?.deposit || 0);

  const [hasPreviousDebt, setHasPreviousDebt] = useState(Boolean(editingInvoice?.previousDebt));
  const [previousDebt, setPreviousDebt] = useState(editingInvoice?.previousDebt || 0);

  const [notes, setNotes] = useState(editingInvoice?.notes || '');
  const [cardNumber, setCardNumber] = useState(editingInvoice?.cardNumber || '');

  const [showCatalogModal, setShowCatalogModal] = useState(false);
  const [showCustomerModal, setShowCustomerModal] = useState(false);
  const [productSearch, setProductSearch] = useState('');

  useEffect(() => {
    if (onUpdateTabState) {
      onUpdateTabState({
        number,
        customerName,
        customerPhone,
        date,
        type,
        paymentType,
        items,
        discountAmount: discountValue,
        shippingFee,
        deposit,
        previousDebt,
        notes,
        cardNumber
      });
    }
  }, [number, customerName, customerPhone, date, type, paymentType, items, discountValue, shippingFee, deposit, previousDebt, notes, cardNumber]);

  // Item helpers
  const handleItemChange = (index, field, value) => {
    const updated = [...items];
    const item = { ...updated[index], [field]: value };

    if (field === 'quantity' || field === 'unitPrice') {
      const q = parseFloat(item.quantity) || 0;
      const p = parseFloat(item.unitPrice) || 0;
      item.totalPrice = q * p;
    }

    updated[index] = item;
    setItems(updated);
  };

  const addItemRow = () => {
    setItems([
      ...items,
      { id: Date.now().toString(), title: `- ${toPersianDigits(items.length + 1)}`, quantity: 1, unit: 'عدد', unitPrice: 0, totalPrice: 0 }
    ]);
  };

  const removeItemRow = (index) => {
    if (items.length === 1) return;
    setItems(items.filter((_, i) => i !== index));
  };

  const addFromCatalog = (product) => {
    setItems([
      ...items,
      {
        id: Date.now().toString(),
        title: product.name,
        quantity: 1,
        unit: product.unit || 'عدد',
        unitPrice: product.sellPrice || 0,
        totalPrice: product.sellPrice || 0
      }
    ]);
    setShowCatalogModal(false);
  };

  // Subtotal & Totals calculations
  const subtotal = items.reduce((sum, item) => sum + (parseFloat(item.totalPrice) || 0), 0);

  let discountAmount = 0;
  if (hasDiscount) {
    if (discountType === 'percent') {
      discountAmount = Math.round((subtotal * (parseFloat(discountValue) || 0)) / 100);
    } else {
      discountAmount = parseFloat(discountValue) || 0;
    }
  }

  const shipping = hasShipping ? (parseFloat(shippingFee) || 0) : 0;
  const prevDebt = hasPreviousDebt ? (parseFloat(previousDebt) || 0) : 0;
  const dep = hasDeposit ? (parseFloat(deposit) || 0) : 0;

  const totalAmount = Math.max(0, subtotal - discountAmount + shipping + prevDebt);

  // Handle Save
  const handleSave = () => {
    const newInvoice = {
      id: editingInvoice?.id || `inv-${Date.now()}`,
      number,
      customerId: '',
      customerName: customerName.trim() || 'مشتری عمومی',
      customerPhone,
      type,
      paymentType,
      status: type === 'proforma' ? 'proforma' : (paymentType === 'cash' ? 'paid' : 'unpaid'),
      date,
      items,
      subtotal,
      discountPercent: discountType === 'percent' ? parseFloat(discountValue) || 0 : 0,
      discountAmount,
      shippingFee: shipping,
      previousDebt: prevDebt,
      deposit: dep,
      totalAmount,
      paidAmount: paymentType === 'cash' ? totalAmount : dep,
      remainingAmount: paymentType === 'cash' ? 0 : Math.max(0, totalAmount - dep),
      notes,
      cardNumber,
      createdAt: date
    };

    onSaveInvoice(newInvoice, true);
  };

  return (
    <div className="space-y-4 max-w-xl mx-auto pb-24 animate-fade-in font-vazir">
      
      {/* Top Banner Button (Screenshot 2) */}
      <button
        onClick={() => alert('جهت افزودن سربرگ کسب‌وکار، نام و لوگو را در بخش تنظیمات وارد کنید.')}
        className="w-full py-3.5 px-4 bg-sky-500 hover:bg-sky-600 text-white font-bold text-xs rounded-2xl shadow-sm transition active:scale-98"
      >
        برای افزودن سربرگ کلیک کنید
      </button>

      {/* Customer & Date Metadata Card (Screenshot 2) */}
      <div className="bg-slate-100/90 dark:bg-slate-800 p-4 rounded-3xl space-y-3 text-xs border border-slate-200/60 dark:border-slate-700">
        <div className="flex items-center justify-between gap-2">
          <input
            type="text"
            value={customerName}
            onChange={(e) => setCustomerName(e.target.value)}
            placeholder="مثلا: رضا محمدی"
            className="flex-1 p-2 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 font-bold text-left dir-rtl text-xs"
          />
          <button
            type="button"
            onClick={() => setShowCustomerModal(true)}
            className="px-2.5 py-1.5 bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 font-bold text-[10px] rounded-xl border border-blue-200 dark:border-blue-800 shrink-0"
          >
            انتخاب مشتری
          </button>
          <span className="text-slate-600 dark:text-slate-300 font-bold shrink-0">:نام مشتری</span>
        </div>

        <div className="flex items-center justify-between gap-2">
          <input
            type="text"
            value={customerPhone}
            onChange={(e) => setCustomerPhone(e.target.value)}
            placeholder="0912..."
            className="flex-1 p-2 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 font-bold text-left dir-rtl text-xs"
          />
          <span className="text-slate-600 dark:text-slate-300 font-bold shrink-0">:شماره مشتری</span>
        </div>

        <div className="pt-2 border-t border-slate-200/60 dark:border-slate-700 flex items-center justify-between text-slate-600 dark:text-slate-300 text-xs">
          <div>
            تاریخ: <span className="font-bold">{toPersianDigits(date)}</span>
          </div>
          <div className="flex items-center gap-1">
            <input
              type="text"
              value={number}
              onChange={(e) => setNumber(e.target.value)}
              className="w-12 p-1 rounded-lg bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 font-bold text-center text-xs"
            />
            <span>:شماره فاکتور</span>
          </div>
        </div>
      </div>

      {/* Items Table Card (Screenshot 2 & 3) */}
      <div className="bg-white dark:bg-slate-800 rounded-3xl border border-slate-200 dark:border-slate-700 overflow-hidden shadow-xs">
        
        {/* Table Header */}
        <div className="grid grid-cols-12 bg-slate-50 dark:bg-slate-900/60 border-b border-slate-200 dark:border-slate-700 text-center font-bold text-[11px] text-slate-600 dark:text-slate-300 py-2.5">
          <div className="col-span-2">قیمت کل</div>
          <div className="col-span-3">قیمت واحد</div>
          <div className="col-span-2">واحد</div>
          <div className="col-span-2">مقدار</div>
          <div className="col-span-3">عنوان</div>
        </div>

        {/* Table Rows */}
        <div className="divide-y divide-slate-100 dark:divide-slate-700">
          {items.map((item, index) => (
            <div key={item.id} className="grid grid-cols-12 items-center text-center p-2 text-xs">
              
              {/* Line Total */}
              <div className="col-span-2 font-bold text-slate-800 dark:text-slate-200">
                {toPersianDigits(item.totalPrice)}
              </div>

              {/* Unit Price */}
              <div className="col-span-3">
                <input
                  type="number"
                  value={item.unitPrice || ''}
                  onChange={(e) => handleItemChange(index, 'unitPrice', e.target.value)}
                  placeholder="۰"
                  className="w-full p-1.5 rounded-xl border border-slate-200 dark:border-slate-700 text-center font-bold text-xs"
                />
              </div>

              {/* Unit */}
              <div className="col-span-2">
                <select
                  value={item.unit}
                  onChange={(e) => handleItemChange(index, 'unit', e.target.value)}
                  className="w-full p-1 rounded-xl border border-slate-200 dark:border-slate-700 text-center text-xs font-medium bg-white dark:bg-slate-900"
                >
                  {UNITS.map(u => (
                    <option key={u} value={u}>{u}</option>
                  ))}
                </select>
              </div>

              {/* Quantity */}
              <div className="col-span-2">
                <input
                  type="number"
                  value={item.quantity}
                  onChange={(e) => handleItemChange(index, 'quantity', e.target.value)}
                  className="w-full p-1.5 rounded-xl border border-slate-200 dark:border-slate-700 text-center font-bold text-xs"
                />
              </div>

              {/* Title */}
              <div className="col-span-3 flex items-center justify-end gap-1">
                <input
                  type="text"
                  value={item.title}
                  onChange={(e) => handleItemChange(index, 'title', e.target.value)}
                  placeholder="- ۱"
                  className="w-full p-1.5 rounded-xl border border-slate-200 dark:border-slate-700 text-right font-medium text-xs"
                />
                {items.length > 1 && (
                  <button
                    onClick={() => removeItemRow(index)}
                    className="text-rose-400 p-0.5 hover:text-rose-600"
                  >
                    <X className="w-3.5 h-3.5" />
                  </button>
                )}
              </div>

            </div>
          ))}
        </div>

        {/* Add Item Row Button (Screenshot 2) */}
        <div className="p-3 bg-slate-50/50 dark:bg-slate-900/30 text-center border-t border-slate-100 dark:border-slate-700 flex items-center justify-center gap-4">
          <button
            onClick={addItemRow}
            className="text-sky-600 dark:text-sky-400 font-bold text-xs hover:underline flex items-center gap-1"
          >
            <span>ایجاد سطر جدید</span>
            <Plus className="w-4 h-4" />
          </button>
          <span className="text-slate-300">|</span>
          <button
            onClick={() => setShowCatalogModal(true)}
            className="text-emerald-600 dark:text-emerald-400 font-bold text-xs hover:underline flex items-center gap-1"
          >
            <span>انتخاب از کاتالوگ کالا</span>
            <Package className="w-4 h-4" />
          </button>
        </div>

      </div>

      {/* Subtotal Line (Screenshot 2) */}
      <div className="flex items-center justify-between text-xs px-2 font-bold text-slate-700 dark:text-slate-300">
        <span>{formatCurrency(subtotal)}</span>
        <span>جمع آیتم‌ها</span>
      </div>

      {/* Adjustments Section (Screenshot 2 & 3) */}
      <div className="bg-slate-100/80 dark:bg-slate-800 p-4 rounded-3xl space-y-3 text-xs border border-slate-200/60 dark:border-slate-700">
        
        {/* Row 1: Shipping & Discount */}
        <div className="grid grid-cols-2 gap-3 items-center">
          
          {/* Shipping Fee */}
          <div className="flex items-center justify-end gap-2">
            {hasShipping && (
              <input
                type="number"
                value={shippingFee || ''}
                onChange={(e) => setShippingFee(e.target.value)}
                placeholder="مبلغ"
                className="w-20 p-1.5 rounded-xl border border-slate-200 text-center text-xs"
              />
            )}
            <label htmlFor="chk-ship" className="font-bold text-slate-700 dark:text-slate-300">
              :هزینه ارسال
            </label>
            <input
              type="checkbox"
              id="chk-ship"
              checked={hasShipping}
              onChange={(e) => setHasShipping(e.target.checked)}
              className="w-4 h-4 rounded text-blue-600"
            />
          </div>

          {/* Discount */}
          <div className="flex items-center justify-end gap-2">
            {hasDiscount && (
              <div className="flex items-center gap-1">
                <input
                  type="number"
                  value={discountValue || ''}
                  onChange={(e) => setDiscountValue(e.target.value)}
                  placeholder="مقدار"
                  className="w-16 p-1.5 rounded-xl border border-slate-200 text-center text-xs"
                />
                <button
                  type="button"
                  onClick={() => setDiscountType(discountType === 'percent' ? 'fixed' : 'percent')}
                  className="text-[10px] text-blue-600 font-bold underline"
                >
                  {discountType === 'percent' ? 'درصد' : 'مبلغ'}
                </button>
              </div>
            )}
            <label htmlFor="chk-disc" className="font-bold text-slate-700 dark:text-slate-300">
              :تخفیف
            </label>
            <input
              type="checkbox"
              id="chk-disc"
              checked={hasDiscount}
              onChange={(e) => setHasDiscount(e.target.checked)}
              className="w-4 h-4 rounded text-blue-600"
            />
          </div>

        </div>

        {/* Row 2: Deposit & Previous Debt */}
        <div className="grid grid-cols-2 gap-3 items-center pt-2 border-t border-slate-200/60 dark:border-slate-700">
          
          {/* Deposit */}
          <div className="flex items-center justify-end gap-2">
            {hasDeposit && (
              <input
                type="number"
                value={deposit || ''}
                onChange={(e) => setDeposit(e.target.value)}
                placeholder="مبلغ"
                className="w-20 p-1.5 rounded-xl border border-slate-200 text-center text-xs"
              />
            )}
            <label htmlFor="chk-dep" className="font-bold text-slate-700 dark:text-slate-300">
              :بیعانه
            </label>
            <input
              type="checkbox"
              id="chk-dep"
              checked={hasDeposit}
              onChange={(e) => setHasDeposit(e.target.checked)}
              className="w-4 h-4 rounded text-blue-600"
            />
          </div>

          {/* Previous Debt */}
          <div className="flex items-center justify-end gap-2">
            {hasPreviousDebt && (
              <input
                type="number"
                value={previousDebt || ''}
                onChange={(e) => setPreviousDebt(e.target.value)}
                placeholder="مبلغ"
                className="w-20 p-1.5 rounded-xl border border-slate-200 text-center text-xs"
              />
            )}
            <label htmlFor="chk-prev" className="font-bold text-slate-700 dark:text-slate-300">
              :بدهی قبلی
            </label>
            <input
              type="checkbox"
              id="chk-prev"
              checked={hasPreviousDebt}
              onChange={(e) => setHasPreviousDebt(e.target.checked)}
              className="w-4 h-4 rounded text-blue-600"
            />
          </div>

        </div>

      </div>

      {/* Factor Type & Payment Type Radios (Screenshot 2 & 3) */}
      <div className="bg-slate-100/80 dark:bg-slate-800 p-4 rounded-3xl space-y-3 text-xs border border-slate-200/60 dark:border-slate-700">
        
        {/* Factor Type */}
        <div className="flex items-center justify-end gap-3 flex-wrap">
          <label className="flex items-center gap-1.5 cursor-pointer">
            <span className="font-bold text-slate-700 dark:text-slate-300">فاکتور فروش</span>
            <input
              type="radio"
              name="radio-type"
              checked={type === 'sale'}
              onChange={() => setType('sale')}
              className="w-4 h-4 text-blue-600"
            />
          </label>

          <label className="flex items-center gap-1.5 cursor-pointer">
            <span className="font-bold text-slate-700 dark:text-slate-300">فاکتور خرید</span>
            <input
              type="radio"
              name="radio-type"
              checked={type === 'purchase'}
              onChange={() => setType('purchase')}
              className="w-4 h-4 text-blue-600"
            />
          </label>

          <label className="flex items-center gap-1.5 cursor-pointer">
            <span className="font-bold text-slate-700 dark:text-slate-300">پیش فاکتور</span>
            <input
              type="radio"
              name="radio-type"
              checked={type === 'proforma'}
              onChange={() => setType('proforma')}
              className="w-4 h-4 text-blue-600"
            />
          </label>

          <span className="font-bold text-slate-500 mr-2">:نوع فاکتور</span>
        </div>

        {/* Payment Type */}
        <div className="flex items-center justify-end gap-3 pt-2 border-t border-slate-200/60 dark:border-slate-700">
          <label className="flex items-center gap-1.5 cursor-pointer">
            <span className="font-bold text-slate-700 dark:text-slate-300">غیر نقدی</span>
            <input
              type="radio"
              name="radio-pay"
              checked={paymentType === 'non_cash'}
              onChange={() => setPaymentType('non_cash')}
              className="w-4 h-4 text-blue-600"
            />
          </label>

          <label className="flex items-center gap-1.5 cursor-pointer">
            <span className="font-bold text-slate-700 dark:text-slate-300">نقدی</span>
            <input
              type="radio"
              name="radio-pay"
              checked={paymentType === 'cash'}
              onChange={() => setPaymentType('cash')}
              className="w-4 h-4 text-blue-600"
            />
          </label>

          <span className="font-bold text-slate-500 mr-2">:نوع پرداخت</span>
        </div>

      </div>

      {/* Net Total Line (Screenshot 3) */}
      <div className="flex items-center justify-between text-sm px-2 font-black text-slate-800 dark:text-white">
        <span className="text-base text-blue-600 dark:text-blue-400">{formatCurrency(totalAmount)}</span>
        <span>جمع کل</span>
      </div>

      {/* Descriptions Box (Screenshot 3) */}
      <div className="bg-slate-100/80 dark:bg-slate-800 p-3 rounded-3xl border border-slate-200/60 dark:border-slate-700">
        <input
          type="text"
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="توضیحات"
          className="w-full p-2 bg-transparent text-right font-medium text-xs outline-none"
        />
      </div>

      {/* Add Bank Card Button (Screenshot 3) */}
      <button
        onClick={() => {
          const card = prompt('شماره کارت بانکی جدید جهت درج در فاکتور:');
          if (card) setCardNumber(card);
        }}
        className="w-full p-3.5 rounded-3xl bg-slate-100/80 dark:bg-slate-800 border border-slate-200/60 dark:border-slate-700 flex items-center justify-between text-xs font-bold text-sky-600 dark:text-sky-400 hover:bg-slate-200/60 transition"
      >
        <ChevronLeft className="w-5 h-5 text-sky-500" />
        <span>{cardNumber ? `شماره کارت: ${cardNumber}` : 'افزودن شماره کارت'}</span>
      </button>

      {/* Main Save & Share Action Button (Screenshot 3) */}
      <button
        onClick={handleSave}
        className="w-full p-4 rounded-3xl bg-slate-200 dark:bg-slate-700 hover:bg-sky-500 hover:text-white font-black text-sm text-slate-800 dark:text-white flex items-center justify-center gap-2 shadow-xs transition active:scale-98"
      >
        <Share2 className="w-5 h-5" />
        <span>ذخیره و اشتراک گذاری فاکتور</span>
      </button>

      {/* Sticky Bottom Tab Bar (Screenshots 2 & 3) */}
      <div className="fixed bottom-0 left-0 right-0 z-30 bg-slate-100/95 dark:bg-slate-900/95 backdrop-blur-md border-t border-slate-200 dark:border-slate-700 p-2">
        <div className="max-w-xl mx-auto flex items-center justify-between">
          
          {/* Plus button to add new tab */}
          <button
            onClick={onAddTab}
            className="w-10 h-10 rounded-xl bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-sky-600 flex items-center justify-center font-bold shadow-xs hover:bg-sky-50 transition"
            title="فاکتور جدید موقت"
          >
            <Plus className="w-6 h-6" />
          </button>

          {/* Active Tab Badge in center */}
          <button
            onClick={onOpenWindowsModal}
            className="px-5 py-2.5 rounded-xl bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-sky-600 font-bold text-xs flex items-center gap-2 shadow-xs"
          >
            <span className="text-[10px]">▲</span>
            <span>{tabs.find(t => t.id === activeTabId)?.title || 'پیش فاکتور ۱'}</span>
          </button>

          {/* Windows / Open tabs list icon button */}
          <button
            onClick={onOpenWindowsModal}
            className="w-10 h-10 rounded-xl bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 text-slate-700 dark:text-slate-200 flex items-center justify-center font-bold shadow-xs hover:bg-slate-200 transition"
            title="پنجره‌های باز"
          >
            <Menu className="w-5 h-5" />
          </button>

        </div>
      </div>

      {/* Customer Selection Modal */}
      {showCustomerModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
          <div className="w-full max-w-md bg-white dark:bg-slate-800 rounded-3xl p-5 shadow-2xl space-y-3 border border-slate-200 dark:border-slate-700">
            <div className="flex items-center justify-between pb-2 border-b border-slate-100 dark:border-slate-700">
              <h3 className="font-bold text-sm text-slate-800 dark:text-white">انتخاب از مشتریان ثبت‌شده</h3>
              <button onClick={() => setShowCustomerModal(false)} className="text-slate-400"><X className="w-5 h-5" /></button>
            </div>
            <div className="max-h-60 overflow-y-auto space-y-2">
              {customers.map(c => (
                <div
                  key={c.id}
                  onClick={() => {
                    setCustomerName(c.name);
                    setCustomerPhone(c.mobile || c.phone || '');
                    setShowCustomerModal(false);
                  }}
                  className="p-3 rounded-2xl bg-slate-50 dark:bg-slate-900 border border-slate-100 dark:border-slate-700 cursor-pointer hover:border-blue-500 flex justify-between items-center text-xs"
                >
                  <span className="font-bold text-slate-800 dark:text-white">{c.name}</span>
                  <span className="text-slate-400">{c.mobile || c.phone}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Catalog Selection Modal */}
      {showCatalogModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
          <div className="w-full max-w-md bg-white dark:bg-slate-800 rounded-3xl p-5 shadow-2xl space-y-3 border border-slate-200 dark:border-slate-700">
            <div className="flex items-center justify-between pb-2 border-b border-slate-100 dark:border-slate-700">
              <h3 className="font-bold text-sm text-slate-800 dark:text-white">انتخاب از کاتالوگ کالا و خدمات</h3>
              <button onClick={() => setShowCatalogModal(false)} className="text-slate-400"><X className="w-5 h-5" /></button>
            </div>
            <div className="max-h-60 overflow-y-auto space-y-2">
              {products.map(p => (
                <div
                  key={p.id}
                  onClick={() => addFromCatalog(p)}
                  className="p-3 rounded-2xl bg-slate-50 dark:bg-slate-900 border border-slate-100 dark:border-slate-700 cursor-pointer hover:border-emerald-500 flex justify-between items-center text-xs"
                >
                  <div>
                    <div className="font-bold text-slate-800 dark:text-white">{p.name}</div>
                    <div className="text-[10px] text-slate-400">واحد: {p.unit}</div>
                  </div>
                  <span className="font-bold text-emerald-600">{formatCurrency(p.sellPrice)}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

    </div>
  );
}
