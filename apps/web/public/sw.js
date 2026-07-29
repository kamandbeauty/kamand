/**
 * سرویس‌ورکر جاوید — پشتوانهٔ عملی «کار بدون اینترنت».
 *
 * راهبرد:
 *  - دارایی‌های برنامه: cache-first، چون نسخه‌دار هستند و تغییر نمی‌کنند
 *  - ناوبری: network-first با سقوط به کش، تا کاربر آفلاین هم برنامه را ببیند
 *  - درخواست‌های API: هرگز کش نمی‌شوند — دادهٔ مالی باید تازه باشد
 *
 * نکتهٔ مهم: هیچ پاسخ API‌ای کش نمی‌شود. دادهٔ محلی در IndexedDB است،
 * نه در کش سرویس‌ورکر؛ قاطی کردن این دو باعث نمایش دادهٔ کهنه می‌شود.
 */

const VERSION = 'javid-v1';
const SHELL_CACHE = `${VERSION}-shell`;

const SHELL = ['./', './index.html', './manifest.webmanifest'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches
      .open(SHELL_CACHE)
      // نبود یک فایل نباید کل نصب را بشکند
      .then((cache) => Promise.allSettled(SHELL.map((u) => cache.add(u))))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(keys.filter((k) => !k.startsWith(VERSION)).map((k) => caches.delete(k))),
      )
      .then(() => self.clients.claim()),
  );
});

/** آیا این درخواست به API همگام‌سازی است؟ */
function isApiRequest(url) {
  return (
    url.pathname.startsWith('/sync/') ||
    url.pathname.startsWith('/auth/') ||
    url.pathname === '/me' ||
    url.pathname.startsWith('/businesses')
  );
}

self.addEventListener('fetch', (event) => {
  const { request } = event;

  if (request.method !== 'GET') return;

  const url = new URL(request.url);

  // دادهٔ مالی هرگز از کش سرو نمی‌شود
  if (isApiRequest(url)) return;

  // فقط دامنهٔ خودمان
  if (url.origin !== self.location.origin) return;

  // ناوبری: شبکه اول، سپس کش
  if (request.mode === 'navigate') {
    event.respondWith(
      fetch(request)
        .then((res) => {
          const copy = res.clone();
          caches.open(SHELL_CACHE).then((c) => c.put('./index.html', copy));
          return res;
        })
        .catch(() =>
          caches.match('./index.html').then((r) => r ?? caches.match('./')),
        ),
    );
    return;
  }

  // دارایی‌ها: کش اول
  event.respondWith(
    caches.match(request).then((cached) => {
      if (cached) return cached;
      return fetch(request)
        .then((res) => {
          if (res.ok && res.type === 'basic') {
            const copy = res.clone();
            caches.open(SHELL_CACHE).then((c) => c.put(request, copy));
          }
          return res;
        })
        .catch(() => cached);
    }),
  );
});

/** پیام از برنامه — برای بروزرسانی فوری */
self.addEventListener('message', (event) => {
  if (event.data === 'skip-waiting') self.skipWaiting();
});
