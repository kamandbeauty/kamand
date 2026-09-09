import { useMemo, useState } from 'react'
import {
  Boxes,
  ClipboardList,
  FileSpreadsheet,
  MessageSquare,
  Package,
  Save,
  Search,
  Settings,
  Truck,
} from 'lucide-react'
import { ProgressBar, StatusBadge } from '../components'
import {
  applySms,
  autoFillDates,
  CARRIERS,
  carrierById,
  getState,
  logSms,
  saveState,
  upsertTracking,
} from '../store'
import { csvParse, downloadText, money, toFa, todayJalali } from '../utils'

const MENUS = [
  { id: 'orders', label: 'سفارشات', icon: ClipboardList },
  { id: 'bulk', label: 'درج گروهی کد رهگیری', icon: Boxes },
  { id: 'import', label: 'درون‌ریزی اکسل', icon: FileSpreadsheet },
  { id: 'sms', label: 'پیامک و شورتکد', icon: MessageSquare },
  { id: 'settings', label: 'تنظیمات ساینا', icon: Settings },
]

export default function AdminApp({ onToast, onState, state }) {
  const [page, setPage] = useState('orders')
  const [selected, setSelected] = useState(null)
  return (
    <div className="wp-like min-h-[calc(100vh-56px)]">
      <div className="mx-auto flex max-w-6xl gap-0 px-0 sm:px-4 sm:py-6">
        <aside className="hidden w-56 shrink-0 rounded-s-3xl bg-[#1d2327] p-3 text-slate-200 sm:block">
          <div className="mb-4 flex items-center gap-2 px-2 pt-2">
            <img src="/saina-logo.png" alt="" className="h-8 w-8 rounded-lg" />
            <div className="text-xs font-bold text-white">ساینا ترک‌اوردر</div>
          </div>
          {MENUS.map((m) => (
            <button
              key={m.id}
              onClick={() => { setPage(m.id); setSelected(null) }}
              className={`mb-1 flex w-full items-center gap-2 rounded-xl px-3 py-2 text-xs ${page === m.id ? 'bg-saina-700 text-white' : 'hover:bg-white/5'}`}
            >
              <m.icon size={14} /> {m.label}
            </button>
          ))}
        </aside>
        <div className="min-w-0 flex-1 bg-white sm:rounded-e-3xl sm:p-5">
          <div className="flex gap-2 overflow-x-auto border-b border-slate-100 p-3 sm:hidden">
            {MENUS.map((m) => (
              <button key={m.id} onClick={() => { setPage(m.id); setSelected(null) }} className={`whitespace-nowrap rounded-full px-3 py-1 text-[11px] font-bold ${page === m.id ? 'bg-saina-700 text-white' : 'bg-slate-100'}`}>
                {m.label}
              </button>
            ))}
          </div>
          {page === 'orders' && !selected && <OrdersList state={state} onOpen={setSelected} />}
          {page === 'orders' && selected && (
            <OrderEdit
              order={state.orders.find((o) => o.id === selected) || selected}
              settings={state.settings}
              onBack={() => setSelected(null)}
              onToast={onToast}
              onState={onState}
            />
          )}
          {page === 'bulk' && <BulkPage state={state} onToast={onToast} onState={onState} />}
          {page === 'import' && <ImportPage state={state} onToast={onToast} onState={onState} />}
          {page === 'sms' && <SmsPage state={state} onToast={onToast} onState={onState} />}
          {page === 'settings' && <SettingsPage state={state} onToast={onToast} onState={onState} />}
        </div>
      </div>
    </div>
  )
}

