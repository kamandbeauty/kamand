import React, { useState } from 'react';
import {
  Plus,
  ArrowRight,
  Menu,
  FolderPlus,
  SlidersHorizontal,
  Edit,
  Trash2,
  X,
  ChevronDown
} from 'lucide-react';
import { UNITS, formatCurrency, toPersianDigits } from '../utils/helpers';

export default function ProductManagementView({
  products,
  onAddProduct,
  onEditProduct,
  onDeleteProduct,
  onBack
}) {
  const [showModal, setShowModal] = useState(false);
  const [editingProduct, setEditingProduct] = useState(null);

  // Form State (Screenshot 4: Name, Price, Unit)
  const [name, setName] = useState('');
  const [unit, setUnit] = useState('عدد');
  const [sellPrice, setSellPrice] = useState('');

  const openAddModal = () => {
    setEditingProduct(null);
    setName('');
    setUnit('عدد');
    setSellPrice('');
    setShowModal(true);
  };

  const openEditModal = (p) => {
    setEditingProduct(p);
    setName(p.name || '');
    setUnit(p.unit || 'عدد');
    setSellPrice((p.sellPrice || 0).toString());
    setShowModal(true);
  };

  const handleSave = (e) => {
    e.preventDefault();
    if (!name.trim()) {
      alert('لطفاً نام آیتم را وارد کنید.');
      return;
    }

    const productData = {
      id: editingProduct?.id || `p-${Date.now()}`,
      code: editingProduct?.code || (products.length + 101).toString(),
      name: name.trim(),
      unit,
      buyPrice: editingProduct?.buyPrice || 0,
      sellPrice: parseFloat(sellPrice) || 0,
      stock: editingProduct?.stock || 99,
      notes: editingProduct?.notes || ''
    };

    if (editingProduct) {
      onEditProduct(productData);
    } else {
      onAddProduct(productData);
    }

    setShowModal(false);
  };

  return (
    <div className="space-y-4 max-w-xl mx-auto pb-24 animate-fade-in font-vazir relative min-h-[80vh]">
      
      {/* Top Header Bar (Screenshot 6) */}
      <div className="flex items-center justify-between py-2 border-b border-slate-200/60 dark:border-slate-700">
        <button onClick={() => onBack ? onBack() : window.history.back()} className="p-1.5 text-slate-700 dark:text-slate-200" title="بازگشت">
          <ArrowRight className="w-5 h-5" />
        </button>

        <h2 className="font-extrabold text-lg text-slate-900 dark:text-white">
          آیتم‌ها
        </h2>

        <div className="w-5" />
      </div>

      {/* Action Bar: Create Category + Filter Icons (Screenshot 6) */}
      <div className="flex items-center justify-between gap-3 pt-1">
        <div className="flex items-center gap-2">
          <button className="p-2 rounded-2xl bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300">
            <SlidersHorizontal className="w-4 h-4" />
          </button>
        </div>

        <button
          onClick={() => alert('دسته‌بندی جدید ایجاد شد.')}
          className="px-4 py-2 rounded-2xl bg-slate-100/90 dark:bg-slate-800 text-sky-600 dark:text-sky-400 font-bold text-xs flex items-center gap-1.5 hover:bg-slate-200 transition"
        >
          <Plus className="w-4 h-4" />
          <span>ایجاد دسته‌بندی</span>
        </button>
      </div>

      {/* Products List or Empty State Folder Box (Screenshot 6) */}
      {products.length === 0 ? (
        <div className="my-12 p-8 bg-slate-100/80 dark:bg-slate-800 rounded-3xl text-center space-y-4 border border-slate-200/60 dark:border-slate-700">
          {/* Yellow Folder Icon */}
          <div className="w-24 h-24 mx-auto bg-amber-400/20 text-amber-500 rounded-3xl flex items-center justify-center text-5xl shadow-xs">
            📁
          </div>

          <h3 className="font-bold text-slate-700 dark:text-slate-200 text-sm">
            هنوز هیچ آیتمی اضافه نشده!
          </h3>

          <button
            onClick={openAddModal}
            className="text-sky-600 dark:text-sky-400 font-bold text-xs hover:underline block mx-auto"
          >
            ایجاد آیتم
          </button>
        </div>
      ) : (
        <div className="space-y-3 pt-2">
          {products.map((product) => (
            <div
              key={product.id}
              className="p-4 rounded-3xl bg-white dark:bg-slate-800 border border-slate-200/60 dark:border-slate-700 flex items-center justify-between shadow-xs hover:border-sky-400 transition"
            >
              <div className="text-right">
                <h4 className="font-bold text-sm text-slate-900 dark:text-white">
                  {product.name}
                </h4>
                <div className="text-[11px] text-slate-400 mt-0.5">
                  واحد: {product.unit}
                </div>
              </div>

              <div className="flex items-center gap-3">
                <div className="font-bold text-sm text-sky-600 dark:text-sky-400">
                  {formatCurrency(product.sellPrice)}
                </div>

                <div className="flex items-center gap-1">
                  <button
                    onClick={() => openEditModal(product)}
                    className="p-1.5 rounded-lg text-slate-400 hover:text-sky-600"
                  >
                    <Edit className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => {
                      if (window.confirm(`آیا از حذف آیتم ${product.name} اطمینان دارید؟`)) {
                        onDeleteProduct(product.id);
                      }
                    }}
                    className="p-1.5 rounded-lg text-slate-400 hover:text-rose-600"
                  >
                    <Trash2 className="w-4 h-4" />
                  </button>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Floating Action Button (FAB) Bottom Right (Screenshot 6) */}
      <button
        onClick={openAddModal}
        className="fixed bottom-6 left-6 z-30 w-14 h-14 rounded-full bg-sky-500 hover:bg-sky-600 text-white shadow-xl flex items-center justify-center text-2xl transition active:scale-95"
        title="ایجاد آیتم"
      >
        <Plus className="w-7 h-7" />
      </button>

      {/* Create Item Modal (Screenshot 4) */}
      {showModal && (
        <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-3 bg-slate-900/60 backdrop-blur-sm font-vazir">
          <div className="w-full max-w-md bg-white dark:bg-slate-800 rounded-3xl p-5 shadow-2xl space-y-4 border border-slate-100 dark:border-slate-700 animate-slide-up">
            
            <h3 className="font-extrabold text-base text-slate-900 dark:text-white text-center pb-2 border-b border-slate-100 dark:border-slate-700">
              {editingProduct ? 'ویرایش آیتم' : 'ایجاد آیتم'}
            </h3>

            <form onSubmit={handleSave} className="space-y-3 text-xs">
              {/* Name Field */}
              <div>
                <input
                  type="text"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="نام"
                  className="w-full p-3.5 rounded-2xl bg-slate-100 dark:bg-slate-900 border border-slate-200 dark:border-slate-700 text-right font-medium text-xs outline-none focus:border-sky-500"
                />
              </div>

              {/* Price & Unit Row (Screenshot 4) */}
              <div className="grid grid-cols-2 gap-2">
                
                {/* Unit Select */}
                <div className="relative">
                  <select
                    value={unit}
                    onChange={(e) => setUnit(e.target.value)}
                    className="w-full p-3.5 rounded-2xl bg-slate-100 dark:bg-slate-900 border border-slate-200 dark:border-slate-700 text-center font-medium text-xs outline-none appearance-none"
                  >
                    {UNITS.map(u => (
                      <option key={u} value={u}>{u}</option>
                    ))}
                  </select>
                  <ChevronDown className="w-4 h-4 absolute left-3 top-4 text-slate-400 pointer-events-none" />
                </div>

                {/* Price Field */}
                <div>
                  <input
                    type="number"
                    value={sellPrice}
                    onChange={(e) => setSellPrice(e.target.value)}
                    placeholder="قیمت"
                    className="w-full p-3.5 rounded-2xl bg-slate-100 dark:bg-slate-900 border border-slate-200 dark:border-slate-700 text-center font-bold text-xs outline-none focus:border-sky-500"
                  />
                </div>

              </div>

              {/* Bottom Actions (Screenshot 4: Cancel left, Create right) */}
              <div className="flex gap-2 pt-2">
                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  className="flex-1 py-3 rounded-2xl text-slate-700 dark:text-slate-300 font-bold text-xs hover:bg-slate-100 dark:hover:bg-slate-700 transition"
                >
                  انصراف
                </button>

                <button
                  type="submit"
                  className="flex-1 py-3 rounded-2xl bg-sky-500 hover:bg-sky-600 text-white font-bold text-xs shadow-md transition active:scale-98"
                >
                  {editingProduct ? 'ذخیره' : 'ایجاد'}
                </button>
              </div>

            </form>

          </div>
        </div>
      )}

    </div>
  );
}
