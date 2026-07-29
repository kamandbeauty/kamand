/**
 * بارکدخوان — دو مسیر:
 *  ۱. سخت‌افزاری: اسکنرهای USB خودشان را کیبورد جا می‌زنند و رشته را
 *     خیلی سریع تایپ می‌کنند و با Enter تمام می‌کنند. با سنجش سرعت
 *     تایپ می‌توان آن را از تایپ انسان تشخیص داد.
 *  ۲. نرم‌افزاری: دوربین گوشی از طریق BarcodeDetector مرورگر.
 */

/** حداکثر فاصلهٔ زمانی بین دو نویسه تا «اسکن» شمرده شود (میلی‌ثانیه) */
const SCAN_CHAR_GAP_MS = 45;
const MIN_BARCODE_LENGTH = 4;

export interface ScannerOptions {
  onScan: (code: string) => void;
  minLength?: number;
  gapMs?: number;
}

/**
 * تشخیص اسکنر سخت‌افزاری.
 * انسان نمی‌تواند ۱۰ نویسه را با فاصلهٔ زیر ۴۵ میلی‌ثانیه تایپ کند،
 * پس اگر چنین الگویی دیدیم، اسکنر است.
 */
export function attachHardwareScanner(opts: ScannerOptions): () => void {
  const minLength = opts.minLength ?? MIN_BARCODE_LENGTH;
  const gapMs = opts.gapMs ?? SCAN_CHAR_GAP_MS;

  let buffer = '';
  let lastTime = 0;

  const onKey = (e: KeyboardEvent) => {
    const now = Date.now();

    if (e.key === 'Enter') {
      if (buffer.length >= minLength) {
        opts.onScan(buffer);
        // جلوگیری از ارسال ناخواستهٔ فرم
        e.preventDefault();
      }
      buffer = '';
      return;
    }

    if (e.key.length !== 1) return;

    // فاصلهٔ زیاد یعنی شروع دنبالهٔ جدید
    if (now - lastTime > gapMs) buffer = '';
    buffer += e.key;
    lastTime = now;
  };

  window.addEventListener('keydown', onKey, true);
  return () => window.removeEventListener('keydown', onKey, true);
}

// ─────────────────── دوربین ───────────────────

interface DetectedBarcode {
  rawValue: string;
  format: string;
}

interface BarcodeDetectorLike {
  detect(source: CanvasImageSource): Promise<DetectedBarcode[]>;
}

interface BarcodeDetectorCtor {
  new (opts?: { formats?: string[] }): BarcodeDetectorLike;
  getSupportedFormats?(): Promise<string[]>;
}

export function cameraScanSupported(): boolean {
  return (
    typeof window !== 'undefined' &&
    'BarcodeDetector' in window &&
    typeof navigator !== 'undefined' &&
    !!navigator.mediaDevices?.getUserMedia
  );
}

export const CAMERA_FORMATS = [
  'ean_13', 'ean_8', 'code_128', 'code_39', 'upc_a', 'upc_e', 'itf', 'qr_code',
];

export interface CameraScanner {
  stop(): void;
}

/**
 * راه‌اندازی اسکن با دوربین.
 * دوربین پشتی ترجیح داده می‌شود و پس از اولین تشخیص، اسکن متوقف می‌شود.
 */
export async function startCameraScanner(
  video: HTMLVideoElement,
  onScan: (code: string, format: string) => void,
  onError?: (e: Error) => void,
): Promise<CameraScanner> {
  if (!cameraScanSupported()) {
    throw new Error('مرورگر شما از اسکن با دوربین پشتیبانی نمی‌کند');
  }

  const Ctor = (window as unknown as { BarcodeDetector: BarcodeDetectorCtor }).BarcodeDetector;

  let formats = CAMERA_FORMATS;
  try {
    const supported = await Ctor.getSupportedFormats?.();
    if (supported?.length) formats = CAMERA_FORMATS.filter((f) => supported.includes(f));
  } catch { /* از پیش‌فرض استفاده می‌کنیم */ }

  const detector = new Ctor({ formats });

  const stream = await navigator.mediaDevices.getUserMedia({
    video: { facingMode: { ideal: 'environment' } },
  });

  video.srcObject = stream;
  video.setAttribute('playsinline', 'true');
  await video.play();

  let running = true;
  let raf = 0;

  const tick = async () => {
    if (!running) return;
    try {
      if (video.readyState >= 2) {
        const found = await detector.detect(video);
        const first = found[0];
        if (first?.rawValue) {
          onScan(first.rawValue, first.format);
          stop();
          return;
        }
      }
    } catch (e) {
      onError?.(e as Error);
    }
    raf = requestAnimationFrame(() => { void tick(); });
  };

  function stop() {
    running = false;
    cancelAnimationFrame(raf);
    for (const track of stream.getTracks()) track.stop();
    video.srcObject = null;
  }

  void tick();
  return { stop };
}

// ─────────────────── اعتبارسنجی بارکد ───────────────────

/** رقم کنترلی EAN-13 / EAN-8 / UPC */
export function eanCheckDigit(digits: string): number {
  const body = digits.replace(/\D/g, '');
  let sum = 0;
  // از راست به چپ، وزن‌ها ۳ و ۱ متناوب
  const reversed = [...body].reverse();
  for (let i = 0; i < reversed.length; i++) {
    sum += Number(reversed[i]) * (i % 2 === 0 ? 3 : 1);
  }
  return (10 - (sum % 10)) % 10;
}

export function isValidEAN(code: string): boolean {
  const c = code.replace(/\D/g, '');
  if (![8, 12, 13, 14].includes(c.length)) return false;
  const body = c.slice(0, -1);
  return eanCheckDigit(body) === Number(c.slice(-1));
}

/** تولید بارکد داخلی معتبر برای کالاهای بدون بارکد کارخانه */
export function generateInternalBarcode(seq: number): string {
  // پیشوند ۲۰۰ برای استفادهٔ داخلی رزرو شده است
  const body = `200${String(seq).padStart(9, '0')}`.slice(0, 12);
  return body + eanCheckDigit(body);
}