function OrdersList({ state, onOpen }) {
  const [q, setQ] = useState('')
  const list = useMemo(() => {
    const s = q.trim()
    if (!s) return state.orders
    return state.orders.filter((o) =>
      String(o.id).includes(s) ||
      o.customer.name.includes(s) ||
      o.customer.mobile.includes(s) ||
      (o.tracking.code || '').includes(s)
    )
  }, [q, state.orders])
  return (
    <div className="p-4 sm:p-0">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
        <h2 className="text-lg font-black">سفارشات ووکامرس</h2>
        <div className="relative">
          <Search size={14} className="absolute right-3 top-2.5 text-slate-400" />
          <input value={q} onChange={(e) => setQ(e.target.value)} placeholder="جستجوی سفارش، موبایل یا کد رهگیری" className="h-9 w-64 rounded-lg border border-slate-200 pr-8 pl-3 text-xs outline-none" />
        </div>
      </div>
      <div className="overflow-x-auto rounded-2xl border border-slate-100">
        <table className="w-full min-w-[720px] text-right text-xs">
          <thead className="bg-slate-50 text-slate-500">
            <tr>
              <th className="p-3">سفارش</th>
              <th className="p-3">مشتری</th>
              <th className="p-3">وضعیت</th>
              <th className="p-3">ارسال</th>
              <th className="p-3">مبلغ</th>
            </tr>
          </thead>
          <tbody>
            {list.map((o) => {
              const c = carrierById(o.tracking.carrier)
              return (
                <tr key={o.id} className="border-t border-slate-100 hover:bg-saina-50/40">
                  <td className="p-3">
                    <button onClick={() => onOpen(o.id)} className="font-bold text-saina-800">#{toFa(o.id)}</button>
                    <div className="text-[10px] text-slate-400">{toFa(o.date)}</div>
                  </td>
                  <td className="p-3">
                    <div>{o.customer.name}</div>
                    <div className="text-[10px] text-slate-400">{toFa(o.customer.mobile)}</div>
                  </td>
                  <td className="p-3"><StatusBadge status={o.status} statuses={state.settings.statuses} /></td>
                  <td className="p-3">
                    <div className="group relative inline-flex">
                      <span className={`flex h-8 w-8 items-center justify-center rounded-lg ${o.tracking.code ? 'bg-saina-50 text-saina-700' : 'bg-slate-100 text-slate-400'}`}>
                        <Truck size={14} />
                      </span>
                      <div className="pointer-events-none absolute right-10 top-0 z-10 hidden w-48 rounded-xl bg-slate-900 p-3 text-[10px] text-white group-hover:block">
                        {o.tracking.code ? (
                          <>
                            <div>کد: {o.tracking.code}</div>
                            <div>{c.name}</div>
                            <div>ارسال: {toFa(o.tracking.shipDate || '—')}</div>
                          </>
                        ) : 'کد رهگیری ثبت نشده'}
                      </div>
                    </div>
                  </td>
                  <td className="p-3 font-semibold">{money(o.total)}</td>
                </tr>
              )
            })}
          </tbody>
        </table>
      </div>
    </div>
  )
}

