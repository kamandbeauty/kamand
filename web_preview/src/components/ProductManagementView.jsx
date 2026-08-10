import React, { useState } from 'react';
import {
  Package,
  Search,
  Plus,
  Edit,
  Trash2,
  X,
  Tag,
  Boxes,
  TrendingUp,
  DollarSign
} from 'lucide-react';
import { UNITS, formatCurrency, toPersianDigits } from '../utils/helpers';

export default function ProductManagementView({
  products,
  onAddProduct,
  onEditProduct,
  onDeleteProduct
}) {
  const [searchTerm, setSearchTerm] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [editingProduct, setEditingProduct] = useState(null);

  // Form state
  const [name, setName] = useState('');
  const [code, setCode] = useState('');
  const [unit, setUnit] = useState('عدد');
  const [buyPrice, setBuyPrice] = useState('');
  const [sellPrice, setSellPrice] = useState('');
  const [stock, setStock] = useState('10');
  const [notes, setNotes] = useState('');

  const openAddModal = () => {
    setEditingProduct(null);
    setName('');
    setCode((products.length + 101).toString());
    setUnit('عدد');
    setBuyPrice('');
    setSellPrice('');
    setStock('10');
    setNotes('');
    setShowModal(true);
  };

  const openEditModal = (p) => {
    setEditingProduct(p);
    setName(p.name || '');
    setCode(p.code || '');
    setUnit(p.unit || 'عدد');
    setBuyPrice((p.buyPrice || 0).toString());
    setSellPrice((p.sellPrice || 0).toString());
    setStock((p.stock || 0).toString());
    setNotes(p.notes || '');
    setShowModal(true);
  };

  const handleSave = (e) => {
    e.preventDefault();
    if (!name.trim()) {
      alert('لطفا نام کالا/خدمت را وارد کنید.');
      return;
    }

    const productData = {
      id: editingProduct?.id || `p-${Date.now()}`,
      code: code.trim() || Date.now().toString().slice(-4),
      name: name.trim(),
      unit,
      buyPrice: parseFloat(buyPrice) || 0,
      sellPrice: parseFloat(sellPrice) || 0,
      stock: parseFloat(stock) || 0,
      notes: notes.trim()
    };

    if (editingProduct) {
      onEditProduct(productData);
    } else {
      onAddProduct(productData);
    }

    setShowModal(false);
  };

  const filtered = products.filter(p =>
    p.name.includes(searchTerm.trim()) ||
    p.code.includes(searchTerm.trim())
  );

  return (
    <div className="space-y-6 animate-fade-in pb-12">
      
      {/* Top Header */}
      <div className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm flex flex-col sm:flex-row items-center justify-between gap-4">
        
        <div className="flex items-center gap-3 w-full sm:w-auto">
          <div className="w-10 h-10 rounded-2xl bg-indigo-600 text-white flex items-center justify-center font-bold">
            <Package className="w-5 h-5" />
          </div>
          <div>
            <h2 className="font-bold text-lg text-slate-800 dark:text-white">
              مدیریت کالاها و خدمات
            </h2>
            <p className="text-xs text-slate-400">
              تعداد کالا/خدمات: {toPersianDigits(products.length)}
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
              placeholder="جستجوی کد یا عنوان کالا..."
              className="w-full pr-9 pl-3 py-2.5 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white text-xs"
            />
          </div>

          <button
            onClick={openAddModal}
            className="px-4 py-2.5 rounded-2xl bg-indigo-600 hover:bg-indigo-700 text-white font-bold text-xs shadow-md shadow-indigo-500/20 flex items-center gap-1.5 shrink-0 transition"
          >
            <Plus className="w-4 h-4" />
            <span>کالا جدید</span>
          </button>
        </div>

      </div>

      {/* Product List Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {filtered.length === 0 ? (
          <div className="col-span-full py-12 text-center text-slate-400 text-xs bg-white dark:bg-slate-800 rounded-3xl p-6">
            کالا یا خدمتی با این مشخصات یافت نشد.
          </div>
        ) : (
          filtered.map((product) => {
            const margin = product.sellPrice - product.buyPrice;

            return (
              <div
                key={product.id}
                className="bg-white dark:bg-slate-800 p-5 rounded-3xl border border-slate-100 dark:border-slate-700 shadow-sm hover:shadow-md transition space-y-3 flex flex-col justify-between"
              >
                <div className="space-y-3">
                  
                  {/* Title & Code Badge */}
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <span className="text-[10px] font-mono font-bold text-indigo-600 dark:text-indigo-400 bg-indigo-50 dark:bg-indigo-900/40 px-2 py-0.5 rounded-md inline-block mb-1">
                        کد: {toPersianDigits(product.code)}
                      </span>
                      <h3 className="font-bold text-base text-slate-800 dark:text-white">
                        {product.name}
                      </h3>
                    </div>

                    <span className="px-2.5 py-1 rounded-full text-[11px] font-bold bg-slate-100 dark:bg-slate-700 text-slate-700 dark:text-slate-300 shrink-0">
                      موجودی: {toPersianDigits(product.stock)} {product.unit}
                    </span>
                  </div>

                  {/* Price Box */}
                  <div className="p-3 bg-slate-50 dark:bg-slate-900/50 rounded-2xl border border-slate-100 dark:border-slate-700/60 grid grid-cols-2 gap-2 text-xs">
                    <div>
                      <div className="text-[10px] text-slate-400">قیمت فروش</div>
                      <div className="font-bold text-slate-800 dark:text-white text-sm">
                        {formatCurrency(product.sellPrice)}
                      </div>
                    </div>

                    <div>
                      <div className="text-[10px] text-slate-400">قیمت خرید</div>
                      <div className="font-medium text-slate-500 dark:text-slate-400 text-xs">
                        {product.buyPrice ? formatCurrency(product.buyPrice) : '---'}
                      </div>
                    </div>
                  </div>

                  {product.notes && (
                    <p className="text-[11px] text-slate-400 line-clamp-1">
                      {product.notes}
                    </p>
                  )}

                </div>

                {/* Card Actions */}
                <div className="pt-3 border-t border-slate-100 dark:border-slate-700 flex items-center justify-between">
                  <div className="text-[10px] text-emerald-600 dark:text-emerald-400 font-bold">
                    حاشیه سود: {formatCurrency(margin)}
                  </div>

                  <div className="flex items-center gap-1">
                    <button
                      onClick={() => openEditModal(product)}
                      className="p-1.5 rounded-lg text-slate-400 hover:text-blue-600 hover:bg-slate-100 dark:hover:bg-slate-700 transition"
                      title="ویرایش"
                    >
                      <Edit className="w-4 h-4" />
                    </button>
                    <button
                      onClick={() => {
                        if (window.confirm(`آیا از حذف کالا ${product.name} اطمینان دارید؟`)) {
                          onDeleteProduct(product.id);
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

      {/* Add / Edit Product Modal */}
      {showModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-sm">
          <div className="w-full max-w-lg bg-white dark:bg-slate-800 rounded-3xl p-6 shadow-2xl space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-slate-700">
              <h3 className="font-bold text-base text-slate-800 dark:text-white">
                {editingProduct ? 'ویرایش کالا / خدمت' : 'افزودن کالا یا خدمت جدید'}
              </h3>
              <button onClick={() => setShowModal(false)} className="p-1 text-slate-400">
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSave} className="space-y-3 text-xs">
              <div>
                <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
                  نام کالا یا خدمت *
                </label>
                <input
                  type="text"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="عنوان کامل کالا..."
                  className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-medium"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
                    کد کالا
                  </label>
                  <input
                    type="text"
                    value={code}
                    onChange={(e) => setCode(e.target.value)}
                    placeholder="101"
                    className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-medium text-center"
                  />
                </div>

                <div>
                  <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
                    واحد سنجش
                  </label>
                  <select
                    value={unit}
                    onChange={(e) => setUnit(e.target.value)}
                    className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-medium"
                  >
                    {UNITS.map(u => (
                      <option key={u} value={u}>{u}</option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
                    قیمت خرید (تومان)
                  </label>
                  <input
                    type="number"
                    value={buyPrice}
                    onChange={(e) => setBuyPrice(e.target.value)}
                    placeholder="0"
                    className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-bold"
                  />
                </div>

                <div>
                  <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
                    قیمت فروش (تومان) *
                  </label>
                  <input
                    type="number"
                    required
                    value={sellPrice}
                    onChange={(e) => setSellPrice(e.target.value)}
                    placeholder="0"
                    className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-bold text-blue-600"
                  />
                </div>
              </div>

              <div>
                <label className="block font-bold text-slate-700 dark:text-slate-300 mb-1">
                  موجودی اولیه
                </label>
                <input
                  type="number"
                  value={stock}
                  onChange={(e) => setStock(e.target.value)}
                  placeholder="10"
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
                  placeholder="توضیحات تکمیلی کالا..."
                  className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-slate-800 dark:text-white font-medium"
                />
              </div>

              <div className="flex gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  className="flex-1 py-3 rounded-2xl border border-slate-200 font-bold"
                >
                  انصراف
                </button>
                <button
                  type="submit"
                  className="flex-1 py-3 rounded-2xl bg-indigo-600 text-white font-bold shadow"
                >
                  ذخیره کالا
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

    </div>
  );
}
