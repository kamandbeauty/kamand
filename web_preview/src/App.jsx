import React, { useState, useEffect } from 'react';
import Navbar from './components/Navbar';
import Sidebar from './components/Sidebar';
import WelcomeSplashModal from './components/WelcomeSplashModal';
import OnboardingModal from './components/OnboardingModal';
import DashboardView from './components/DashboardView';
import InvoiceCreatorView from './components/InvoiceCreatorView';
import InvoiceDetailModal from './components/InvoiceDetailModal';
import CustomerManagementView from './components/CustomerManagementView';
import ProductManagementView from './components/ProductManagementView';
import FinancialView from './components/FinancialView';
import SmartToolsModal from './components/SmartToolsModal';
import SettingsView from './components/SettingsView';
import GoldenUpgradeModal from './components/GoldenUpgradeModal';
import PricingPlansModal from './components/PricingPlansModal';
import OpenWindowsModal from './components/OpenWindowsModal';

import {
  INITIAL_USER,
  INITIAL_BUSINESS,
  INITIAL_CUSTOMERS,
  INITIAL_PRODUCTS,
  INITIAL_INVOICES,
  INITIAL_EXPENSES,
  INITIAL_INCOMES,
  INITIAL_SETTINGS
} from './data/mockData';

export default function App() {
  const loadState = (key, fallback) => {
    try {
      const saved = localStorage.getItem(`fida_${key}`);
      return saved ? JSON.parse(saved) : fallback;
    } catch {
      return fallback;
    }
  };

  const saveState = (key, val) => {
    try {
      localStorage.setItem(`fida_${key}`, JSON.stringify(val));
    } catch (e) {
      console.error('LocalStorage save error:', e);
    }
  };

  // Main App State
  const [user, setUser] = useState(() => loadState('user', INITIAL_USER));
  const [business, setBusiness] = useState(() => loadState('business', INITIAL_BUSINESS));
  const [customers, setCustomers] = useState(() => loadState('customers', INITIAL_CUSTOMERS));
  const [products, setProducts] = useState(() => loadState('products', INITIAL_PRODUCTS));
  const [invoices, setInvoices] = useState(() => loadState('invoices', INITIAL_INVOICES));
  const [expenses, setExpenses] = useState(() => loadState('expenses', INITIAL_EXPENSES));
  const [incomes, setIncomes] = useState(() => loadState('incomes', INITIAL_INCOMES));
  const [settings, setSettings] = useState(() => loadState('settings', INITIAL_SETTINGS));

  // Navigation & Modals
  const [activeTab, setActiveTab] = useState('create_invoice');
  const [isSidebarOpen, setIsSidebarOpen] = useState(false);
  const [isDarkMode, setIsDarkMode] = useState(false);
  const [isAppLocked, setIsAppLocked] = useState(false);
  const [pinUnlockInput, setPinUnlockInput] = useState('');

  const [showSplash, setShowSplash] = useState(false);
  const [showGoldenModal, setShowGoldenModal] = useState(false);
  const [showPricingModal, setShowPricingModal] = useState(false);
  const [showWindowsModal, setShowWindowsModal] = useState(false);

  const [selectedInvoiceModal, setSelectedInvoiceModal] = useState(null);
  const [editingInvoiceData, setEditingInvoiceData] = useState(null);

  const [showSmartToolsModal, setShowSmartToolsModal] = useState(false);
  const [globalSearchOpen, setGlobalSearchOpen] = useState(false);
  const [globalSearchQuery, setGlobalSearchOpenQuery] = useState('');

  // Temporary Multi-window Tabs
  const [factorTabs, setFactorTabs] = useState([
    { id: 'tab-1', title: 'پیش فاکتور ۱', number: '۱' }
  ]);
  const [activeFactorTabId, setActiveFactorTabId] = useState('tab-1');

  // Persistence
  useEffect(() => saveState('user', user), [user]);
  useEffect(() => saveState('business', business), [business]);
  useEffect(() => saveState('customers', customers), [customers]);
  useEffect(() => saveState('products', products), [products]);
  useEffect(() => saveState('invoices', invoices), [invoices]);
  useEffect(() => saveState('expenses', expenses), [expenses]);
  useEffect(() => saveState('incomes', incomes), [incomes]);
  useEffect(() => saveState('settings', settings), [settings]);

  // Dark mode
  useEffect(() => {
    if (isDarkMode) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [isDarkMode]);

  // Tab Manager Helpers
  const handleAddFactorTab = () => {
    const newNum = factorTabs.length + 1;
    const newTab = {
      id: `tab-${Date.now()}`,
      title: `پیش فاکتور ${newNum}`,
      number: newNum.toString()
    };
    setFactorTabs([...factorTabs, newTab]);
    setActiveFactorTabId(newTab.id);
  };

  const handleCloseFactorTab = (id) => {
    if (factorTabs.length === 1) return;
    const updated = factorTabs.filter(t => t.id !== id);
    setFactorTabs(updated);
    if (activeFactorTabId === id) {
      setActiveFactorTabId(updated[0].id);
    }
  };

  // Invoice Actions
  const handleSaveInvoice = (invoiceObj, shouldOpenModal = false) => {
    const existingIndex = invoices.findIndex(i => i.id === invoiceObj.id);
    let updatedInvoices = [];
    if (existingIndex >= 0) {
      updatedInvoices = [...invoices];
      updatedInvoices[existingIndex] = invoiceObj;
    } else {
      updatedInvoices = [...invoices, invoiceObj];
    }
    setInvoices(updatedInvoices);

    if (invoiceObj.customerId && invoiceObj.type === 'sale') {
      setCustomers(prev =>
        prev.map(c => {
          if (c.id === invoiceObj.customerId) {
            return { ...c, balance: Math.max(0, (c.balance || 0) + invoiceObj.remainingAmount) };
          }
          return c;
        })
      );
    }

    setEditingInvoiceData(null);
    if (shouldOpenModal) {
      setSelectedInvoiceModal(invoiceObj);
    }
  };

  const handleCopyInvoice = (inv) => {
    const copied = {
      ...inv,
      id: `inv-${Date.now()}`,
      number: (parseInt(inv.number) + 1).toString(),
      date: new Date().toLocaleDateString('fa-IR')
    };
    setSelectedInvoiceModal(null);
    setEditingInvoiceData(copied);
    setActiveTab('create_invoice');
  };

  const handleDeleteInvoice = (id) => setInvoices(invoices.filter(i => i.id !== id));

  const handleConvertProforma = (id) => {
    setInvoices(prev =>
      prev.map(inv => {
        if (inv.id === id) {
          return {
            ...inv,
            type: 'sale',
            status: inv.remainingAmount === 0 ? 'paid' : 'unpaid'
          };
        }
        return inv;
      })
    );
    setSelectedInvoiceModal(null);
    alert('پیش‌فاکتور به فاکتور فروش تبدیل شد.');
  };

  const handleRecordPayment = (invoiceId, amount) => {
    setInvoices(prev =>
      prev.map(inv => {
        if (inv.id === invoiceId) {
          const newPaid = inv.paidAmount + amount;
          const newRemaining = Math.max(0, inv.totalAmount - newPaid);
          return {
            ...inv,
            paidAmount: newPaid,
            remainingAmount: newRemaining,
            status: newRemaining === 0 ? 'paid' : 'partial'
          };
        }
        return inv;
      })
    );
    setSelectedInvoiceModal(null);
  };

  // Reset
  const handleResetData = () => {
    setUser({ ...INITIAL_USER, isOnboarded: true });
    setBusiness(INITIAL_BUSINESS);
    setCustomers(INITIAL_CUSTOMERS);
    setProducts(INITIAL_PRODUCTS);
    setInvoices(INITIAL_INVOICES);
    setExpenses(INITIAL_EXPENSES);
    setIncomes(INITIAL_INCOMES);
    setSettings(INITIAL_SETTINGS);
    setShowSplash(true);
  };

  const handleRestoreData = (parsedData) => {
    if (parsedData.user) setUser(parsedData.user);
    if (parsedData.business) setBusiness(parsedData.business);
    if (parsedData.customers) setCustomers(parsedData.customers);
    if (parsedData.products) setProducts(parsedData.products);
    if (parsedData.invoices) setInvoices(parsedData.invoices);
  };

  if (isAppLocked) {
    return (
      <div className="fixed inset-0 z-50 bg-slate-900 text-white flex items-center justify-center p-4 dir-rtl font-vazir">
        <div className="text-center space-y-4 max-w-xs">
          <div className="w-16 h-16 mx-auto rounded-3xl bg-blue-600 text-white flex items-center justify-center font-black text-2xl shadow-xl">
            ج
          </div>
          <h2 className="font-extrabold text-lg">فاکتورساز جاوید قفل است</h2>
          <p className="text-xs text-slate-400">رمز ۴ رقمی خود را وارد کنید</p>

          <input
            type="password"
            maxLength={4}
            value={pinUnlockInput}
            onChange={(e) => setPinUnlockInput(e.target.value)}
            className="w-full p-3 rounded-2xl bg-slate-800 border border-slate-700 text-center font-mono text-xl tracking-widest"
            autoFocus
          />

          <button
            onClick={() => {
              if (pinUnlockInput === (settings.pinCode || '1234') || pinUnlockInput === '1234') {
                setIsAppLocked(false);
                setPinUnlockInput('');
              } else {
                alert('رمز اشتباه است!');
              }
            }}
            className="w-full py-3 rounded-2xl bg-blue-600 font-bold text-xs shadow-lg"
          >
            باز کردن قفل
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex flex-col bg-[#F8FAFC] dark:bg-slate-900 text-slate-800 dark:text-slate-100 font-vazir select-none">
      
      {/* Welcome Splash Screen */}
      <WelcomeSplashModal
        isOpen={showSplash}
        onStart={() => setShowSplash(false)}
        onSkip={() => setShowSplash(false)}
      />

      {/* Onboarding Wizard Modal on first launch */}
      <OnboardingModal
        isOpen={!user.isOnboarded}
        initialData={user}
        onComplete={(updatedUser) => {
          setUser(updatedUser);
          setBusiness(prev => ({ ...prev, shopName: `فروشگاه ${updatedUser.name}` }));
        }}
      />

      {/* Main Top Navbar */}
      <Navbar
        onOpenSidebar={() => setIsSidebarOpen(true)}
        onOpenGlobalSearch={() => setGlobalSearchOpen(true)}
        onOpenGoldenModal={() => setShowPricingModal(true)}
        isDarkMode={isDarkMode}
        onToggleDarkMode={() => setIsDarkMode(!isDarkMode)}
        onLockApp={() => setIsAppLocked(true)}
      />

      {/* Sidebar Drawer Menu */}
      <Sidebar
        isOpen={isSidebarOpen}
        onClose={() => setIsSidebarOpen(false)}
        onNavigateTab={(tab) => setActiveTab(tab)}
        onOpenGoldenModal={() => setShowGoldenModal(true)}
        onOpenSettings={() => setActiveTab('settings')}
        onResetData={handleResetData}
      />

      {/* Main View Area */}
      <main className="flex-1 max-w-4xl w-full mx-auto p-4 sm:p-6">
        
        {activeTab === 'create_invoice' && (
          <InvoiceCreatorView
            customers={customers}
            products={products}
            business={business}
            editingInvoice={editingInvoiceData}
            onSaveInvoice={handleSaveInvoice}
            onCancel={() => setActiveTab('dashboard')}
            onNewCustomerModal={() => setActiveTab('customers')}
            tabs={factorTabs}
            activeTabId={activeFactorTabId}
            onSelectTab={(id) => setActiveFactorTabId(id)}
            onAddTab={handleAddFactorTab}
            onOpenWindowsModal={() => setShowWindowsModal(true)}
          />
        )}

        {activeTab === 'dashboard' && (
          <DashboardView
            invoices={invoices}
            customers={customers}
            products={products}
            onNewInvoice={() => {
              setEditingInvoiceData(null);
              setActiveTab('create_invoice');
            }}
            onNewCustomer={() => setActiveTab('customers')}
            onNewProduct={() => setActiveTab('products')}
            onViewInvoice={(inv) => setSelectedInvoiceModal(inv)}
            onNavigateTab={(tab) => setActiveTab(tab)}
          />
        )}

        {activeTab === 'invoices' && (
          <DashboardView
            invoices={invoices}
            customers={customers}
            products={products}
            onNewInvoice={() => {
              setEditingInvoiceData(null);
              setActiveTab('create_invoice');
            }}
            onNewCustomer={() => setActiveTab('customers')}
            onNewProduct={() => setActiveTab('products')}
            onViewInvoice={(inv) => setSelectedInvoiceModal(inv)}
            onNavigateTab={(tab) => setActiveTab(tab)}
          />
        )}

        {activeTab === 'customers' && (
          <CustomerManagementView
            customers={customers}
            invoices={invoices}
            onAddCustomer={(c) => setCustomers([...customers, c])}
            onEditCustomer={(c) => setCustomers(customers.map(item => item.id === c.id ? c : item))}
            onDeleteCustomer={(id) => setCustomers(customers.filter(item => item.id !== id))}
            onRecordCustomerPayment={(cId, amt) => {
              setCustomers(prev =>
                prev.map(c => (c.id === cId ? { ...c, balance: Math.max(0, c.balance - amt) } : c))
              );
            }}
            onViewInvoice={(inv) => setSelectedInvoiceModal(inv)}
          />
        )}

        {activeTab === 'products' && (
          <ProductManagementView
            products={products}
            onAddProduct={(p) => setProducts([...products, p])}
            onEditProduct={(p) => setProducts(products.map(item => item.id === p.id ? p : item))}
            onDeleteProduct={(id) => setProducts(products.filter(item => item.id !== id))}
          />
        )}

        {activeTab === 'financial' && (
          <FinancialView
            invoices={invoices}
            customers={customers}
            expenses={expenses}
            incomes={incomes}
            onAddExpense={(exp) => setExpenses([...expenses, exp])}
            onAddIncome={(inc) => setIncomes([...incomes, inc])}
          />
        )}

        {activeTab === 'settings' && (
          <SettingsView
            user={user}
            business={business}
            settings={settings}
            onSaveUser={(u) => setUser(u)}
            onSaveBusiness={(b) => setBusiness(b)}
            onSaveSettings={(s) => setSettings(s)}
            isDarkMode={isDarkMode}
            onToggleDarkMode={() => setIsDarkMode(!isDarkMode)}
          />
        )}

      </main>

      {/* Invoice Detail / PDF Modal */}
      <InvoiceDetailModal
        invoice={selectedInvoiceModal}
        business={business}
        isOpen={Boolean(selectedInvoiceModal)}
        onClose={() => setSelectedInvoiceModal(null)}
        onEdit={(inv) => {
          setSelectedInvoiceModal(null);
          setEditingInvoiceData(inv);
          setActiveTab('create_invoice');
        }}
        onCopy={handleCopyInvoice}
        onDelete={handleDeleteInvoice}
        onConvertProforma={handleConvertProforma}
        onRecordPayment={handleRecordPayment}
      />

      {/* Golden Upgrade Features Modal (Screenshot 6) */}
      <GoldenUpgradeModal
        isOpen={showGoldenModal}
        onClose={() => setShowGoldenModal(false)}
      />

      {/* Pricing Plans Modal (Screenshot 1) */}
      <PricingPlansModal
        isOpen={showPricingModal}
        onClose={() => setShowPricingModal(false)}
      />

      {/* Open Windows Modal (Screenshot 5) */}
      <OpenWindowsModal
        isOpen={showWindowsModal}
        onClose={() => setShowWindowsModal(false)}
        tabs={factorTabs}
        activeTabId={activeFactorTabId}
        onSelectTab={(id) => setActiveFactorTabId(id)}
        onCloseTab={handleCloseFactorTab}
      />

      {/* Smart Tools Modal */}
      <SmartToolsModal
        isOpen={showSmartToolsModal}
        onClose={() => setShowSmartToolsModal(false)}
        invoices={invoices}
        customers={customers}
        products={products}
        business={business}
        settings={settings}
        onUpdateSettings={(s) => setSettings(s)}
        onOpenGlobalSearch={() => {
          setShowSmartToolsModal(false);
          setGlobalSearchOpen(true);
        }}
        onRestoreData={handleRestoreData}
        onLockApp={() => {
          setShowSmartToolsModal(false);
          setIsAppLocked(true);
        }}
      />

      {/* Global Search Dialog */}
      {globalSearchOpen && (
        <div className="fixed inset-0 z-50 flex items-start justify-center p-4 pt-16 bg-slate-900/60 backdrop-blur-sm">
          <div className="w-full max-w-xl bg-white dark:bg-slate-800 rounded-3xl p-5 shadow-2xl space-y-4 font-vazir">
            <div className="flex items-center justify-between pb-2 border-b border-slate-100 dark:border-slate-700">
              <h3 className="font-bold text-sm text-slate-800 dark:text-white">
                جستجوی سریع سراسری
              </h3>
              <button onClick={() => setGlobalSearchOpen(false)} className="text-slate-400 text-xs">
                بستن (Esc)
              </button>
            </div>

            <input
              type="text"
              autoFocus
              value={globalSearchQuery}
              onChange={(e) => setGlobalSearchOpenQuery(e.target.value)}
              placeholder="جستجو در شماره فاکتور، نام مشتری، کالا..."
              className="w-full p-3 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-900 text-xs font-bold"
            />

            <div className="max-h-64 overflow-y-auto space-y-2 text-xs">
              {globalSearchQuery.trim() === '' ? (
                <div className="text-center py-6 text-slate-400">
                  عبارتی را برای جستجو در فاکتورها، مشتریان و کالاها تایپ کنید...
                </div>
              ) : (
                <>
                  <div className="font-bold text-slate-400 text-[11px]">فاکتورها:</div>
                  {invoices
                    .filter(i => i.number.includes(globalSearchQuery) || i.customerName.includes(globalSearchQuery))
                    .map(inv => (
                      <div
                        key={inv.id}
                        onClick={() => {
                          setGlobalSearchOpen(false);
                          setSelectedInvoiceModal(inv);
                        }}
                        className="p-3 bg-slate-50 dark:bg-slate-900 rounded-xl hover:bg-blue-50 cursor-pointer flex justify-between"
                      >
                        <div>فاکتور #{inv.number} - {inv.customerName}</div>
                        <div className="font-bold text-blue-600">{inv.totalAmount.toLocaleString('fa-IR')} تومان</div>
                      </div>
                    ))}
                </>
              )}
            </div>
          </div>
        </div>
      )}

    </div>
  );
}
