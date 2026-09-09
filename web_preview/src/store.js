import { toEn, normalizePhone, todayJalali, addJalaliDays, uid } from './utils'

const KEY = 'saina_track_order_v1'

export const CARRIERS = [
  { id: 'post', name: 'پست پیشتاز', trackName: 'پست ایران', color: '#0f766e' },
  { id: 'post-custom', name: 'پست سفارشی', trackName: 'پست ایران', color: '#115e59' },
  { id: 'chapar', name: 'چاپار', trackName: 'چاپار', color: '#b45309' },
  { id: 'tipax', name: 'تیپاکس', trackName: 'تیپاکس', color: '#1d4ed8' },
  { id: 'alopeyk', name: 'الوپیک', trackName: 'الوپیک', color: '#dc2626' },
  { id: 'snapp', name: 'اسنپ‌باکس', trackName: 'اسنپ', color: '#16a34a' },
  { id: 'peyk', name: 'پیک موتوری فروشگاه', trackName: 'پیک', color: '#7c3aed' },
  { id: 'custom', name: 'سایر', trackName: 'سفارشی', color: '#475569' },
]

export const DEFAULT_STATUSES = [
  { key: 'processing', wc: 'processing', label: 'در حال انجام', color: '#0d9488', hint: 'سفارش دریافت شد و در حال پردازش است' },
  { key: 'on-hold', wc: 'on-hold', label: 'در حال بررسی', color: '#d97706', hint: 'سفارش در صف بررسی و آماده‌سازی است' },
  { key: 'packing', wc: 'saina-packing', label: 'بسته‌بندی', color: '#7c3aed', hint: 'مرسوله در حال بسته‌بندی است' },
  { key: 'completed', wc: 'completed', label: 'تکمیل شده / ارسال', color: '#2563eb', hint: 'مرسوله به شرکت حمل تحویل داده شد' },
  { key: 'delivered', wc: 'saina-delivered', label: 'تحویل شده', color: '#16a34a', hint: 'سفارش به مشتری تحویل داده شد' },
]

const STATUS_RANK = {
  pending: 0,
  processing: 0,
  'on-hold': 1,
  packing: 2,
  'saina-packing': 2,
  completed: 3,
  delivered: 4,
  'saina-delivered': 4,
}

export function statusIndex(status) {
  if (STATUS_RANK[status] !== undefined) return STATUS_RANK[status]
  return 0
}

export function isCancelled(status) {
  return ['cancelled', 'failed', 'refunded'].includes(status)
}

