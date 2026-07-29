import React, { useEffect, useState } from 'react';
import { can, subscriptionNotice, syncStatus } from '@javid/core';
import { flushDB, initStorage, queue, type DB } from './store';
import {
  listWorkspaces, openActiveWorkspace, saveWorkspace, switchWorkspace,
  type WorkspaceEntry,
} from './workspaces';
import { startAutoSync } from './syncEngine';
import { Banner } from './ui';
import { GlobalSearch, useSearchShortcut } from './GlobalSearch';
import { Dashboard } from './pages/Dashboard';
import { Invoices } from './pages/Invoices';
import { Parties } from './pages/Parties';
import { Products } from './pages/Products';
import { Reports } from './pages/Reports';
import { Treasury } from './pages/Treasury';
import { Settings } from './pages/Settings';
import { Tax } from './pages/Tax';
import { Account } from './pages/Account';
import { Audit } from './pages/Audit';
import { YearEnd } from './pages/YearEnd';
import { Ledger } from './pages/Ledger';
import { Analytics } from './pages/Analytics';

type Page = 'dashboard' | 'invoices' | 'parties' | 'products' | 'treasury' | 'tax' | 'reports' | 'ledger' | 'analytics' | 'audit' | 'yearend' | 'account' | 'settings';

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
      { id: 'ledger', label: 'دفتر و اسناد', icon: '📒' },
      { id: 'reports', label: 'گزارش‌ها', icon: '📊' },
      { id: 'analytics', label: 'تحلیل فروش', icon: '📈' },
      { id: 'audit', label: 'ممیزی و دوره', icon: '📜' },
      { id: 'yearend', label: 'بستن سال', icon: '🔒' },
      { id: 'account', label: 'حساب و همگام‌سازی', icon: '☁️' },
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
  ledger: 'دفتر و اسناد',
  reports: 'گزارش‌ها',
  analytics: 'تحلیل فروش',
  audit: 'ردّ ممیزی و دورهٔ مالی',
  yearend: 'بستن سال مالی',
  account: 'حساب کاربری و همگام‌سازی',
  settings: 'تنظیمات',
};

export default function App() {
  const [db, setDBState] = useState<DB | null>(null);
  const [workspaces, setWorkspaces] = useState<WorkspaceEntry[]>([]);
  const [switching, setSwitching] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const [page, setPage] = useState<Page>('dashboard');
  const [menuOpen, setMenuOpen] = useState(false);
  const [online, setOnline] = useState(navigator.onLine);
  const [dismissed, setDismissed] = useState(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      await initStorage();
      const { db: opened } = await openActiveWorkspace();
      const list = await listWorkspaces();
      if (!cancelled) {
        setDBState(opened);
        setWorkspaces(list);
      }
    })();
    return () => { cancelled = true; };
  }, []);

  /** جابه‌جایی بین کسب‌وکارها */
  async function changeWorkspace(id: string) {
    if (!db || id === db.business.id) return;
    setSwitching(true);
    try {
      await flushDB();
      const next = await switchWorkspace(id);
      if (next) {
        setDBState(next);
        setPage('dashboard');
      }
    } finally {
      setSwitching(false);
    }
  }

  async function refreshWorkspaces() {
    setWorkspaces(await listWorkspaces());
  }

  // همگام‌سازی خودکار — فقط اگر کاربر آن را پیکربندی کرده باشد
  const dbRef = React.useRef<DB | null>(null);
  dbRef.current = db;

  useEffect(() => {
    return startAutoSync({
      getDB: () => dbRef.current,
      applyDB: (next) => { setDBState(next); void saveWorkspace(next); },
    });
  }, []);

  // نوشتن معلق پیش از بستن صفحه از دست نرود
  useEffect(() => {
    const flush = () => { void flushDB(); };
    window.addEventListener('beforeunload', flush);
    window.addEventListener('pagehide', flush);
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'hidden') flush();
    });
    return () => {
      window.removeEventListener('beforeunload', flush);
      window.removeEventListener('pagehide', flush);
    };
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
    void saveWorkspace(next);
  }

  if (!db) {
    return <div style={{ padding: 40, textAlign: 'center' }}>در حال بارگذاری…</div>;
  }

  const now = new Date();
  const notice = subscriptionNotice(db.subscription, now);
  const canWrite = can('write', db.subscription, now);
  const sync = syncStatus(online, queue);
  useSearchShortcut(() => setSearchOpen(true));

  const dot = sync.state === 'synced' ? 'green' : sync.state === 'error' ? 'red' : 'amber';

  return (
    <div className="app">
      <aside className={`sidebar ${menuOpen ? 'open' : ''}`}>
        <div className="brand">
          <h1>جاوید</h1>
          {workspaces.length > 1 ? (
            <select
              className="select"
              style={{ marginTop: 6, fontSize: 12, padding: '5px 8px' }}
              value={db.business.id}
              disabled={switching}
              onChange={(e) => { void changeWorkspace(e.target.value); }}
              aria-label="انتخاب کسب‌وکار"
            >
              {workspaces.map((w) => (
                <option key={w.id} value={w.id}>{w.name}</option>
              ))}
            </select>
          ) : (
            <span>{db.business.name}</span>
          )}
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
          <button
            className="btn btn-sm"
            onClick={() => setSearchOpen(true)}
            title="جستجوی سراسری (Ctrl+K)"
          >🔍 جستجو</button>
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
          {page === 'ledger' && <Ledger db={db} setDB={setDB} />}
          {page === 'reports' && <Reports db={db} />}
          {page === 'analytics' && <Analytics db={db} />}
          {page === 'audit' && <Audit db={db} setDB={setDB} />}
          {page === 'yearend' && <YearEnd db={db} setDB={setDB} />}
          {page === 'account' && <Account db={db} setDB={setDB} />}
          {page === 'settings' && (
            <Settings db={db} setDB={setDB} onWorkspacesChanged={refreshWorkspaces} onSwitch={changeWorkspace} />
          )}
        </main>
      </div>

      <GlobalSearch
        db={db}
        open={searchOpen}
        onClose={() => setSearchOpen(false)}
        onNavigate={(p) => setPage(p as Page)}
      />
    </div>
  );
}
