import { useMemo, useState } from 'react'
import { Hash, Mail, Phone, Search } from 'lucide-react'
import { CarrierModal, MathCaptcha, OrderResult, RecaptchaBox } from '../components'
import { findOrders, getState, upsertTracking } from '../store'
import { toEn } from '../utils'

const TABS = [
  { id: 'order', label: 'شماره سفارش', icon: Hash },
  { id: 'mobile', label: 'موبایل', icon: Phone },
  { id: 'email', label: 'ایمیل', icon: Mail },
  { id: 'combo', label: 'ترکیبی', icon: Search },
]

export default function TrackPage({ onToast, onState }) {
  const settings = getState().settings
  const tabs = TABS.filter((t) => {
    if (t.id === 'order') return settings.searchOrder !== false
    if (t.id === 'mobile') return settings.searchMobile !== false
    if (t.id === 'email') return settings.searchEmail !== false
    return true
  })
  const [tab, setTab] = useState(tabs[0]?.id || 'order')
  const [orderId, setOrderId] = useState('')
  const [mobile, setMobile] = useState('')
  const [email, setEmail] = useState('')
  const [captchaOk, setCaptchaOk] = useState(settings.captcha === 'none')
  const [refresh, setRefresh] = useState(0)
  const [results, setResults] = useState(null)
  const [carrierOrder, setCarrierOrder] = useState(null)
  const [loading, setLoading] = useState(false)

  const hint = useMemo(() => {
    if (tab === 'order') return 'نمونه: ۱۰۴۲'
    if (tab === 'mobile') return 'نمونه: ۰۹۱۲۱۲۳۴۵۶۷'
    if (tab === 'email') return 'نمونه: sara@example.com'
    return 'شماره سفارش + موبایل یا ایمیل'
  }, [tab])

  function search(e) {
    e?.preventDefault()
    if (settings.captcha !== 'none' && !captchaOk) {
      onToast('لطفاً کپچا را تکمیل کنید')
      return
    }
    const payload = {
      orderId: tab === 'mobile' || tab === 'email' ? '' : orderId,
      mobile: tab === 'order' || tab === 'email' ? '' : mobile,
      email: tab === 'order' || tab === 'mobile' ? '' : email,
    }
    if (tab === 'combo' && settings.trackMode === 'order_mobile' && (!orderId || !mobile)) {
      onToast('شماره سفارش و موبایل هر دو لازم است')
      return
    }
    if (tab === 'combo' && settings.trackMode === 'order_email' && (!orderId || !email)) {
      onToast('شماره سفارش و ایمیل هر دو لازم است')
      return
    }
    if (!payload.orderId && !payload.mobile && !payload.email) {
      onToast('یکی از فیلدهای پیگیری را وارد کنید')
      return
    }
    setLoading(true)
    setTimeout(() => {
      const mode = settings.trackMode === 'any' && tab !== 'combo' ? 'any' : settings.trackMode
      const list = findOrders(payload, tab === 'combo' ? (mobile ? 'order_mobile' : 'order_email') : mode)
      setResults(list)
      setRefresh((n) => n + 1)
      setCaptchaOk(settings.captcha === 'none')
      setLoading(false)
    }, settings.ajaxSearch ? 420 : 80)
  }

  function confirmDelivery(order) {
    upsertTracking(order.id, order.tracking, { status: 'delivered' })
    onState(getState())
    setResults(findOrders({ orderId: String(order.id) }))
    onToast('وضعیت سفارش به «تحویل شده» تغییر کرد')
  }

  return (
    <div className="mx-auto max-w-3xl px-4 py-8">
      <div className="mb-6 text-center">
        <div className="text-xs font-bold text-saina-700">{settings.shopName}</div>
        <h1 className="mt-1 text-2xl font-black text-slate-900">پیگیری سفارش</h1>
        <p className="mt-2 text-sm text-slate-500">{settings.formPlaceholder || 'وضعیت مرسوله را با شماره سفارش، موبایل یا ایمیل ببینید.'}</p>
      </div>

      <form onSubmit={search} className="rounded-3xl border border-saina-100 bg-white p-4 shadow-card sm:p-6">
        <div className="mb-4 grid grid-cols-2 gap-2 sm:grid-cols-4">
          {tabs.map((t) => (
            <button
              key={t.id}
              type="button"
              onClick={() => setTab(t.id)}
              className={`flex items-center justify-center gap-1 rounded-xl px-2 py-2 text-xs font-bold ${tab === t.id ? 'bg-saina-700 text-white' : 'bg-slate-50 text-slate-600'}`}
            >
              <t.icon size={14} /> {t.label}
            </button>
          ))}
        </div>
        <div className="grid gap-3">
          {(tab === 'order' || tab === 'combo') && (
            <Field label="شماره سفارش" value={orderId} onChange={setOrderId} placeholder="مثلاً ۱۰۴۲" />
          )}
          {(tab === 'mobile' || tab === 'combo') && (
            <Field label="شماره موبایل" value={mobile} onChange={setMobile} placeholder="۰۹۱۲۱۲۳۴۵۶۷" />
          )}
          {(tab === 'email' || tab === 'combo') && (
            <Field label="ایمیل سفارش" value={email} onChange={setEmail} placeholder="you@email.com" dir="ltr" />
          )}
        </div>
        <div className="mt-3 text-[11px] text-slate-400">{hint}</div>
        <div className="mt-4">
          {settings.captcha === 'math' && <MathCaptcha refreshKey={refresh} onChange={setCaptchaOk} />}
          {settings.captcha === 'recaptcha2' && <RecaptchaBox onChange={setCaptchaOk} />}
          {settings.captcha === 'recaptcha3' && (
            <div className="text-[11px] text-slate-400">reCAPTCHA v3 در پس‌زمینه فعال است.</div>
          )}
        </div>
        <button
          disabled={loading}
          style={{ background: settings.colorFormBtn || '#0f766e' }}
          className="mt-4 w-full rounded-2xl py-3 text-sm font-bold text-white disabled:opacity-60"
        >
          {loading ? 'در حال جستجو…' : 'پیگیری سفارش'}
        </button>
      </form>

      {results && (
        <div className="mt-6 space-y-4">
          {results.length === 0 && (
            <div className="rounded-3xl border border-rose-100 bg-rose-50 px-5 py-8 text-center text-sm text-rose-700">
              سفارشی با این مشخصات یافت نشد.
            </div>
          )}
          {results.map((o) => (
            <OrderResult
              key={o.id}
              order={o}
              settings={settings}
              onTrackCarrier={setCarrierOrder}
              onConfirm={confirmDelivery}
            />
          ))}
        </div>
      )}

      {carrierOrder && <CarrierModal order={carrierOrder} onClose={() => setCarrierOrder(null)} />}
    </div>
  )
}

function Field({ label, value, onChange, placeholder, dir }) {
  return (
    <label className="block">
      <span className="mb-1 block text-xs font-bold text-slate-600">{label}</span>
      <input
        value={value}
        dir={dir || 'rtl'}
        onChange={(e) => onChange(toEn(e.target.value) === e.target.value ? e.target.value : e.target.value)}
        placeholder={placeholder}
        className="h-11 w-full rounded-xl border border-slate-200 bg-slate-50 px-3 text-sm outline-none focus:border-saina-500 focus:bg-white"
      />
    </label>
  )
}