const seedOrders = [
  {
    id: 1042,
    date: '1404/06/12',
    status: 'packing',
    payment: 'پرداخت در محل',
    total: 1860000,
    customer: { name: 'سارا محمدی', mobile: '09121234567', email: 'sara@example.com', city: 'تهران' },
    items: [
      { name: 'سرم ویتامین C ساینا', qty: 1, price: 890000 },
      { name: 'کرم مرطوب‌کننده شب', qty: 2, price: 420000 },
    ],
    tracking: {
      code: '994412345678901234567890',
      carrier: 'post',
      shipDate: '1404/06/14',
      deliveryDate: '1404/06/18',
    },
    history: {
      processing: '1404/06/12 11:20',
      'on-hold': '1404/06/12 16:40',
      packing: '1404/06/13 09:10',
    },
  },
  {
    id: 1045,
    date: '1404/06/15',
    status: 'processing',
    payment: 'کارت به کارت',
    total: 540000,
    customer: { name: 'علی رضایی', mobile: '09351234567', email: 'ali.r@example.com', city: 'اصفهان' },
    items: [{ name: 'تونر آبرسان گل رز', qty: 1, price: 540000 }],
    tracking: { code: '', carrier: 'post', shipDate: '', deliveryDate: '' },
    history: { processing: '1404/06/15 19:02' },
  },
  {
    id: 1038,
    date: '1404/06/04',
    status: 'delivered',
    payment: 'زرین‌پال',
    total: 1270000,
    customer: { name: 'سارا محمدی', mobile: '09121234567', email: 'sara@example.com', city: 'تهران' },
    items: [{ name: 'پک روتین پوست خشک', qty: 1, price: 1270000 }],
    tracking: {
      code: 'CHP-88234119',
      carrier: 'chapar',
      shipDate: '1404/06/05',
      deliveryDate: '1404/06/07',
    },
    history: {
      processing: '1404/06/04 10:12',
      packing: '1404/06/04 18:00',
      completed: '1404/06/05 09:30',
      delivered: '1404/06/07 14:18',
    },
  },
  {
    id: 1031,
    date: '1404/05/28',
    status: 'completed',
    payment: 'زرین‌پال',
    total: 760000,
    customer: { name: 'سارا محمدی', mobile: '09121234567', email: 'sara@example.com', city: 'تهران' },
    items: [{ name: 'ماسک ورقه‌ای کلاژن', qty: 4, price: 190000 }],
    tracking: {
      code: 'TPX10992811',
      carrier: 'tipax',
      shipDate: '1404/05/29',
      deliveryDate: '1404/06/01',
    },
    history: {
      processing: '1404/05/28 12:00',
      packing: '1404/05/28 17:40',
      completed: '1404/05/29 08:20',
    },
  },
  {
    id: 1028,
    date: '1404/05/22',
    status: 'on-hold',
    payment: 'پرداخت در محل',
    total: 320000,
    customer: { name: 'سارا محمدی', mobile: '09121234567', email: 'sara@example.com', city: 'تهران' },
    items: [{ name: 'بالم لب عسلی', qty: 2, price: 160000 }],
    tracking: { code: '', carrier: 'peyk', shipDate: '', deliveryDate: '' },
    history: { processing: '1404/05/22 21:11', 'on-hold': '1404/05/23 09:00' },
  },
  {
    id: 1050,
    date: '1404/06/16',
    status: 'packing',
    payment: 'اسنپ‌پی',
    total: 2140000,
    customer: { name: 'رضا کریمی', mobile: '09139876543', email: 'reza.k@example.com', city: 'شیراز' },
    items: [
      { name: 'دستگاه فیشال خانگی', qty: 1, price: 1890000 },
      { name: 'ژل پاک‌کننده', qty: 1, price: 250000 },
    ],
    tracking: {
      code: 'TPX22019844',
      carrier: 'tipax',
      shipDate: '1404/06/17',
      deliveryDate: '1404/06/20',
    },
    history: { processing: '1404/06/16 13:44', packing: '1404/06/16 18:05' },
  },
  {
    id: 1048,
    date: '1404/06/14',
    status: 'delivered',
    payment: 'کارت به کارت',
    total: 410000,
    customer: { name: 'مریم احمدی', mobile: '09012345678', email: 'maryam@example.com', city: 'مشهد' },
    items: [{ name: 'اسپری فیکس آرایش', qty: 1, price: 410000 }],
    tracking: {
      code: '994498761234567890123456',
      carrier: 'post',
      shipDate: '1404/06/14',
      deliveryDate: '1404/06/16',
    },
    history: {
      processing: '1404/06/14 08:10',
      packing: '1404/06/14 11:00',
      completed: '1404/06/14 16:20',
      delivered: '1404/06/16 12:40',
    },
  },
  {
    id: 1041,
    date: '1404/06/11',
    status: 'cancelled',
    payment: 'زرین‌پال',
    total: 980000,
    customer: { name: 'نیما صادقی', mobile: '09121112233', email: 'nima@example.com', city: 'کرج' },
    items: [{ name: 'ست براش حرفه‌ای', qty: 1, price: 980000 }],
    tracking: { code: '', carrier: 'post', shipDate: '', deliveryDate: '' },
    history: { processing: '1404/06/11 20:01' },
  },
  {
    id: 1035,
    date: '1404/06/01',
    status: 'completed',
    payment: 'پرداخت در محل',
    total: 1550000,
    customer: { name: 'حسین نوری', mobile: '09190001122', email: 'hossein@example.com', city: 'تبریز' },
    items: [{ name: 'روغن آرگان خالص', qty: 2, price: 775000 }],
    tracking: { code: '', carrier: 'post', shipDate: '', deliveryDate: '' },
    history: { processing: '1404/06/01 10:00', completed: '1404/06/02 09:30' },
  },
]

const defaultSettings = {
  shopName: 'فروشگاه زیبایی ساینا',
  progressBarEnabled: true,
  iconsColumnEnabled: true,
  captcha: 'math',
  trackMode: 'any',
  defaultCarrier: 'post',
  autoDeliverDays: 7,
  confirmDelivery: true,
  disableVirtual: true,
  smsEnabled: true,
  emailEmbed: true,
  ajaxSearch: true,
  recaptchaSite: '',
  smsTemplate:
    'سلام {first_name} عزیز، سفارش {order_id} با کد رهگیری {tracking_code} از طریق {carrier} در تاریخ {ship_date} ارسال شد. تاریخ تقریبی تحویل: {delivery_date}',
  statuses: DEFAULT_STATUSES.map((s) => ({ ...s })),
}

