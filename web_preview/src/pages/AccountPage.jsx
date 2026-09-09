import { useState } from 'react'
import { Package } from 'lucide-react'
import { CarrierModal, ProgressBar, StatusBadge } from '../components'
import { carrierById, getState, upsertTracking } from '../store'
import { money, toFa } from '../utils'

export default function AccountPage({ onToast, onState }) {
  const state = getState()
  const settings = state.settings
  const mine = state.orders.filter((o) => o.customer.mobile === '09121234567')
  const [carrierOrder, setCarrierOrder] = useState(null)

  return (
    <div className="mx-auto max-w-4xl px-4 py-8">
      <div className="mb-5 flex items-center justify-between">
        <div>
          <div className="text-xs text-slate-400">حساب کاربری</div>
          <h1 className="text-xl font-black">سفارش‌های من</h1>
        </div>
        <div className="rounded-full bg-saina-50 px-3 py-1 text-xs font-bold text-saina-800">سارا محمدی</div>
      </div>
      <div className="space-y-4">
        {mine.map((order) => {
          const c = carrierById(order.tracking.carrier)
          return (
            <div key={order.id} className="overflow-hidden rounded-3xl border border-slate-100 bg-white shadow-soft">
              <div className="flex flex-wrap items-center justify-between gap-3 border-b border-slate-100 px-4 py-3">
                <div className="flex items-center gap-3">
                  {!settings.disableIconsColumn && settings.iconsColumnEnabled && (
                    <div className="group relative flex h-10 w-10 items-center justify-center rounded-2xl bg-saina-50 text-saina-700">
                      <Package size={18} />
                      {order.tracking.code && (
                        <div className="pointer-events-none absolute right-12 top-1 z-10 hidden w-52 rounded-xl bg-slate-900 p-3 text-[11px] text-white shadow-xl group-hover:block">
                          <div>کد: {order.tracking.code}</div>
                          <div>{c.name}</div>
                          <div>ارسال: {toFa(order.tracking.shipDate || '—')}</div>
                        </div>
                      )}
                    </div>
                  )}
                  <div>
                    <div className="font-bold">سفارش #{toFa(order.id)}</div>
                    <div className="text-[11px] text-slate-400">{toFa(order.date)} · {money(order.total)}</div>
                  </div>
                </div>
                <StatusBadge status={order.status} statuses={settings.statuses} />
              </div>
              <div className="p-4">
                {!settings.disableProgressAccount && settings.progressBarEnabled && <ProgressBar order={order} statuses={settings.statuses} compact />}
                <div className="mt-3 flex flex-wrap gap-2">
                  {order.tracking.code && (c.id === 'post' || c.id === 'post-custom') && (
                    <button onClick={() => setCarrierOrder(order)} className="rounded-lg bg-saina-700 px-3 py-1.5 text-[11px] font-bold text-white">پیگیری از پست</button>
                  )}
                  {order.tracking.code && c.id === 'chapar' && (
                    <button onClick={() => setCarrierOrder(order)} className="rounded-lg bg-amber-600 px-3 py-1.5 text-[11px] font-bold text-white">پیگیری از چاپار</button>
                  )}
                  {order.tracking.code && c.id === 'tipax' && (
                    <button onClick={() => setCarrierOrder(order)} className="rounded-lg bg-blue-700 px-3 py-1.5 text-[11px] font-bold text-white">پیگیری از تیپاکس</button>
                  )}
                  {!settings.disableConfirm && settings.confirmDelivery && order.status === 'completed' && (
                    <button
                      onClick={() => {
                        upsertTracking(order.id, order.tracking, { status: 'delivered' })
                        onState(getState())
                        onToast('از تأیید دریافت شما متشکریم')
                      }}
                      className="rounded-lg border border-emerald-200 bg-emerald-50 px-3 py-1.5 text-[11px] font-bold text-emerald-700"
                    >
                      کالا را تحویل گرفتم
                    </button>
                  )}
                </div>
              </div>
            </div>
          )
        })}
      </div>
      {carrierOrder && <CarrierModal order={carrierOrder} onClose={() => setCarrierOrder(null)} />}
    </div>
  )
}
