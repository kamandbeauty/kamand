import React, { useState, useEffect } from 'react';
import {
  Plus,
  Share2,
  Package,
  X,
  ChevronLeft,
  Menu,
  UserPlus
} from 'lucide-react';
import { UNITS, formatCurrency, getTodayJalali, toPersianDigits } from '../utils/helpers';

/**
 * صفحه اصلی صدور فاکتور — چیدمان مطابق اسکرین‌شات مرجع (فیدا)
 * و هم‌راستا با DashboardScreen فلاتر
 */
export default function InvoiceCreatorView({
  customers,
  products,
  business,
  settings,
  onUpdateSettings,
  editingInvoice,
  onSaveInvoice,
  onCancel,
  onNewCustomerModal,
  onOpenSettings,
  tabs,
  activeTabId,
  onSelectTab,
  onAddTab,
  onOpenWindowsModal,
  onUpdateTabState,
  onAddProduct
}) {
  const [number, setNumber] = useState(editingInvoice?.number || '۱');
  const [customerName, setCustomerName] = useState(editingInvoice?.customerName || '');
  const [customerPhone, setCustomerPhone] = useState(editingInvoice?.customerPhone || '');
  const [date, setDate] = useState(editingInvoice?.date || getTodayJalali());

  const [type, setType] = useState(editingInvoice?.type || 'proforma');
  const [paymentType, setPaymentType] = useState(editingInvoice?.paymentType || 'non_cash');

  const [items, setItems] = useState(
    editingInvoice?.items?.length
      ? editingInvoice.items
      : [{ id: '1', title: '', quantity: 1, unit: 'عدد', unitPrice: 0, totalPrice: 0 }]
  );

  const [hasDiscount, setHasDiscount] = useState(Boolean(editingInvoice?.discountAmount));
  const [discountType, setDiscountType] = useState(
    editingInvoice?.discountPercent ? 'percent' : 'fixed'
  );
  const [discountValue, setDiscountValue] = useState(
    editingInvoice?.discountPercent || editingInvoice?.discountAmount || 0
  );

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
  const [selectedRow, setSelectedRow] = useState(null);

  useEffect(() => {
    if (!onUpdateTabState) return;
    onUpdateTabState({
      number,
      customerName,
      customerPhone,
      date,
      type,
      paymentType,
      items,
      discountAmount: discountValue,
      discountPercent: discountType === 'percent' ? discountValue : 0,
      shippingFee,
      deposit,
      previousDebt,
      notes,
      cardNumber
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    number,
    customerName,
    customerPhone,
    date,
    type,
    paymentType,
    items,
    discountValue,
    discountType,
    shippingFee,
    deposit,
    previousDebt,
    notes,
    cardNumber
  ]);

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
    const next = [
      ...items,
      {
        id: Date.now().toString(),
        title: '',
        quantity: 1,
        unit: 'عدد',
        unitPrice: 0,
        totalPrice: 0
      }
    ];
    setItems(next);
    setSelectedRow(next.length - 1);
  };

  const removeItemRow = (index) => {
    if (items.length === 1) {
      setItems([{ id: '1', title: '', quantity: 1, unit: 'عدد', unitPrice: 0, totalPrice: 0 }]);
      setSelectedRow(null);
      return;
    }
    setItems(items.filter((_, i) => i !== index));
    setSelectedRow(null);
  };

  const addFromCatalog = (product) => {
    const emptyIdx = items.findIndex((it) => !String(it.title || '').trim() && !it.unitPrice);
    if (emptyIdx >= 0) {
      const updated = [...items];
      updated[emptyIdx] = {
        ...updated[emptyIdx],
        title: product.name,
        unit: product.unit || 'عدد',
        unitPrice: product.sellPrice || 0,
        totalPrice: product.sellPrice || 0,
        quantity: 1
      };
      setItems(updated);
      setSelectedRow(emptyIdx);
    } else {
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
    }
    setShowCatalogModal(false);
    setProductSearch('');
  };

  const subtotal = items.reduce((sum, item) => sum + (parseFloat(item.totalPrice) || 0), 0);

  let discountAmount = 0;
  if (hasDiscount) {
    if (discountType === 'percent') {
      discountAmount = Math.round((subtotal * (parseFloat(discountValue) || 0)) / 100);
    } else {
      discountAmount = parseFloat(discountValue) || 0;
    }
  }

  const shipping = hasShipping ? parseFloat(shippingFee) || 0 : 0;
  const prevDebt = hasPreviousDebt ? parseFloat(previousDebt) || 0 : 0;
  const dep = hasDeposit ? parseFloat(deposit) || 0 : 0;
  // جمع ناخالص = اقلام − تخفیف + ارسال + بدهی قبلی
  const grossTotal = Math.max(0, subtotal - discountAmount + shipping + prevDebt);
  // مبلغ قابل پرداخت = ناخالص − بیعانه
  const totalAmount = Math.max(0, grossTotal - dep);

  const handleSave = () => {
    const cleanItems = items.filter(
      (it) => String(it.title || '').trim() || parseFloat(it.unitPrice) > 0
    );
    if (cleanItems.length === 0) {
      alert('حداقل یک قلم کالا با عنوان یا قیمت اضافه کنید');
      return;
    }
    if (totalAmount <= 0 && cleanItems.every((it) => !(parseFloat(it.unitPrice) > 0))) {
      alert('قیمت اقلام را وارد کنید');
      return;
    }

    const newInvoice = {
      id: editingInvoice?.id || `inv-${Date.now()}`,
      number: number || '۱',
      customerId: '',
      customerName: customerName.trim() || 'مشتری عمومی',
      customerPhone,
      type,
      paymentType,
      status: type === 'proforma' ? 'proforma' : paymentType === 'cash' ? 'paid' : 'unpaid',
      date: date || getTodayJalali(),
      items: cleanItems,
      subtotal,
      discountPercent: discountType === 'percent' ? parseFloat(discountValue) || 0 : 0,
      discountAmount,
      shippingFee: shipping,
      previousDebt: prevDebt,
      deposit: dep,
      totalAmount,
      // بیعانه قبلاً از total کم شده؛ در غیرنقدی paid=بیعانه و remaining=total
      paidAmount: paymentType === 'cash' ? totalAmount : dep,
      remainingAmount: paymentType === 'cash' ? 0 : totalAmount,
      notes,
      cardNumber,
      createdAt: date || getTodayJalali()
    };

    // ذخیره و باز شدن صفحه نمایش فاکتور
    onSaveInvoice(newInvoice, true);
  };

  const filteredProducts = products.filter(
    (p) =>
      !productSearch.trim() ||
      p.name.includes(productSearch) ||
      (p.code && String(p.code).includes(productSearch))
  );

  const typeLabel =
    type === 'sale' ? 'فاکتور فروش' : type === 'purchase' ? 'فاکتور خرید' : 'پیش فاکتور';

  const formatThousands = (raw) => {
    const clean = String(raw ?? '').replace(/[^\d.]/g, '');
    if (!clean) return '';
    const [a, b] = clean.split('.');
    const intPart = a.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    return toPersianDigits(b !== undefined ? `${intPart}.${b}` : intPart);
  };
  const parseThousands = (s) => {
    const clean = String(s ?? '').replace(/[^\d.]/g, '');
    if (!clean) return 0;
    const n = parseFloat(clean);
    return Number.isFinite(n) ? n : 0;
  };
  const fmtNum = (n) =>
    toPersianDigits(Math.round(Number(n) || 0).toLocaleString('en-US'));

  return (
    <div className="relative max-w-lg mx-auto pb-20 animate-fade-in font-vazir" dir="rtl">
      {/* ۱) تنظیمات فاکتور */}
      <button
        type="button"
        onClick={() => {
          if (typeof onOpenSettings === 'function') {
            onOpenSettings();
          } else {
            alert('از منو وارد تنظیمات شوید تا سربرگ، مهر و امضا را ویرایش کنید.');
          }
        }}
        className="w-full h-[52px] mb-3 rounded-2xl bg-[#F97316] hover:bg-[#EA580C] text-white font-extrabold text-[13px] shadow-sm transition active:scale-[0.99]"
      >
        تنظیمات فاکتور
      </button>

      {/* ۲) کارت اطلاعات مشتری — لیبل بالا + یک کادر تمیز */}
      <div className="mb-2.5 rounded-2xl bg-[#F1F5F9] dark:bg-slate-800 border border-transparent dark:border-slate-700 p-3 space-y-3">
        <div className="space-y-1.5">
          <div className="text-[11px] font-bold text-slate-500 dark:text-slate-400 text-right">
            نام مشتری
          </div>
          <div className="flex items-center gap-1.5">
            <input
              type="text"
              value={customerName}
              onChange={(e) => setCustomerName(e.target.value)}
              placeholder="مثلاً: آقای محمدی"
              dir="rtl"
              lang="fa"
              autoComplete="off"
              className="invoice-rtl-input flex-1 min-w-0 h-[44px] rounded-xl bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-500 px-3 outline-none text-[13px] font-bold text-slate-800 dark:text-white placeholder:text-slate-400 placeholder:font-normal focus:border-[#F97316] focus:ring-1 focus:ring-orange-200"
              style={{ direction: 'rtl', textAlign: 'right', unicodeBidi: 'plaintext' }}
            />
            <button
              type="button"
              onClick={() => setShowCustomerModal(true)}
              className="shrink-0 h-[44px] w-[44px] rounded-xl bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-500 text-[#F97316] flex items-center justify-center"
              title="انتخاب مشتری"
            >
              <UserPlus className="w-4 h-4" />
            </button>
          </div>
        </div>

        <div className="space-y-1.5">
          <div className="text-[11px] font-bold text-slate-500 dark:text-slate-400 text-right">
            شماره همراه مشتری
          </div>
          <input
            type="tel"
            value={customerPhone}
            onChange={(e) => setCustomerPhone(e.target.value)}
            placeholder="۰۹۱۲xxxxxxx"
            className="w-full h-[44px] rounded-xl bg-white dark:bg-slate-700 border border-slate-300 dark:border-slate-500 px-3 outline-none text-[13px] font-bold text-slate-800 dark:text-white placeholder:text-slate-400 placeholder:font-normal focus:border-[#F97316] focus:ring-1 focus:ring-orange-200"
            dir="ltr"
            style={{ textAlign: 'right' }}
          />
        </div>

        <div className="border-t border-slate-200 dark:border-slate-700 pt-2.5 flex items-center justify-between gap-2 text-[11px]">
          <div className="flex items-center gap-1.5 min-w-0">
            <span className="text-slate-500 dark:text-slate-400 shrink-0">شماره فاکتور:</span>
            <input
              type="text"
              value={number}
              onChange={(e) => setNumber(e.target.value)}
              className="w-14 bg-white dark:bg-slate-700 border border-slate-200 dark:border-slate-600 rounded-md px-1.5 py-0.5 font-extrabold text-[13px] text-center text-slate-800 dark:text-white outline-none"
            />
            <span className="w-1.5 h-1.5 rounded-full bg-[#F97316] shrink-0" />
          </div>
          <div className="flex items-center gap-1.5 min-w-0">
            <span className="text-slate-500 dark:text-slate-400 shrink-0">تاریخ:</span>
            <input
              type="text"
              value={date}
              onChange={(e) => setDate(e.target.value)}
              className="w-[6.5rem] bg-transparent font-semibold text-[11px] text-slate-800 dark:text-white outline-none text-left"
            />
          </div>
        </div>
      </div>

{/* ۳) جدول اقلام — عنوان پهن + تایپ راست‌چین */}
      <div className="mb-2 rounded-xl bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 overflow-hidden">
        <div className="overflow-x-auto">
          <table
            className="w-full min-w-[380px] border-collapse invoice-items-table"
            dir="rtl"
            style={{ tableLayout: 'fixed' }}
          >
            <colgroup>
              <col style={{ width: '46%' }} />
              <col style={{ width: '12%' }} />
              <col style={{ width: '12%' }} />
              <col style={{ width: '15%' }} />
              <col style={{ width: '15%' }} />
            </colgroup>
            <thead>
              <tr className="bg-slate-50 dark:bg-slate-900/60 border-b border-slate-200 dark:border-slate-700">
                {['عنوان', 'مقدار', 'واحد', 'قیمت واحد', 'قیمت کل'].map((label, i, arr) => (
                  <th
                    key={label}
                    className={`py-2.5 px-1.5 text-[10px] font-bold text-slate-600 dark:text-slate-400 ${
                      i === 0 ? 'text-right' : 'text-center'
                    } ${i < arr.length - 1 ? 'border-l border-slate-200 dark:border-slate-700' : ''}`}
                  >
                    {label}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {items.map((item, index) => {
                const isSelected = selectedRow === index;
                return (
                  <tr
                    key={item.id}
                    onClick={() => setSelectedRow(index)}
                    className={`border-b border-slate-200 dark:border-slate-700 text-xs cursor-pointer ${
                      isSelected ? 'bg-orange-50/70 dark:bg-orange-900/10' : ''
                    }`}
                  >
                    {/* عنوان + شماره ردیف — فضای بیشتر */}
                    <td className="p-0 border-l border-slate-200 dark:border-slate-700 align-middle">
                      <div className="flex items-center gap-1 px-1.5 py-1.5 min-h-[42px]" dir="rtl">
                        {isSelected ? (
                          <button
                            type="button"
                            onClick={(e) => {
                              e.stopPropagation();
                              removeItemRow(index);
                            }}
                            className="p-0.5 text-slate-400 hover:text-rose-500 shrink-0"
                            title="حذف سطر"
                          >
                            <X className="w-4 h-4" />
                          </button>
                        ) : (
                          <span className="w-4 shrink-0" />
                        )}
                        <span className="text-[11px] text-slate-500 font-bold shrink-0 tabular-nums">
                          {toPersianDigits(index + 1)}
                        </span>
                        <input
                          type="text"
                          value={item.title}
                          onChange={(e) => handleItemChange(index, 'title', e.target.value)}
                          onFocus={() => setSelectedRow(index)}
                          placeholder="نام کالا / خدمت"
                          dir="rtl"
                          lang="fa"
                          className="invoice-rtl-input flex-1 min-w-0 w-full bg-transparent outline-none text-[12px] font-medium text-slate-800 dark:text-white py-2 px-1.5 rounded-md focus:bg-white dark:focus:bg-slate-900 focus:ring-1 focus:ring-orange-300"
                          style={{
                            direction: 'rtl',
                            textAlign: 'right',
                            unicodeBidi: 'plaintext'
                          }}
                        />
                      </div>
                    </td>

                    {/* مقدار — با فوکوس کل متن انتخاب می‌شود تا تایپ جایگزین شود */}
                    <td className="p-0 border-l border-slate-200 dark:border-slate-700 align-middle">
                      <input
                        type="text"
                        inputMode="decimal"
                        value={item.quantity === '' || item.quantity === undefined ? '' : item.quantity}
                        onChange={(e) => {
                          const v = e.target.value.replace(/[^\d.]/g, '');
                          handleItemChange(index, 'quantity', v === '' ? 0 : v);
                        }}
                        onFocus={(e) => {
                          setSelectedRow(index);
                          e.target.select();
                        }}
                        onClick={(e) => e.target.select()}
                        className="w-full bg-transparent outline-none text-center text-[12px] font-bold text-slate-800 dark:text-white py-2.5 px-0.5"
                        dir="ltr"
                      />
                    </td>

                    {/* واحد */}
                    <td className="p-0 border-l border-slate-200 dark:border-slate-700 align-middle">
                      <select
                        value={item.unit}
                        onChange={(e) => handleItemChange(index, 'unit', e.target.value)}
                        onFocus={() => setSelectedRow(index)}
                        className="w-full bg-transparent outline-none text-center text-[11px] text-slate-700 dark:text-slate-200 py-2.5 appearance-none"
                        dir="rtl"
                      >
                        {UNITS.map((u) => (
                          <option key={u} value={u}>
                            {u}
                          </option>
                        ))}
                      </select>
                    </td>

                    {/* قیمت واحد — با فوکوس کل متن انتخاب می‌شود تا تایپ جایگزین شود */}
                    <td className="p-0 border-l border-slate-200 dark:border-slate-700 align-middle">
                      <input
                        type="text"
                        inputMode="decimal"
                        value={item.unitPrice ? formatThousands(item.unitPrice) : ''}
                        onChange={(e) => {
                          const n = parseThousands(e.target.value);
                          handleItemChange(index, 'unitPrice', n);
                        }}
                        onFocus={(e) => {
                          setSelectedRow(index);
                          e.target.select();
                        }}
                        onClick={(e) => e.target.select()}
                        placeholder="۰"
                        className="w-full bg-transparent outline-none text-center text-[11px] font-bold text-slate-800 dark:text-white py-2.5 px-0.5"
                        dir="ltr"
                      />
                    </td>

                    {/* قیمت کل */}
                    <td className="p-0 align-middle">
                      <div className="text-center text-[11px] font-bold text-slate-800 dark:text-white py-2.5 px-1 tabular-nums">
                        {item.totalPrice ? fmtNum(item.totalPrice) : '۰'}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>

        {/* ایجاد سطر + کاتالوگ */}
        <div className="h-12 flex items-center justify-between gap-2 px-3 border-t border-slate-100 dark:border-slate-700 bg-slate-50/80 dark:bg-slate-900/30">
          <button
            type="button"
            onClick={() => setShowCatalogModal(true)}
            className="flex items-center gap-1 text-emerald-600 dark:text-emerald-400 font-extrabold text-[12px]"
          >
            <Package className="w-3.5 h-3.5" />
            <span>کاتالوگ</span>
          </button>
          {items.some((it, i) => i === selectedRow && String(it.title||'').trim()) && (
            <button
              type="button"
              onClick={() => {
                const it = items[selectedRow];
                if (!it || !String(it.title||'').trim()) return;
                // bubble via custom event - parent may not have handler; use alert fallback
                const name = String(it.title).trim();
                const exists = products.some(p => p.name === name);
                if (exists) { alert('این کالا از قبل در کاتالوگ هست'); return; }
                // Need onAddProduct prop - check
                if (typeof onAddProduct === 'function') {
                  onAddProduct({
                    id: `p-${Date.now()}`,
                    code: `${100+products.length+1}`,
                    name,
                    unit: it.unit || 'عدد',
                    buyPrice: 0,
                    sellPrice: parseFloat(it.unitPrice)||0,
                    stock: 0,
                    notes: ''
                  });
                  alert(`«${name}» به کاتالوگ اضافه شد`);
                } else {
                  alert('برای افزودن به کاتالوگ، از صفحه کالاها استفاده کنید');
                }
              }}
              className="flex items-center gap-1 text-[#F97316] font-extrabold text-[12px] px-2"
            >
              <span>افزودن به کاتالوگ</span>
            </button>
          )}
          <button
            type="button"
            onClick={addItemRow}
            className="flex items-center gap-1.5 text-[#F97316] font-extrabold text-[13px] mr-auto"
          >
            <span>ایجاد</span>
            <span className="w-[22px] h-[22px] rounded-md bg-orange-100 dark:bg-orange-900/30 flex items-center justify-center">
              <Plus className="w-4 h-4 text-[#F97316]" strokeWidth={2.5} />
            </span>
          </button>
        </div>
      </div>

      {/* جمع آیتم‌ها */}
      <div className="flex items-center justify-between px-1 mb-3 text-[12px]">
        <span className="font-bold text-slate-700 dark:text-slate-200">جمع آیتم‌ها</span>
        <span className="text-slate-500 dark:text-slate-400 tabular-nums">
          {formatCurrency(subtotal)}
        </span>
      </div>

      {/* ۴) هزینه ارسال / تخفیف / بیعانه / بدهی قبلی */}
      <div className="mb-2.5 rounded-2xl bg-[#F1F5F9] dark:bg-slate-800 border border-transparent dark:border-slate-700 p-3 space-y-2">
        <div className="grid grid-cols-2 gap-2">
          <CheckField
            label="هزینه ارسال:"
            checked={hasShipping}
            onChange={setHasShipping}
            showInput={hasShipping}
            value={shippingFee}
            onValueChange={setShippingFee}
          />
          <CheckField
            label="تخفیف:"
            checked={hasDiscount}
            onChange={setHasDiscount}
            showInput={hasDiscount}
            value={discountValue}
            onValueChange={setDiscountValue}
            extra={
              hasDiscount ? (
                <button
                  type="button"
                  onClick={() =>
                    setDiscountType(discountType === 'percent' ? 'fixed' : 'percent')
                  }
                  className="text-[11px] font-bold text-[#F97316] underline shrink-0"
                >
                  {discountType === 'percent' ? 'درصد' : 'مبلغ'}
                </button>
              ) : null
            }
          />
        </div>
        <div className="border-t border-slate-200 dark:border-slate-700 pt-2 grid grid-cols-2 gap-2">
          <CheckField
            label="بیعانه:"
            checked={hasDeposit}
            onChange={setHasDeposit}
            showInput={hasDeposit}
            value={deposit}
            onValueChange={setDeposit}
          />
          <CheckField
            label="بدهی قبلی:"
            checked={hasPreviousDebt}
            onChange={setHasPreviousDebt}
            showInput={hasPreviousDebt}
            value={previousDebt}
            onValueChange={setPreviousDebt}
          />
        </div>
      </div>

      {/* ۵) نوع فاکتور / نوع پرداخت */}
      <div className="mb-3 rounded-2xl bg-[#F1F5F9] dark:bg-slate-800 border border-transparent dark:border-slate-700 p-3 space-y-2">
        <div className="flex items-center gap-2 flex-wrap">
          <span className="text-[11px] font-bold text-slate-600 dark:text-slate-300 shrink-0">
            نوع فاکتور
          </span>
          <div className="flex-1 flex items-center justify-end gap-2 flex-wrap">
            <RadioChip
              label="پیش فاکتور"
              active={type === 'proforma'}
              onClick={() => setType('proforma')}
            />
            <RadioChip
              label="فاکتور خرید"
              active={type === 'purchase'}
              onClick={() => setType('purchase')}
            />
            <RadioChip
              label="فاکتور فروش"
              active={type === 'sale'}
              onClick={() => setType('sale')}
            />
          </div>
        </div>
        <div className="border-t border-slate-200 dark:border-slate-700 pt-2 flex items-center gap-2">
          <span className="text-[11px] font-bold text-slate-600 dark:text-slate-300 shrink-0">
            نوع پرداخت
          </span>
          <div className="flex-1 flex items-center justify-end gap-3">
            <RadioChip
              label="نقدی"
              active={paymentType === 'cash'}
              onClick={() => setPaymentType('cash')}
            />
            <RadioChip
              label="غیر نقدی"
              active={paymentType === 'non_cash'}
              onClick={() => setPaymentType('non_cash')}
            />
          </div>
        </div>
      </div>

      {/* ۶) خلاصه مبالغ */}
      <div className="mb-2.5 rounded-2xl bg-[#F1F5F9] dark:bg-slate-800 border border-transparent dark:border-slate-700 p-3 space-y-1.5 text-[12px]">
        <div className="flex justify-between text-slate-600 dark:text-slate-300">
          <span>جمع اقلام</span>
          <span className="font-bold tabular-nums">{formatCurrency(subtotal)}</span>
        </div>
        {hasDiscount && discountAmount > 0 && (
          <div className="flex justify-between text-emerald-600">
            <span>تخفیف{discountType === 'percent' ? ` (${toPersianDigits(discountValue)}٪)` : ''}</span>
            <span className="font-bold tabular-nums">− {formatCurrency(discountAmount)}</span>
          </div>
        )}
        {hasShipping && shipping > 0 && (
          <div className="flex justify-between text-slate-600 dark:text-slate-300">
            <span>هزینه ارسال</span>
            <span className="font-bold tabular-nums">+ {formatCurrency(shipping)}</span>
          </div>
        )}
        {hasPreviousDebt && prevDebt > 0 && (
          <div className="flex justify-between text-rose-600">
            <span>بدهی قبلی</span>
            <span className="font-bold tabular-nums">+ {formatCurrency(prevDebt)}</span>
          </div>
        )}
        {hasDeposit && dep > 0 && (
          <div className="flex justify-between text-sky-600">
            <span>بیعانه</span>
            <span className="font-bold tabular-nums">− {formatCurrency(dep)}</span>
          </div>
        )}
        <div className="flex justify-between pt-2 border-t border-slate-200 dark:border-slate-700">
          <span className="font-black text-slate-800 dark:text-white">مبلغ قابل پرداخت</span>
          <span className="text-lg font-black text-[#F97316] tabular-nums">
            {formatCurrency(totalAmount)}
          </span>
        </div>
      </div>

      {/* تیک مهر و امضا */}
      <div className="mb-2.5 rounded-2xl bg-[#F1F5F9] dark:bg-slate-800 border border-transparent dark:border-slate-700 p-3 space-y-2">
        <label className="flex items-center gap-2 cursor-pointer select-none">
          <input
            type="checkbox"
            checked={Boolean(settings?.showStamp !== false)}
            onChange={(e) =>
              onUpdateSettings?.({ ...(settings || {}), showStamp: e.target.checked })
            }
            className="w-[18px] h-[18px] rounded accent-[#F97316]"
          />
          <span className="text-[11px] font-bold text-slate-600 dark:text-slate-300 flex-1">
            نمایش مهر روی فاکتور
          </span>
          {!business?.stampDataUrl && (
            <span className="text-[10px] text-[#F97316] font-bold">از تنظیمات اضافه کنید</span>
          )}
        </label>
        <div className="border-t border-slate-200 dark:border-slate-700" />
        <label className="flex items-center gap-2 cursor-pointer select-none">
          <input
            type="checkbox"
            checked={Boolean(settings?.showSignature !== false)}
            onChange={(e) =>
              onUpdateSettings?.({ ...(settings || {}), showSignature: e.target.checked })
            }
            className="w-[18px] h-[18px] rounded accent-[#F97316]"
          />
          <span className="text-[11px] font-bold text-slate-600 dark:text-slate-300 flex-1">
            نمایش امضا روی فاکتور
          </span>
          {!business?.signatureDataUrl && (
            <span className="text-[10px] text-[#F97316] font-bold">از تنظیمات اضافه کنید</span>
          )}
        </label>
      </div>

      {/* ۷) توضیحات */}
      <div className="mb-2.5 rounded-2xl bg-[#F1F5F9] dark:bg-slate-800 border border-transparent dark:border-slate-700 px-3 py-2">
        <textarea
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="توضیحات"
          rows={2}
          dir="rtl"
          lang="fa"
          className="invoice-rtl-input w-full bg-transparent outline-none text-[12px] text-slate-800 dark:text-white placeholder:text-slate-400 resize-none"
          style={{ direction: 'rtl', textAlign: 'right', unicodeBidi: 'plaintext' }}
        />
      </div>

      {/* ۸) شماره کارت */}
      <button
        type="button"
        onClick={() => {
          const card = prompt('شماره کارت بانکی جهت درج در فاکتور:', cardNumber || '');
          if (card !== null) setCardNumber(card.trim());
        }}
        className="w-full mb-2.5 rounded-2xl bg-[#F1F5F9] dark:bg-slate-800 border border-transparent dark:border-slate-700 px-3 py-3.5 flex items-center justify-between"
      >
        <ChevronLeft className="w-5 h-5 text-slate-400" />
        <span className="text-[12px] font-bold text-[#F97316]">
          {cardNumber ? `شماره کارت: ${cardNumber}` : 'افزودن شماره کارت'}
        </span>
      </button>

      {/* ۹) ذخیره و اشتراک‌گذاری */}
      <button
        type="button"
        onClick={handleSave}
        className="w-full h-14 mb-2 rounded-xl bg-[#F1F5F9] dark:bg-slate-800 border border-slate-200 dark:border-slate-700 flex items-center justify-center gap-2 hover:bg-orange-50 dark:hover:bg-orange-900/20 transition active:scale-[0.99]"
      >
        <Share2 className="w-5 h-5 text-slate-600 dark:text-slate-300" />
        <span className="text-[13px] font-extrabold text-slate-800 dark:text-white">
          ذخیره و اشتراک گذاری فاکتور
        </span>
      </button>

      {/* نوار پایین چندپنجره‌ای */}
      <div className="fixed bottom-0 left-0 right-0 z-30 bg-white dark:bg-slate-900 border-t border-slate-200 dark:border-slate-700">
        <div className="max-w-lg mx-auto h-12 flex items-stretch" dir="rtl">
          {/* + سمت راست در RTL */}
          <button
            type="button"
            onClick={onAddTab}
            className="w-12 shrink-0 flex items-center justify-center border-l border-slate-200 dark:border-slate-700 text-[#F97316]"
            title="فاکتور جدید موقت"
          >
            <Plus className="w-[22px] h-[22px]" strokeWidth={2.5} />
          </button>

          <div className="flex-1 flex items-stretch overflow-x-auto no-scrollbar">
            {tabs.map((tab) => {
              const isActive = tab.id === activeTabId;
              const label = tab.title || `${typeLabel} ${toPersianDigits(tab.number)}`;
              return (
                <button
                  key={tab.id}
                  type="button"
                  onClick={() => onSelectTab?.(tab.id)}
                  className={`px-3 min-w-[7rem] shrink-0 flex items-center justify-center gap-1 text-[11px] font-extrabold border-l border-slate-200 dark:border-slate-700 ${
                    isActive
                      ? 'bg-[#F1F5F9] dark:bg-slate-800 text-[#F97316]'
                      : 'text-slate-500 dark:text-slate-400'
                  }`}
                >
                  <span className="truncate max-w-[5.5rem]">{label}</span>
                  {isActive && <span className="text-[#F97316] text-sm leading-none">▴</span>}
                </button>
              );
            })}
          </div>

          <button
            type="button"
            onClick={onOpenWindowsModal}
            className="w-12 shrink-0 flex items-center justify-center text-slate-700 dark:text-slate-200"
            title="پنجره‌های باز"
          >
            <Menu className="w-5 h-5" />
          </button>
        </div>
      </div>

      {/* مدال مشتری */}
      {showCustomerModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
          <div className="w-full max-w-md bg-white dark:bg-slate-800 rounded-3xl p-5 shadow-2xl space-y-3 border border-slate-200 dark:border-slate-700">
            <div className="flex items-center justify-between pb-2 border-b border-slate-100 dark:border-slate-700">
              <h3 className="font-bold text-sm text-slate-800 dark:text-white">
                انتخاب از مشتریان ثبت‌شده
              </h3>
              <button type="button" onClick={() => setShowCustomerModal(false)} className="text-slate-400">
                <X className="w-5 h-5" />
              </button>
            </div>
            <div className="max-h-60 overflow-y-auto space-y-2">
              {customers.length === 0 ? (
                <div className="text-center py-6 text-xs text-slate-400">مشتری‌ای ثبت نشده است</div>
              ) : (
                customers.map((c) => (
                  <div
                    key={c.id}
                    onClick={() => {
                      setCustomerName(c.name);
                      setCustomerPhone(c.mobile || c.phone || '');
                      setShowCustomerModal(false);
                    }}
                    className="p-3 rounded-2xl bg-slate-50 dark:bg-slate-900 border border-slate-100 dark:border-slate-700 cursor-pointer hover:border-[#F97316] flex justify-between items-center text-xs"
                  >
                    <span className="font-bold text-slate-800 dark:text-white">{c.name}</span>
                    <span className="text-slate-400" dir="ltr">
                      {c.mobile || c.phone}
                    </span>
                  </div>
                ))
              )}
            </div>
            {onNewCustomerModal && (
              <button
                type="button"
                onClick={() => {
                  setShowCustomerModal(false);
                  onNewCustomerModal();
                }}
                className="w-full py-2.5 rounded-xl bg-orange-50 dark:bg-orange-900/20 text-[#F97316] font-bold text-xs border border-orange-200 dark:border-orange-800"
              >
                + افزودن مشتری جدید
              </button>
            )}
          </div>
        </div>
      )}

      {/* مدال کاتالوگ */}
      {showCatalogModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
          <div className="w-full max-w-md bg-white dark:bg-slate-800 rounded-3xl p-5 shadow-2xl space-y-3 border border-slate-200 dark:border-slate-700">
            <div className="flex items-center justify-between pb-2 border-b border-slate-100 dark:border-slate-700">
              <h3 className="font-bold text-sm text-slate-800 dark:text-white">
                انتخاب از کاتالوگ کالا و خدمات
              </h3>
              <button
                type="button"
                onClick={() => {
                  setShowCatalogModal(false);
                  setProductSearch('');
                }}
                className="text-slate-400"
              >
                <X className="w-5 h-5" />
              </button>
            </div>
            <input
              type="text"
              value={productSearch}
              onChange={(e) => setProductSearch(e.target.value)}
              placeholder="جستجوی کالا..."
              dir="rtl"
              lang="fa"
              className="invoice-rtl-input w-full p-2.5 rounded-xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-xs font-bold outline-none focus:border-[#F97316]"
              style={{ direction: 'rtl', textAlign: 'right', unicodeBidi: 'plaintext' }}
              autoFocus
            />
            <div className="max-h-60 overflow-y-auto space-y-2">
              {filteredProducts.length === 0 ? (
                <div className="text-center py-6 text-xs text-slate-400">کالایی یافت نشد</div>
              ) : (
                filteredProducts.map((p) => (
                  <div
                    key={p.id}
                    onClick={() => addFromCatalog(p)}
                    className="p-3 rounded-2xl bg-slate-50 dark:bg-slate-900 border border-slate-100 dark:border-slate-700 cursor-pointer hover:border-emerald-500 flex justify-between items-center text-xs gap-2"
                  >
                    <div className="min-w-0 text-right">
                      <div className="font-bold text-slate-800 dark:text-white truncate">{p.name}</div>
                      <div className="text-[10px] text-slate-400">واحد: {p.unit}</div>
                    </div>
                    <span className="font-bold text-emerald-600 shrink-0">
                      {formatCurrency(p.sellPrice)}
                    </span>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function CheckField({ label, checked, onChange, showInput, value, onValueChange, extra }) {
  return (
    <div className="flex items-center gap-1.5 min-h-[28px] w-full">
      <input
        type="checkbox"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
        className="w-[18px] h-[18px] rounded accent-[#F97316] shrink-0"
      />
      <span className="text-[11px] text-slate-500 dark:text-slate-400 shrink-0">{label}</span>
      {extra}
      <span className="flex-1" />
      {showInput && (
        <input
          type="number"
          value={value || ''}
          onChange={(e) => onValueChange(e.target.value)}
          placeholder="۰"
          className="w-[72px] h-8 rounded-lg border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-900 text-center text-[12px] font-bold text-slate-800 dark:text-white outline-none shrink-0"
        />
      )}
    </div>
  );
}

function RadioChip({ label, active, onClick }) {
  return (
    <button type="button" onClick={onClick} className="flex items-center gap-1 select-none">
      <span
        className={`text-[11px] ${
          active
            ? 'text-[#F97316] font-extrabold'
            : 'text-slate-500 dark:text-slate-400 font-medium'
        }`}
      >
        {label}
      </span>
      <span
        className={`w-5 h-5 rounded-full border-2 flex items-center justify-center ${
          active ? 'border-[#F97316] bg-[#F97316]' : 'border-slate-400'
        }`}
      >
        {active && <span className="w-2 h-2 rounded-full bg-white" />}
      </span>
    </button>
  );
}
