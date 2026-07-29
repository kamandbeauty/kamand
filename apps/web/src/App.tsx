import React, { useEffect, useState } from 'react';
import { can, subscriptionNotice, syncStatus } from '@javid/core';
import { createEmptyDB, loadDB, queue, saveDB, type DB } from './store';
import { Banner } from './ui';
import { Dashboard } from './pages/Dashboard';
import { Invoices } from './pages/Invoices';
import { Parties } from './pages/Parties';
import { Products } from './pages/Products';
import { Reports } from './pages/Reports';
import { Treasury } from './pages/Treasury';
import { Settings } from './pages/Settings';
import { Tax } from './pages/Tax';

type Page = 'dashboard' | 'invoices' | 'parties' | 'products' | 'treasury' | 'tax' | 'reports' | 'settings';

const NAV: { group: string; items: { id: Page; label: string; icon: string }[] }[] = [
  {
    group: '',
    items: [{ id: 'dashboard', label: 'داشبورد', icon: '🏠' }],
  },
  {
    group: 'عملیات',
    items: [
      { id: 'invoices', label: 'فاکتورها', icon: '🧾' },
      { id: 'parties', label: 'اشخاص', icon: '👥' },
      { id: 'products', label: 'کالاها', icon: '📦' },
      { id: 'treasury', label: 'خزانه و چک', icon: '💳' },
      { id: 'tax', label: 'سامانهٔ مؤدیان', icon: '🏛' },
    ],
  },
  {
    group: 'تحلیل',
    items: [
      { id: 'reports', label: 'گزارش‌ها', icon: '📊' },
      { id: 'settings', label: 'تنظیمات', icon: '⚙️' },
    ],
  },
];

const TITLES: Record<Page, string> = {
  dashboard: 'داشبورد',
  invoices: 'فاکتورها',
  parties: 'اشخاص',
  products: 'کالاها و خدمات',
  treasury: 'خزانه‌داری و چک',
  tax: 'سامانهٔ مؤدیان',
  reports: 'گزارش‌ها',
  settings: 'تنظیمات',
};

export default function App() {
  const [db, setDBState] = useState<DB | null>(null);
  const [page, setPage] = useState<Page>('dashboard');
  const [menuOpen, setMenuOpen] = useState(false);
  const [online, setOnline] = useState(navigator.onLine);
  const [dismissed, setDismissed] = useState(false);

  useEffect(() => {
    setDBState(loadDB() ?? createEmptyDB());
  }, []);

  useEffect(() => {
    const on = () => setOnline(true);
    const off = () => setOnline(false);
    window.addEventListener('online', on);
    window.addEventListener('offline', off);
    return () => {
      window.removeEventListener('online', on);
      window.removeEventListener('offline', off);
    };
  }, []);

  function setDB(next: DB) {
    setDBState(next);
    saveDB(next);
  }

  if (!db) {
    return <div style={{ padding: 40, textAlign: 'center' }}>در حال بارگذاری…</div>;
  }

  const now = new Date();
  const notice = subscriptionNotice(db.subscription, now);
  const canWrite = can('write', db.subscription, now);
  const sync = syncStatus(online, queue);

  const dot = sync.state === 'synced' ? 'green' : sync.state === 'error' ? 'red' : 'amber';

  return (
    <div className="app">
      <aside className={`sidebar ${menuOpen ? 'open' : ''}`}>
        <div className="brand">
          <h1>جاوید</h1>
          <span>{db.business.name}</span>
        </div>
        <nav className="nav">
          {NAV.map((g, i) => (
            <div className="nav-group" key={i}>
              {g.group && <div className="nav-label">{g.group}</div>}
              {g.items.map((item) => (
                <button
                  key={item.id}
                  className={`nav-item ${page === item.id ? 'active' : ''}`}
                  onClick={() => { setPage(item.id); setMenuOpen(false); }}
                >
                  <span className="ico">{item.icon}</span>
                  {item.label}
                </button>
              ))}
            </div>
          ))}
        </nav>
      </aside>

      <div className="main">
        <header className="topbar no-print">
          <button
            className="btn btn-sm btn-ghost"
            style={{ display: 'none' }}
            id="menu-btn"
            onClick={() => setMenuOpen((v) => !v)}
          >☰</button>
          <h2>{TITLES[page]}</h2>
          <div className="spacer" />
          <span className="sync-pill" title={sync.message}>
            <span className={`dot ${dot}`} />
            {sync.state === 'offline' ? 'آفلاین' : sync.state === 'synced' ? 'همگام' : `${sync.pendingCount} در صف`}
          </span>
        </header>

        <main className="content">
          {!canWrite && !dismissed && (
            <Banner
              tone="critical"
              title="اشتراک شما به پایان رسیده است"
              action={
                <button className="btn btn-sm" onClick={() => setDismissed(true)}>بستن</button>
              }
            >
              {notice.message}
            </Banner>
          )}

          {canWrite && notice.level !== 'none' && !dismissed && (
            <Banner
              tone={notice.level === 'critical' ? 'critical' : notice.level === 'warning' ? 'warning' : 'info'}
              action={<button className="btn btn-sm" onClick={() => setDismissed(true)}>بستن</button>}
            >
              {notice.message}
            </Banner>
          )}

          {page === 'dashboard' && <Dashboard db={db} onNav={(p) => setPage(p as Page)} />}
          {page === 'invoices' && <Invoices db={db} setDB={setDB} canWrite={canWrite} />}
          {page === 'parties' && <Parties db={db} setDB={setDB} canWrite={canWrite} />}
          {page === 'products' && <Products db={db} setDB={setDB} canWrite={canWrite} />}
          {page === 'treasury' && <Treasury db={db} setDB={setDB} canWrite={canWrite} />}
          {page === 'tax' && <Tax db={db} setDB={setDB} canWrite={canWrite} />}
          {page === 'reports' && <Reports db={db} />}
          {page === 'settings' && <Settings db={db} setDB={setDB} />}
        </main>
      </div>
    </div>
  );
}
