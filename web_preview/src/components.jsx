import { useEffect, useMemo, useState } from 'react'
import {
  Check,
  ClipboardList,
  Search,
  Package,
  Truck,
  BadgeCheck,
  X,
  ExternalLink,
  Copy,
  Box,
} from 'lucide-react'
import { toFa, toEn, money } from './utils'
import { carrierById, isCancelled, statusIndex } from './store'

const ICONS = [ClipboardList, Search, Package, Truck, BadgeCheck]

export function StatusBadge({ status, statuses }) {
  const map = {
    pending: { label: 'در انتظار پرداخت', cls: 'bg-slate-100 text-slate-600' },
    processing: { label: statuses[0]?.label || 'در حال انجام', cls: 'bg-teal-50 text-teal-700' },
    'on-hold': { label: statuses[1]?.label || 'در حال بررسی', cls: 'bg-amber-50 text-amber-700' },
    packing: { label: statuses[2]?.label || 'بسته‌بندی', cls: 'bg-violet-50 text-violet-700' },
    completed: { label: statuses[3]?.label || 'تکمیل شده', cls: 'bg-blue-50 text-blue-700' },
    delivered: { label: statuses[4]?.label || 'تحویل شده', cls: 'bg-emerald-50 text-emerald-700' },
    cancelled: { label: 'لغو شده', cls: 'bg-rose-50 text-rose-700' },
    failed: { label: 'ناموفق', cls: 'bg-rose-50 text-rose-700' },
    refunded: { label: 'مسترد شده', cls: 'bg-slate-100 text-slate-600' },
  }
  const s = map[status] || map.processing
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-[11px] font-semibold ${s.cls}`}>
      {s.label}
    </span>
  )
}

export function ProgressBar({ order, statuses, compact = false }) {
  if (isCancelled(order.status)) {
    return (
      <div className="rounded-2xl border border-rose-100 bg-rose-50 px-4 py-3 text-sm text-rose-700">
        این سفارش لغو یا نامعتبر است و نوار پیشرفت برای آن نمایش داده نمی‌شود.
      </div>
    )
  }
  const idx = statusIndex(order.status)
  return (
    <div className={compact ? '' : 'rounded-2xl border border-saina-100 bg-white p-5 shadow-soft'}>
      {!compact && (
        <div className="mb-4 flex items-center justify-between">
          <div className="text-sm font-bold text-slate-800">نوار پیشرفت سفارش</div>
          <div className="text-[11px] text-slate-400">سفارش {toFa(order.id)} · {toFa(order.date)}</div>
        </div>
      )}
      <div className="relative flex items-start justify-between gap-1">
        <div className="absolute right-[10%] left-[10%] top-[18px] h-[3px] rounded-full bg-slate-200" />
        <div
          className="absolute right-[10%] top-[18px] h-[3px] rounded-full bg-gradient-to-l from-saina-500 to-emerald-500 transition-all duration-700"
          style={{ width: `${(idx / (statuses.length - 1)) * 80}%` }}
        />
        {statuses.map((st, i) => {
          const Icon = ICONS[i] || Box
          const done = i < idx
          const current = i === idx
          const title = order.history?.[st.key] || order.history?.[st.wc]
          return (
            <div key={st.key} className="relative z-[1] flex w-1/5 flex-col items-center text-center">
              <div
                title={title ? `تغییر وضعیت: ${toFa(title)}` : st.hint}
                className={[
                  'flex h-9 w-9 items-center justify-center rounded-full border-2 bg-white transition-all',
                  done ? 'border-saina-600 bg-saina-600 text-white' : '',
                  current ? 'border-saina-600 text-saina-700 saina-pulse' : '',
                  !done && !current ? 'border-slate-200 text-slate-400' : '',
                ].join(' ')}
                style={done ? { background: st.color, borderColor: st.color } : current ? { borderColor: st.color, color: st.color } : undefined}
              >
                {done ? <Check size={16} /> : current ? (
                  <span className="relative flex h-5 w-5 items-center justify-center">
                    <span className="absolute inset-0 rounded-full border-2 border-current border-t-transparent saina-spin" />
                    <Icon size={12} />
                  </span>
                ) : (
                  <Icon size={15} />
                )}
              </div>
              <div className={`mt-2 text-[11px] font-semibold leading-5 ${current ? 'text-saina-800' : done ? 'text-slate-700' : 'text-slate-400'}`}>
                {st.label}
              </div>
              {title && !compact && (
                <div className="mt-0.5 hidden text-[10px] text-slate-400 sm:block">{toFa(title)}</div>
              )}
            </div>
          )
        })}
      </div>
    </div>
  )
}

export function Toast({ toast, onClose }) {
  useEffect(() => {
    if (!toast) return undefined
    const t = setTimeout(onClose, 3200)
    return () => clearTimeout(t)
  }, [toast, onClose])
  if (!toast) return null
  return (
    <div className="fixed bottom-5 left-1/2 z-[80] -translate-x-1/2 saina-in">
      <div className="rounded-2xl bg-slate-900 px-4 py-3 text-sm text-white shadow-xl">
        {toast}
      </div>
    </div>
  )
}

export function MathCaptcha({ onChange, refreshKey }) {
  const puzzle = useMemo(() => {
    const a = 2 + Math.floor(Math.random() * 7)
    const b = 1 + Math.floor(Math.random() * 8)
    return { a, b, sum: a + b }
  }, [refreshKey])
  const [val, setVal] = useState('')
  useEffect(() => {
    onChange(toEn(val) === String(puzzle.sum))
  }, [val, puzzle, onChange])
  return (
    <div className="flex items-center gap-3 rounded-xl border border-slate-200 bg-slate-50 px-3 py-2">
      <div className="min-w-[92px] rounded-lg bg-white px-3 py-2 text-center text-sm font-bold tracking-widest text-saina-800 shadow-sm">
        {toFa(puzzle.a)} + {toFa(puzzle.b)} = ؟
      </div>
      <input
        value={val}
        onChange={(e) => setVal(e.target.value)}
        className="h-10 w-24 rounded-lg border border-slate-200 bg-white px-3 text-center text-sm outline-none focus:border-saina-500"
        placeholder="پاسخ"
        inputMode="numeric"
      />
    </div>
  )
}

export function RecaptchaBox({ onChange }) {
  const [ok, setOk] = useState(false)
  return (
    <button
      type="button"
      onClick={() => {
        const next = !ok
        setOk(next)
        onChange(next)
      }}
      className="flex items-center gap-3 rounded-xl border border-slate-200 bg-slate-50 px-3 py-2 text-sm"
    >
      <span className={`flex h-5 w-5 items-center justify-center rounded-sm border ${ok ? 'border-saina-600 bg-saina-600 text-white' : 'border-slate-300 bg-white'}`}>
        {ok && <Check size={12} />}
      </span>
      من ربات نیستم
      <span className="mr-auto text-[10px] text-slate-400">reCAPTCHA v2 · آزمایشی</span>
    </button>
  )
}

export function CarrierModal({ order, onClose }) {
  const c = carrierById(order.tracking.carrier)
  const events = buildCarrierEvents(order, c)
  return (
    <div className="fixed inset-0 z-[70] flex items-end justify-center bg-slate-900/40 p-3 sm:items-center" onClick={onClose}>
      <div className="w-full max-w-lg overflow-hidden rounded-3xl bg-white shadow-2xl saina-in" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between border-b border-slate-100 px-5 py-4">
          <div>
            <div className="text-sm font-bold">پیگیری از {c.trackName}</div>
            <div className="text-[11px] text-slate-400">کد مرسوله به‌صورت خودکار در فرم قرار گرفت</div>
          </div>
          <button onClick={onClose} className="rounded-full p-1 text-slate-400 hover:bg-slate-100"><X size={18} /></button>
        </div>
        <div className="px-5 py-4">
          <div className="mb-4 flex items-center justify-between rounded-2xl bg-slate-50 px-4 py-3">
            <div>
              <div className="text-[11px] text-slate-400">کد رهگیری</div>
              <div className="font-mono text-sm font-bold tracking-wide">{order.tracking.code}</div>
            </div>
            <button
              className="inline-flex items-center gap-1 rounded-lg border border-slate-200 px-2 py-1 text-[11px]"
              onClick={() => navigator.clipboard.writeText(order.tracking.code)}
            >
              <Copy size={12} /> کپی
            </button>
          </div>
          <ol className="space-y-3">
            {events.map((ev, i) => (
              <li key={i} className="flex gap-3">
                <div className="flex flex-col items-center">
                  <span className={`h-2.5 w-2.5 rounded-full ${i === 0 ? 'bg-saina-600' : 'bg-slate-300'}`} />
                  {i < events.length - 1 && <span className="mt-1 h-full w-px bg-slate-200" />}
                </div>
                <div className="pb-2">
                  <div className="text-sm font-semibold text-slate-800">{ev.title}</div>
                  <div className="text-[11px] text-slate-400">{toFa(ev.time)} · {ev.place}</div>
                </div>
              </li>
            ))}
          </ol>
          <a
            href={carrierUrl(c.id, order.tracking.code)}
            target="_blank"
            rel="noreferrer"
            className="mt-4 inline-flex w-full items-center justify-center gap-2 rounded-xl bg-saina-700 py-2.5 text-sm font-semibold text-white"
          >
            مشاهده در سایت {c.trackName} <ExternalLink size={14} />
          </a>
        </div>
      </div>
    </div>
  )
}

function carrierUrl(id, code) {
  if (id === 'post' || id === 'post-custom') return `https://tracking.post.ir/?id=${encodeURIComponent(code)}`
  if (id === 'chapar') return `https://chapar.ir/`
  if (id === 'tipax') return `https://tipaxco.com/`
  return '#'
}