const defaultSmsLog = []

function load() {
  try {
    const raw = localStorage.getItem(KEY)
    if (!raw) return null
    return JSON.parse(raw)
  } catch {
    return null
  }
}

function persist(state) {
  localStorage.setItem(KEY, JSON.stringify(state))
}

export function getState() {
  const saved = load()
  if (saved?.orders?.length) {
    return {
      orders: saved.orders,
      settings: { ...defaultSettings, ...saved.settings, statuses: saved.settings?.statuses?.length ? saved.settings.statuses : defaultSettings.statuses },
      smsLog: saved.smsLog || [],
    }
  }
  return {
    orders: seedOrders.map((o) => ({ ...o, tracking: { ...o.tracking }, items: o.items.map((i) => ({ ...i })), customer: { ...o.customer }, history: { ...o.history } })),
    settings: { ...defaultSettings, statuses: DEFAULT_STATUSES.map((s) => ({ ...s })) },
    smsLog: defaultSmsLog,
  }
}

export function saveState(state) {
  persist(state)
}

export function carrierById(id) {
  return CARRIERS.find((c) => c.id === id) || CARRIERS[CARRIERS.length - 1]
}

export function findOrders({ orderId, mobile, email }, mode = 'any') {
  const state = getState()
  const oid = toEn(orderId || '').replace(/^#/, '').trim()
  const mob = normalizePhone(mobile || '')
  const em = String(email || '').trim().toLowerCase()

  let list = state.orders.filter((o) => {
    const matchOrder = oid ? String(o.id) === oid : true
    const matchMobile = mob ? normalizePhone(o.customer.mobile) === mob : true
    const matchEmail = em ? o.customer.email.toLowerCase() === em : true

    if (mode === 'order_mobile') return oid && mob && matchOrder && matchMobile
    if (mode === 'order_email') return oid && em && matchOrder && matchEmail

    if (oid && !mob && !em) return matchOrder
    if (!oid && mob && !em) return matchMobile
    if (!oid && !mob && em) return matchEmail
    if (oid && mob) return matchOrder && matchMobile
    if (oid && em) return matchOrder && matchEmail
    if (mob && em) return matchMobile && matchEmail
    return false
  })

  list = list.sort((a, b) => b.id - a.id)
  if ((mob || em) && !oid) list = list.slice(0, 4)
  return list
}

export function upsertTracking(orderId, tracking, extra = {}) {
  const state = getState()
  const next = {
    ...state,
    orders: state.orders.map((o) => {
      if (o.id !== Number(orderId)) return o
      const merged = { ...o, tracking: { ...o.tracking, ...tracking }, ...extra }
      if (extra.status && extra.status !== o.status) {
        merged.history = { ...o.history, [extra.status]: `${todayJalali()} ${new Date().toTimeString().slice(0, 5)}` }
      }
      return merged
    }),
  }
  saveState(next)
  return next
}

export function applySms(order, template) {
  const c = carrierById(order.tracking.carrier)
  return template
    .replaceAll('{first_name}', order.customer.name.split(' ')[0])
    .replaceAll('{order_id}', String(order.id))
    .replaceAll('{tracking_code}', order.tracking.code || '—')
    .replaceAll('{carrier}', c.name)
    .replaceAll('{ship_date}', order.tracking.shipDate || '—')
    .replaceAll('{delivery_date}', order.tracking.deliveryDate || '—')
}

export function logSms(order, text) {
  const state = getState()
  const entry = {
    id: uid('sms'),
    orderId: order.id,
    mobile: order.customer.mobile,
    text,
    at: `${todayJalali()} ${new Date().toTimeString().slice(0, 5)}`,
  }
  const next = { ...state, smsLog: [entry, ...state.smsLog].slice(0, 40) }
  saveState(next)
  return entry
}

export function resetDemo() {
  localStorage.removeItem(KEY)
  return getState()
}

export function autoFillDates(carrierId) {
  const ship = todayJalali()
  const extra = carrierId === 'peyk' || carrierId === 'alopeyk' || carrierId === 'snapp' ? 1 : 3
  return { shipDate: ship, deliveryDate: addJalaliDays(ship, extra) }
}
