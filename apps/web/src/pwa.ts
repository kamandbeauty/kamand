/**
 * نصب و مدیریت سرویس‌ورکر.
 *
 * قاعده: هیچ‌کدام از این‌ها نباید برنامه را متوقف کند. اگر مرورگر
 * سرویس‌ورکر نداشت یا نصب شکست خورد، برنامه عادی کار می‌کند —
 * فقط قابلیت نصب و کش آفلاین را از دست می‌دهد.
 */

export type UpdateHandler = (applyUpdate: () => void) => void;

let onUpdate: UpdateHandler | null = null;

export function onUpdateAvailable(handler: UpdateHandler): void {
  onUpdate = handler;
}

export function registerServiceWorker(): void {
  if (typeof navigator === 'undefined' || !('serviceWorker' in navigator)) return;
  // در حالت توسعه سرویس‌ورکر مزاحم بارگذاری مجدد است
  if (import.meta.env?.DEV) return;

  window.addEventListener('load', () => {
    navigator.serviceWorker
      .register('./sw.js', { scope: './' })
      .then((reg) => {
        reg.addEventListener('updatefound', () => {
          const next = reg.installing;
          if (!next) return;
          next.addEventListener('statechange', () => {
            // نسخهٔ جدید آماده است ولی نسخهٔ فعلی هنوز فعال است
            if (next.state === 'installed' && navigator.serviceWorker.controller) {
              onUpdate?.(() => {
                next.postMessage('skip-waiting');
                window.location.reload();
              });
            }
          });
        });
      })
      .catch(() => {
        // بی‌صدا رد می‌شویم — نبود کش آفلاین مانع کار نیست
      });
  });
}

// ─────────────────── نصب برنامه ───────────────────

interface BeforeInstallPromptEvent extends Event {
  prompt(): Promise<void>;
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>;
}

let deferredPrompt: BeforeInstallPromptEvent | null = null;
let installListener: ((available: boolean) => void) | null = null;

if (typeof window !== 'undefined') {
  window.addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    deferredPrompt = e as BeforeInstallPromptEvent;
    installListener?.(true);
  });

  window.addEventListener('appinstalled', () => {
    deferredPrompt = null;
    installListener?.(false);
  });
}

export function onInstallAvailable(cb: (available: boolean) => void): () => void {
  installListener = cb;
  cb(deferredPrompt !== null);
  return () => { installListener = null; };
}

export function canInstall(): boolean {
  return deferredPrompt !== null;
}

/** نمایش پنجرهٔ نصب مرورگر */
export async function promptInstall(): Promise<'accepted' | 'dismissed' | 'unavailable'> {
  if (!deferredPrompt) return 'unavailable';
  await deferredPrompt.prompt();
  const { outcome } = await deferredPrompt.userChoice;
  deferredPrompt = null;
  installListener?.(false);
  return outcome;
}

/** آیا برنامه به صورت نصب‌شده اجرا می‌شود؟ */
export function isStandalone(): boolean {
  if (typeof window === 'undefined') return false;
  const nav = navigator as Navigator & { standalone?: boolean };
  return (
    window.matchMedia?.('(display-mode: standalone)').matches === true ||
    nav.standalone === true
  );
}

/**
 * راهنمای نصب برای مرورگرهایی که پنجرهٔ خودکار ندارند.
 * سافاری iOS مهم‌ترین موردش است.
 */
export function installHint(): string | null {
  if (typeof navigator === 'undefined' || isStandalone()) return null;
  const ua = navigator.userAgent;

  const isIos = /iPad|iPhone|iPod/.test(ua);
  const isSafari = /Safari/.test(ua) && !/Chrome|CriOS|FxiOS|Edg/.test(ua);

  if (isIos && isSafari) {
    return 'برای نصب: دکمهٔ اشتراک‌گذاری مرورگر را بزنید و «افزودن به صفحهٔ اصلی» را انتخاب کنید.';
  }
  if (isIos) {
    return 'برای نصب، این صفحه را در مرورگر سافاری باز کنید و «افزودن به صفحهٔ اصلی» را بزنید.';
  }
  return null;
}