function OrderEdit({ order, settings, onBack, onToast, onState }) {
  const [form, setForm] = useState({
    code: order.tracking.code || '',
    carrier: order.tracking.carrier || settings.defaultCarrier,
    shipDate: order.tracking.shipDate || '',
    deliveryDate: order.tracking.deliveryDate || '',
    status: order.status,
    sendSms: true,
  })
  function set(k, v) { setForm((f) => ({ ...f, [k]: v })) }
  function save() {
    const tracking = { code: form.code, carrier: form.carrier, shipDate: form.shipDate, deliveryDate: form.deliveryDate }
    const next = upsertTracking(order.id, tracking, { status: form.status })
    if (form.sendSms && settings.smsEnabled && form.code) {
      const fresh = next.orders.find((o) => o.id === order.id)
      const text = applySms(fresh, settings.smsTemplate)
      logSms(fresh, text)
    }
    onState(getState())
    onToast(form.sendSms && form.code ? 'جزئیات ارسال ذخیره و پیامک شبیه‌سازی شد' : 'جزئیات ارسال ذخیره شد')
  }
  return (
    <div className="p-4 sm:p-0">
      <button onClick={onBack} className="mb-3 text-xs text-saina-700">← بازگشت به سفارشات</button>
      <div className="grid gap-4 lg:grid-cols-[1fr_320px]">
        <div className="rounded-2xl border border-slate-100 p-4">
          <h3 className="mb-3 font-black">سفارش #{toFa(order.id)} · {order.customer.name}</h3>
          <div className="mb-4 text-xs text-slate-500">{order.customer.city} · {toFa(order.customer.mobile)} · {order.customer.email}</div>
          {order.items.map((it, i) => (
            <div key={i} className="flex justify-between border-b border-slate-50 py-2 text-sm">
              <span>{it.name} × {toFa(it.qty)}</span><span>{money(it.price * it.qty)}</span>
            </div>
          ))}
          <div className="mt-4"><ProgressBar order={{ ...order, status: form.status, tracking: form }} statuses={settings.statuses} compact /></div>
        </div>
        <div className="rounded-2xl border border-saina-100 bg-saina-50/40 p-4">
          <div className="mb-3 flex items-center gap-2 text-sm font-bold text-saina-900">
            <Package size={16} /> جزئیات ارسال ساینا
          </div>
          <label className="mb-2 block text-[11px] font-bold">کد رهگیری</label>
          <input value={form.code} onChange={(e) => set('code', e.target.value)} className="mb-3 h-10 w-full rounded-lg border px-3 font-mono text-xs" />
          <label className="mb-2 block text-[11px] font-bold">سیستم حمل‌ونقل</label>
          <select value={form.carrier} onChange={(e) => {
            const carrier = e.target.value
            const dates = autoFillDates(carrier)
            setForm((f) => ({ ...f, carrier, shipDate: f.shipDate || dates.shipDate, deliveryDate: f.deliveryDate || dates.deliveryDate }))
          }} className="mb-3 h-10 w-full rounded-lg border px-3 text-xs">
            {CARRIERS.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
          <div className="mb-3 grid grid-cols-2 gap-2">
            <div>
              <label className="mb-1 block text-[11px] font-bold">تاریخ ارسال (شمسی)</label>
              <input value={form.shipDate} onChange={(e) => set('shipDate', e.target.value)} placeholder={todayJalali()} className="h-10 w-full rounded-lg border px-2 text-xs" />
            </div>
            <div>
              <label className="mb-1 block text-[11px] font-bold">تاریخ تحویل</label>
              <input value={form.deliveryDate} onChange={(e) => set('deliveryDate', e.target.value)} className="h-10 w-full rounded-lg border px-2 text-xs" />
            </div>
          </div>
          <label className="mb-2 block text-[11px] font-bold">وضعیت سفارش</label>
          <select value={form.status} onChange={(e) => set('status', e.target.value)} className="mb-3 h-10 w-full rounded-lg border px-3 text-xs">
            {settings.statuses.map((s) => <option key={s.key} value={s.key}>{s.label}</option>)}
            <option value="cancelled">لغو شده</option>
          </select>
          <label className="mb-4 flex items-center gap-2 text-xs">
            <input type="checkbox" checked={form.sendSms} onChange={(e) => set('sendSms', e.target.checked)} />
            ارسال پیامک (افزودن شورتکدها به پیامک وضعیت)
          </label>
          <button onClick={save} className="flex w-full items-center justify-center gap-2 rounded-xl bg-saina-700 py-2.5 text-sm font-bold text-white">
            <Save size={14} /> ذخیره جزئیات ارسال
          </button>
        </div>
      </div>
    </div>
  )
}

function BulkPage({ state, onToast, onState }) {
  const [rows, setRows] = useState(() =>
    state.orders.map((o) => ({
      id: o.id,
      name: o.customer.name,
      code: o.tracking.code,
      carrier: o.tracking.carrier || state.settings.defaultCarrier,
      shipDate: o.tracking.shipDate || todayJalali(),
      deliveryDate: o.tracking.deliveryDate || '',
      status: o.status,
    }))
  )
  const [page, setPage] = useState(0)
  const per = 6
  const slice = rows.slice(page * per, page * per + per)
  function saveAll() {
    rows.forEach((r) => {
      upsertTracking(r.id, { code: r.code, carrier: r.carrier, shipDate: r.shipDate, deliveryDate: r.deliveryDate }, { status: r.status })
    })
    onState(getState())
    onToast('کدهای رهگیری گروهی ذخیره شد')
  }
  return (
    <div className="p-4 sm:p-0">
      <div className="mb-3 flex items-center justify-between">
        <h2 className="text-lg font-black">درج کد رهگیری به‌صورت دسته جمعی</h2>
        <button onClick={saveAll} className="rounded-xl bg-saina-700 px-4 py-2 text-xs font-bold text-white">ذخیره همه</button>
      </div>
      <p className="mb-4 text-xs text-slate-500">پیش‌فرض حامل: {carrierById(state.settings.defaultCarrier).name} · تاریخ‌ها شمسی هستند.</p>
      <div className="space-y-2">
        {slice.map((r, idx) => (
          <div key={r.id} className="grid gap-2 rounded-xl border border-slate-100 p-3 sm:grid-cols-6">
            <div className="text-xs font-bold text-saina-800">#{toFa(r.id)}<div className="font-normal text-slate-400">{r.name}</div></div>
            <input value={r.code} placeholder="کد رهگیری" onChange={(e) => setRows((all) => all.map((x) => x.id === r.id ? { ...x, code: e.target.value } : x))} className="h-9 rounded-lg border px-2 font-mono text-[11px] sm:col-span-2" />
            <select value={r.carrier} onChange={(e) => setRows((all) => all.map((x) => x.id === r.id ? { ...x, carrier: e.target.value } : x))} className="h-9 rounded-lg border px-2 text-[11px]">
              {CARRIERS.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
            </select>
            <input value={r.shipDate} onChange={(e) => setRows((all) => all.map((x) => x.id === r.id ? { ...x, shipDate: e.target.value } : x))} className="h-9 rounded-lg border px-2 text-[11px]" />
            <select value={r.status} onChange={(e) => setRows((all) => all.map((x) => x.id === r.id ? { ...x, status: e.target.value } : x))} className="h-9 rounded-lg border px-2 text-[11px]">
              {state.settings.statuses.map((s) => <option key={s.key} value={s.key}>{s.label}</option>)}
            </select>
          </div>
        ))}
      </div>
      <div className="mt-3 flex gap-2">
        <button disabled={page === 0} onClick={() => setPage((p) => p - 1)} className="rounded-lg border px-3 py-1 text-xs disabled:opacity-40">قبلی</button>
        <button disabled={(page + 1) * per >= rows.length} onClick={() => setPage((p) => p + 1)} className="rounded-lg border px-3 py-1 text-xs disabled:opacity-40">بعدی</button>
      </div>
    </div>
  )
}

function ImportPage({ state, onToast, onState }) {
  const [text, setText] = useState('order_id,tracking_code,carrier,ship_date,delivery_date\n1045,994400112233445566778899,post,1404/06/16,1404/06/19\n1035,CHP-991122,chapar,1404/06/03,1404/06/06')
  function apply() {
    const rows = csvParse(text)
    let n = 0
    rows.forEach((r) => {
      const id = Number(r.order_id || r.order || r.id)
      if (!id) return
      upsertTracking(id, {
        code: r.tracking_code || r.code,
        carrier: r.carrier || state.settings.defaultCarrier,
        shipDate: r.ship_date || '',
        deliveryDate: r.delivery_date || '',
      }, { status: 'completed' })
      n += 1
    })
    onState(getState())
    onToast(`${toFa(n)} سفارش از فایل اکسل به‌روز شد`)
  }
  return (
    <div className="p-4 sm:p-0">
      <h2 className="mb-2 text-lg font-black">درون‌ریزی کد رهگیری با اکسل / CSV</h2>
      <p className="mb-3 text-xs text-slate-500">کدهای رهگیری با شماره سفارش شناسایی می‌شوند. مناسب فروشندگان دکان و صدور گروهی.</p>
      <textarea value={text} onChange={(e) => setText(e.target.value)} className="h-48 w-full rounded-2xl border border-slate-200 p-3 font-mono text-[11px]" />
      <div className="mt-3 flex flex-wrap gap-2">
        <button onClick={apply} className="rounded-xl bg-saina-700 px-4 py-2 text-xs font-bold text-white">درون‌ریزی</button>
        <button
          onClick={() => downloadText('saina-tracking-sample.csv', 'order_id,tracking_code,carrier,ship_date,delivery_date\n1045,994400112233445566778899,post,1404/06/16,1404/06/19\n')}
          className="rounded-xl border px-4 py-2 text-xs font-bold"
        >
          دانلود نمونه CSV
        </button>
      </div>
    </div>
  )
}

function SmsPage({ state, onToast, onState }) {
  const [tpl, setTpl] = useState(state.settings.smsTemplate)
  return (
    <div className="p-4 sm:p-0">
      <h2 className="mb-2 text-lg font-black">پیامک ووکامرس فارسی</h2>
      <p className="mb-4 text-xs leading-6 text-slate-500">
        ساینا پیامک جدا نمی‌فرستد؛ شورتکدها به متن وضعیت «تکمیل‌شده» و «تحویل‌شده» افزونه پیامک ووکامرس اضافه می‌شوند. ایمیل نیز به جزئیات ایمیل ووکامرس الحاق می‌گردد.
      </p>
      <textarea value={tpl} onChange={(e) => setTpl(e.target.value)} className="h-32 w-full rounded-2xl border p-3 text-sm" />
      <div className="mt-2 flex flex-wrap gap-2 text-[11px]">
        {['{order_id}', '{first_name}', '{tracking_code}', '{carrier}', '{ship_date}', '{delivery_date}'].map((s) => (
          <code key={s} className="rounded bg-slate-100 px-2 py-1">{s}</code>
        ))}
      </div>
      <button
        onClick={() => {
          const next = getState()
          next.settings.smsTemplate = tpl
          saveState(next)
          onState(next)
          onToast('قالب پیامک ذخیره شد')
        }}
        className="mt-4 rounded-xl bg-saina-700 px-4 py-2 text-xs font-bold text-white"
      >
        ذخیره قالب
      </button>
      <h3 className="mt-6 mb-2 text-sm font-bold">گزارش پیامک‌های آزمایشی</h3>
      <div className="space-y-2">
        {state.smsLog.length === 0 && <div className="text-xs text-slate-400">هنوز پیامکی ارسال نشده. از متاباکس سفارش، ذخیره همراه با تیک پیامک را بزنید.</div>}
        {state.smsLog.map((s) => (
          <div key={s.id} className="rounded-xl border border-slate-100 p-3 text-xs">
            <div className="mb-1 font-bold">#{toFa(s.orderId)} → {toFa(s.mobile)} · {toFa(s.at)}</div>
            <div className="text-slate-600">{s.text}</div>
          </div>
        ))}
      </div>
    </div>
  )
}

function SettingsPage({ state, onToast, onState }) {
  const [s, setS] = useState(state.settings)
  function set(k, v) { setS((x) => ({ ...x, [k]: v })) }
  function save() {
    const next = getState()
    next.settings = s
    saveState(next)
    onState(next)
    onToast('تنظیمات ساینا ذخیره شد')
  }
  return (
    <div className="p-4 sm:p-0">
      <h2 className="mb-4 text-lg font-black">تنظیمات افزونه ساینا</h2>
      <div className="grid gap-4 lg:grid-cols-2">
        <Box title="عمومی">
          <Toggle label="نمایش نوار پیشرفت" checked={s.progressBarEnabled} onChange={(v) => set('progressBarEnabled', v)} />
          <Toggle label="ستون آیکن در سفارشات کاربر" checked={s.iconsColumnEnabled} onChange={(v) => set('iconsColumnEnabled', v)} />
          <Toggle label="جستجوی Ajax" checked={s.ajaxSearch} onChange={(v) => set('ajaxSearch', v)} />
          <Toggle label="تأیید دریافت توسط مشتری" checked={s.confirmDelivery} onChange={(v) => set('confirmDelivery', v)} />
          <Toggle label="غیرفعال برای محصولات دانلودی/مجازی" checked={s.disableVirtual} onChange={(v) => set('disableVirtual', v)} />
          <Toggle label="جاسازی در ایمیل ووکامرس" checked={s.emailEmbed} onChange={(v) => set('emailEmbed', v)} />
          <label className="mt-2 block text-[11px] font-bold">حالت فرم پیگیری</label>
          <select value={s.trackMode} onChange={(e) => set('trackMode', e.target.value)} className="h-9 w-full rounded-lg border px-2 text-xs">
            <option value="any">شماره سفارش یا موبایل یا ایمیل</option>
            <option value="order_mobile">همزمان سفارش + موبایل</option>
            <option value="order_email">همزمان سفارش + ایمیل</option>
          </select>
        </Box>
        <Box title="کپچا و حامل پیش‌فرض">
          <label className="block text-[11px] font-bold">نوع کپچا</label>
          <select value={s.captcha} onChange={(e) => set('captcha', e.target.value)} className="mb-3 h-9 w-full rounded-lg border px-2 text-xs">
            <option value="none">بدون کپچا</option>
            <option value="math">کپچای عددی</option>
            <option value="recaptcha2">Google reCAPTCHA v2</option>
            <option value="recaptcha3">Google reCAPTCHA v3</option>
          </select>
          <label className="block text-[11px] font-bold">حامل پیش‌فرض</label>
          <select value={s.defaultCarrier} onChange={(e) => set('defaultCarrier', e.target.value)} className="h-9 w-full rounded-lg border px-2 text-xs">
            {CARRIERS.map((c) => <option key={c.id} value={c.id}>{c.name}</option>)}
          </select>
          <label className="mt-3 block text-[11px] font-bold">تبدیل خودکار تکمیل‌شده به تحویل‌شده (روز)</label>
          <input type="number" value={s.autoDeliverDays} onChange={(e) => set('autoDeliverDays', Number(e.target.value))} className="h-9 w-full rounded-lg border px-2 text-xs" />
        </Box>
      </div>
      <Box title="شخصی‌سازی ۵ وضعیت نوار پیشرفت">
        <div className="grid gap-3">
          {s.statuses.map((st, i) => (
            <div key={st.key} className="grid grid-cols-[1fr_120px] gap-2">
              <input value={st.label} onChange={(e) => {
                const statuses = s.statuses.map((x, idx) => idx === i ? { ...x, label: e.target.value } : x)
                set('statuses', statuses)
              }} className="h-9 rounded-lg border px-2 text-xs" />
              <input type="color" value={st.color} onChange={(e) => {
                const statuses = s.statuses.map((x, idx) => idx === i ? { ...x, color: e.target.value } : x)
                set('statuses', statuses)
              }} className="h-9 w-full rounded-lg border" />
            </div>
          ))}
        </div>
      </Box>
      <button onClick={save} className="mt-4 rounded-xl bg-saina-700 px-5 py-2.5 text-sm font-bold text-white">ذخیره تنظیمات</button>
    </div>
  )
}

function Box({ title, children }) {
  return (
    <div className="mb-4 rounded-2xl border border-slate-100 p-4">
      <div className="mb-3 text-sm font-bold">{title}</div>
      {children}
    </div>
  )
}
function Toggle({ label, checked, onChange }) {
  return (
    <label className="mb-2 flex items-center justify-between gap-3 text-xs">
      <span>{label}</span>
      <input type="checkbox" checked={checked} onChange={(e) => onChange(e.target.checked)} />
    </label>
  )
}
