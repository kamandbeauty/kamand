import moment from 'jalali-moment'

export const faDigits = '۰۱۲۳۴۵۶۷۸۹'
export const enDigits = '0123456789'

export function toFa(value) {
  return String(value ?? '').replace(/\d/g, (d) => faDigits[d])
}

export function toEn(value) {
  return String(value ?? '')
    .replace(/[۰-۹]/g, (d) => enDigits[faDigits.indexOf(d)])
    .replace(/[٠-٩]/g, (d) => '0123456789'['٠١٢٣٤٥٦٧٨٩'.indexOf(d)])
}

export function money(n) {
  const num = Number(n || 0)
  return `${toFa(num.toLocaleString('en-US'))} تومان`
}

export function todayJalali() {
  return moment().locale('fa').format('jYYYY/jMM/jDD')
}

export function formatJalali(input) {
  if (!input) return '—'
  if (String(input).includes('/')) return toFa(input)
  return toFa(moment(input).locale('fa').format('jYYYY/jMM/jDD'))
}

export function addJalaliDays(jdate, days) {
  const m = moment(jdate, 'jYYYY/jMM/jDD')
  m.add(days, 'day')
  return m.format('jYYYY/jMM/jDD')
}

export function normalizePhone(phone) {
  let p = toEn(phone).replace(/[\s-]/g, '')
  if (p.startsWith('+98')) p = '0' + p.slice(3)
  if (p.startsWith('98') && p.length === 12) p = '0' + p.slice(2)
  return p
}

export function uid(prefix = 'id') {
  return `${prefix}_${Math.random().toString(36).slice(2, 9)}`
}

export function csvParse(text) {
  const lines = text.trim().split(/\r?\n/).filter(Boolean)
  if (!lines.length) return []
  const headers = lines[0].split(',').map((h) => h.trim())
  return lines.slice(1).map((line) => {
    const cols = line.split(',').map((c) => c.trim())
    const row = {}
    headers.forEach((h, i) => {
      row[h] = cols[i] ?? ''
    })
    return row
  })
}

export function downloadText(filename, content, mime = 'text/csv;charset=utf-8') {
  const blob = new Blob([content], { type: mime })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}
