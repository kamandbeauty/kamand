import { buildReceipt, type ReceiptOptions } from '@javid/core';
import type { DB } from './store';
import { paidOf, submissionFor } from './store';

/**
 * ارسال رسید به چاپگر حرارتی.
 *
 * سه مسیر پشتیبانی می‌شود و به ترتیب امتحان می‌شوند:
 *  ۱. Web Bluetooth — چاپگرهای بلوتوثی رایج در مغازه‌ها
 *  ۲. Web Serial — چاپگرهای USB روی دسکتاپ
 *  ۳. دانلود فایل — همیشه کار می‌کند، کاربر خودش به چاپگر می‌فرستد
 *
 * مسیر سوم تضمین می‌کند نبود پشتیبانی مرورگر، کاربر را بن‌بست نکند.
 */

export type PrintMethod = 'bluetooth' | 'serial' | 'download';

/** UUID سرویس چاپ سریال روی اکثر چاپگرهای حرارتی بلوتوثی */
const BT_SERVICE = 0x18f0;
const BT_CHARACTERISTIC = 0x2af1;

interface BluetoothLike {
  requestDevice(opts: unknown): Promise<{
    gatt?: {
      connect(): Promise<{
        getPrimaryService(id: number): Promise<{
          getCharacteristic(id: number): Promise<{
            writeValueWithoutResponse?(b: BufferSource): Promise<void>;
            writeValue(b: BufferSource): Promise<void>;
          }>;
        }>;
      }>;
    };
  }>;
}

interface SerialLike {
  requestPort(): Promise<{
    open(opts: { baudRate: number }): Promise<void>;
    writable: { getWriter(): { write(d: Uint8Array): Promise<void>; releaseLock(): void } } | null;
    close(): Promise<void>;
  }>;
}

export function availableMethods(): PrintMethod[] {
  const out: PrintMethod[] = [];
  const nav = navigator as Navigator & { bluetooth?: unknown; serial?: unknown };
  if (nav.bluetooth) out.push('bluetooth');
  if (nav.serial) out.push('serial');
  out.push('download');
  return out;
}

export const METHOD_LABELS: Record<PrintMethod, string> = {
  bluetooth: 'چاپگر بلوتوثی',
  serial: 'چاپگر USB',
  download: 'دریافت فایل چاپ',
};

async function printBluetooth(data: Uint8Array): Promise<void> {
  const nav = navigator as Navigator & { bluetooth?: BluetoothLike };
  if (!nav.bluetooth) throw new Error('مرورگر شما از بلوتوث پشتیبانی نمی‌کند');

  const device = await nav.bluetooth.requestDevice({
    filters: [{ services: [BT_SERVICE] }],
    optionalServices: [BT_SERVICE],
  });
  const server = await device.gatt?.connect();
  if (!server) throw new Error('اتصال به چاپگر برقرار نشد');

  const service = await server.getPrimaryService(BT_SERVICE);
  const ch = await service.getCharacteristic(BT_CHARACTERISTIC);

  // ارسال تکه‌تکه: بیشتر چاپگرها بستهٔ بزرگ‌تر از ۵۱۲ بایت را رد می‌کنند
  const CHUNK = 180;
  for (let i = 0; i < data.length; i += CHUNK) {
    const slice = data.slice(i, i + CHUNK);
    if (ch.writeValueWithoutResponse) await ch.writeValueWithoutResponse(slice);
    else await ch.writeValue(slice);
    await new Promise((r) => setTimeout(r, 20));
  }
}

async function printSerial(data: Uint8Array): Promise<void> {
  const nav = navigator as Navigator & { serial?: SerialLike };
  if (!nav.serial) throw new Error('مرورگر شما از پورت سریال پشتیبانی نمی‌کند');

  const port = await nav.serial.requestPort();
  await port.open({ baudRate: 9600 });
  const writer = port.writable?.getWriter();
  if (!writer) throw new Error('نوشتن روی پورت ممکن نیست');
  try {
    await writer.write(data);
  } finally {
    writer.releaseLock();
    await port.close();
  }
}

function downloadBinary(filename: string, data: Uint8Array): void {
  const buf = new ArrayBuffer(data.byteLength);
  new Uint8Array(buf).set(data);
  const url = URL.createObjectURL(new Blob([buf], { type: 'application/octet-stream' }));
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

/** ساخت رسید از فاکتور موجود در پایگاه داده */
export function receiptFor(db: DB, invoiceId: string, options: ReceiptOptions = {}) {
  const invoice = db.invoices.find((i) => i.id === invoiceId);
  if (!invoice) throw new Error('فاکتور یافت نشد');

  return buildReceipt({
    invoice,
    business: db.business,
    party: db.parties.find((p) => p.id === invoice.partyId) ?? null,
    products: new Map(db.products.map((p) => [p.id, p])),
    paid: paidOf(db, invoiceId),
    taxId: submissionFor(db, invoiceId)?.taxId ?? null,
    options,
  });
}

export async function printReceipt(
  db: DB,
  invoiceId: string,
  method: PrintMethod,
  options: ReceiptOptions = {},
): Promise<void> {
  const data = receiptFor(db, invoiceId, options).build();
  const invoice = db.invoices.find((i) => i.id === invoiceId);

  switch (method) {
    case 'bluetooth':
      return printBluetooth(data);
    case 'serial':
      return printSerial(data);
    case 'download':
      downloadBinary(`receipt-${invoice?.number ?? invoiceId}.bin`, data);
      return;
  }
}
