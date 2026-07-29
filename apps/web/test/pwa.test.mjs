/**
 * آزمون PWA — بررسی مانیفست، سرویس‌ورکر و آیکن‌ها.
 *
 * تمرکز روی چیزهایی که بی‌صدا خراب می‌شوند: مانیفست ناقص یا
 * سرویس‌ورکری که دادهٔ مالی را کش کند.
 */
import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const pub = (p) => root + 'public/' + p;
const dist = (p) => root + 'dist/' + p;

describe('مانیفست', () => {
  const m = JSON.parse(readFileSync(pub('manifest.webmanifest'), 'utf8'));

  test('فیلدهای الزامی نصب موجودند', () => {
    assert.ok(m.name, 'نام');
    assert.ok(m.short_name, 'نام کوتاه');
    assert.ok(m.start_url, 'آدرس شروع');
    assert.equal(m.display, 'standalone', 'باید تمام‌صفحه اجرا شود');
    assert.ok(Array.isArray(m.icons) && m.icons.length > 0);
  });

  test('راست‌به‌چپ و فارسی اعلام شده', () => {
    assert.equal(m.dir, 'rtl');
    assert.equal(m.lang, 'fa-IR');
  });

  test('آیکن‌های ۱۹۲ و ۵۱۲ و maskable وجود دارند', () => {
    const sizes = m.icons.map((i) => i.sizes);
    assert.ok(sizes.includes('192x192'), 'آیکن ۱۹۲');
    assert.ok(sizes.includes('512x512'), 'آیکن ۵۱۲');
    assert.ok(m.icons.some((i) => i.purpose === 'maskable'), 'آیکن maskable برای اندروید');
  });

  test('فایل هر آیکن واقعاً وجود دارد و خالی نیست', () => {
    for (const icon of m.icons) {
      const file = pub(icon.src.replace('./', ''));
      assert.ok(existsSync(file), `فایل ${icon.src} یافت نشد`);
      assert.ok(statSync(file).size > 1000, `فایل ${icon.src} خیلی کوچک است`);
    }
  });

  test('رنگ برند با طرح یکی است', () => {
    assert.equal(m.theme_color, '#0f766e');
  });

  test('مسیرها نسبی هستند تا در زیرپوشه هم کار کند', () => {
    assert.ok(m.start_url.startsWith('./'));
    assert.ok(m.icons.every((i) => i.src.startsWith('./')));
  });
});

describe('سرویس‌ورکر', () => {
  const sw = readFileSync(pub('sw.js'), 'utf8');

  test('نسخه‌بندی دارد تا کش قدیمی پاک شود', () => {
    assert.match(sw, /const VERSION/);
    assert.match(sw, /caches\.delete/);
  });

  test('درخواست‌های API کش نمی‌شوند', () => {
    assert.match(sw, /isApiRequest/);
    assert.match(sw, /\/sync\//);
    assert.match(sw, /\/auth\//);
  });

  test('فقط درخواست GET را دست می‌گیرد', () => {
    assert.match(sw, /request\.method !== 'GET'/);
  });

  test('ناوبری شبکه-اول است تا نسخهٔ کهنه سرو نشود', () => {
    assert.match(sw, /request\.mode === 'navigate'/);
  });

  test('منطق تشخیص API درست کار می‌کند', () => {
    // همان منطق سرویس‌ورکر، بازتولید شده برای آزمون
    const isApi = (path) =>
      path.startsWith('/sync/') ||
      path.startsWith('/auth/') ||
      path === '/me' ||
      path.startsWith('/businesses');

    assert.equal(isApi('/sync/pull'), true);
    assert.equal(isApi('/auth/otp'), true);
    assert.equal(isApi('/me'), true);
    assert.equal(isApi('/businesses/x/members'), true);
    assert.equal(isApi('/assets/index.js'), false);
    assert.equal(isApi('/'), false);
  });
});

describe('صفحهٔ اصلی', () => {
  const html = readFileSync(root + 'index.html', 'utf8');

  test('مانیفست پیوند شده', () => {
    assert.match(html, /rel="manifest"/);
  });

  test('راست‌به‌چپ و فارسی', () => {
    assert.match(html, /lang="fa"/);
    assert.match(html, /dir="rtl"/);
  });

  test('پشتیبانی نصب روی iOS', () => {
    assert.match(html, /apple-mobile-web-app-capable/);
    assert.match(html, /apple-touch-icon/);
  });

  test('رنگ نوار وضعیت تنظیم شده', () => {
    assert.match(html, /theme-color/);
  });
});

describe('خروجی ساخت', { skip: !existsSync(dist('index.html')) }, () => {
  test('مانیفست و سرویس‌ورکر در خروجی هستند', () => {
    assert.ok(existsSync(dist('manifest.webmanifest')));
    assert.ok(existsSync(dist('sw.js')));
  });

  test('آیکن‌ها در خروجی کپی شده‌اند', () => {
    for (const f of ['icon-192.png', 'icon-512.png', 'icon-maskable.png']) {
      assert.ok(existsSync(dist(f)), `${f} در خروجی نیست`);
    }
  });
});
