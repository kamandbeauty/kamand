import { useMemo, useState } from 'react'
import { RotateCcw } from 'lucide-react'
import { Toast } from './components'
import { getState, resetDemo } from './store'
import LandingPage from './pages/LandingPage'
import TrackPage from './pages/TrackPage'
import AccountPage from './pages/AccountPage'
import AdminApp from './pages/AdminApp'

const NAV = [
  { id: 'home', label: 'معرفی افزونه' },
  { id: 'track', label: 'پیگیری سفارش' },
  { id: 'account', label: 'حساب کاربری' },
  { id: 'admin', label: 'پیشخوان مدیر' },
]

export default function App() {
  const [view, setView] = useState('home')
  const [tick, setTick] = useState(0)
  const [toast, setToast] = useState('')
  const state = useMemo(() => getState(), [tick])

  function refresh() {
    setTick((n) => n + 1)
  }

  return (
    <div className="min-h-screen bg-[#F4F7F6]">
      <header className="sticky top-0 z-40 border-b border-saina-100 bg-white/90 backdrop-blur">
        <div className="mx-auto flex max-w-6xl items-center gap-3 px-4 py-3">
          <button onClick={() => setView('home')} className="flex items-center gap-2">
            <img src="/saina-logo.png" alt="ساینا" className="h-9 w-9 rounded-xl shadow-sm" />
            <div className="text-right">
              <div className="text-sm font-black text-saina-900">ساینا</div>
              <div className="text-[10px] text-slate-400">پیگیری سفارشات ووکامرس</div>
            </div>
          </button>
          <nav className="mr-auto flex items-center gap-1 overflow-x-auto">
            {NAV.map((n) => (
              <button
                key={n.id}
                onClick={() => setView(n.id)}
                className={`whitespace-nowrap rounded-full px-3 py-1.5 text-xs font-bold ${view === n.id ? 'bg-saina-700 text-white' : 'text-slate-600 hover:bg-slate-100'}`}
              >
                {n.label}
              </button>
            ))}
            <button
              onClick={() => {
                resetDemo()
                refresh()
                setToast('داده‌های نمونه بازنشانی شد')
              }}
              className="mr-1 inline-flex items-center gap-1 rounded-full px-2 py-1.5 text-[11px] text-slate-400 hover:text-slate-700"
              title="بازنشانی دمو"
            >
              <RotateCcw size={12} />
            </button>
          </nav>
        </div>
      </header>

      {view === 'home' && <LandingPage onOpen={setView} />}
      {view === 'track' && <TrackPage onToast={setToast} onState={refresh} />}
      {view === 'account' && <AccountPage onToast={setToast} onState={refresh} />}
      {view === 'admin' && <AdminApp state={state} onToast={setToast} onState={refresh} />}

      <Toast toast={toast} onClose={() => setToast('')} />
    </div>
  )
}