function buildCarrierEvents(order, c) {
  const list = [
    { title: 'پذیرش مرسوله در مبدأ', time: order.tracking.shipDate, place: 'انبار فروشگاه' },
    { title: `تحویل به ${c.name}`, time: order.tracking.shipDate, place: order.customer.city },
  ]
  if (statusIndex(order.status) >= 3) list.push({ title: 'خروج از مرکز تجزیه', time: order.tracking.shipDate, place: 'هاب پستی' })
  if (statusIndex(order.status) >= 4) list.push({ title: 'تحویل به گیرنده', time: order.tracking.deliveryDate, place: order.customer.city })
  else list.push({ title: 'در مسیر توزیع', time: order.tracking.deliveryDate, place: `مقصد: ${order.customer.city}` })
  return list.reverse()
}

export function OrderResult({ order, settings, onTrackCarrier, onConfirm }) {
  const c = carrierById(order.tracking.carrier)
  const hasCode = Boolean(order.tracking.code)
  return (
    <div className="saina-in overflow-hidden rounded-3xl border border-saina-100 bg-white shadow-card">
      <div className="flex flex-wrap items-center justify-between gap-3 border-b border-slate-100 bg-gradient-to-l from-saina-50 to-white px-5 py-4">
        <div>
          <div className="text-xs text-slate-500">شماره سفارش</div>
          <div className="text-lg font-black text-saina-900">#{toFa(order.id)}</div>
        </div>
        <div className="text-left">
          <StatusBadge status={order.status} statuses={settings.statuses} />
          <div className="mt-1 text-[11px] text-slate-400">ثبت: {toFa(order.date)}</div>
        </div>
      </div>
      <div className="space-y-4 p-5">
        {settings.progressBarEnabled && <ProgressBar order={order} statuses={settings.statuses} />}
        <div className="grid gap-3 sm:grid-cols-2">
          <Info label="خریدار" value={order.customer.name} />
          <Info label="شهر" value={order.customer.city} />
          <Info label="موبایل" value={toFa(order.customer.mobile)} />
          <Info label="ایمیل" value={order.customer.email} />
        </div>
        <div className="rounded-2xl border border-slate-100">
          <div className="border-b border-slate-100 px-4 py-2 text-xs font-bold text-slate-500">اقلام سفارش</div>
          {order.items.map((it, i) => (
            <div key={i} className="flex items-center justify-between px-4 py-2 text-sm">
              <span>{it.name} <span className="text-slate-400">× {toFa(it.qty)}</span></span>
              <span className="font-semibold">{money(it.price * it.qty)}</span>
            </div>
          ))}
          <div className="flex items-center justify-between border-t border-slate-100 px-4 py-2 text-sm font-bold">
            <span>جمع کل · {order.payment}</span>
            <span>{money(order.total)}</span>
          </div>
        </div>
        <div className="rounded-2xl bg-slate-50 p-4">
          <div className="mb-2 text-xs font-bold text-slate-500">جزئیات ارسال</div>
          {hasCode ? (
            <div className="grid gap-2 sm:grid-cols-2">
              <Info label="کد رهگیری" value={order.tracking.code} mono />
              <Info label="سیستم حمل‌ونقل" value={c.name} />
              <Info label="تاریخ ارسال" value={toFa(order.tracking.shipDate || '—')} />
              <Info label="تاریخ تقریبی تحویل" value={toFa(order.tracking.deliveryDate || '—')} />
            </div>
          ) : (
            <div className="text-sm text-slate-500">هنوز کد رهگیری پستی برای این سفارش ثبت نشده است.</div>
          )}
        </div>
        {hasCode && (
          <div className="flex flex-wrap gap-2">
            {(c.id === 'post' || c.id === 'post-custom') && (
              <button onClick={() => onTrackCarrier(order)} className="rounded-xl bg-[#0f766e] px-3 py-2 text-xs font-bold text-white">پیگیری از پست</button>
            )}
            {c.id === 'chapar' && (
              <button onClick={() => onTrackCarrier(order)} className="rounded-xl bg-amber-600 px-3 py-2 text-xs font-bold text-white">پیگیری از چاپار</button>
            )}
            {c.id === 'tipax' && (
              <button onClick={() => onTrackCarrier(order)} className="rounded-xl bg-blue-700 px-3 py-2 text-xs font-bold text-white">پیگیری از تیپاکس</button>
            )}
            {settings.confirmDelivery && order.status === 'completed' && (
              <button onClick={() => onConfirm(order)} className="rounded-xl border border-emerald-200 bg-emerald-50 px-3 py-2 text-xs font-bold text-emerald-700">
                کالا را تحویل گرفتم
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  )
}

function Info({ label, value, mono }) {
  return (
    <div>
      <div className="text-[11px] text-slate-400">{label}</div>
      <div className={`text-sm font-semibold text-slate-800 ${mono ? 'font-mono tracking-wide' : ''}`}>{value}</div>
    </div>
  )
}
