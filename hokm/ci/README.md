# CI حکم — نسخهٔ کانونی

`hokm-flutter.yml` نسخهٔ مرجعِ ورک‌فلوی گیت‌هاب اکشن‌ز است.

## چرا اینجا؟

بات Arena اجازهٔ نوشتن در `.github/workflows` را ندارد (محدودیت دسترسیِ
`workflows` در توکن GitHub App). به همین دلیل نسخهٔ مرجع اینجا نگه‌داری
می‌شود و پس از هر تغییر باید **به‌صورت دستی** به مسیر زیر همگام شود:

```
.github/workflows/hokm-flutter.yml
```

## همگام‌سازی (در کپی محلی گیت‌هاب)

```bash
git fetch origin arena/01a01f01-kamand
git checkout arena/01a01f01-kamand -- hokm/ci/hokm-flutter.yml
cp hokm/ci/hokm-flutter.yml .github/workflows/hokm-flutter.yml
git add .github/workflows/hokm-flutter.yml
git commit -m "ci: sync hokm-flutter workflow"
git push origin <branch>
```

یا از رابط وب گیت‌هاب: فایل `hokm/ci/hokm-flutter.yml` را باز کنید، محتوایش
را کپی و در `.github/workflows/hokm-flutter.yml` (Edit) جای‌گذاری کنید.

## چه چیزی از آخرین همگام‌سازی تغییر کرده

- گزارش تحلیل در کامنت تشخیصی فقط `error`/`warning` را نشان می‌دهد و
  تعداد infoها را جداگانه خلاصه می‌کند (حذف نویز لینت‌های سبک).
- خطاهای تحلیل و تست‌های شکست‌خورده به‌صورت annotation («Checks →
  Annotations») منتشر می‌شوند تا بدون دسترسی به لاگ، علت دقیق خوانده شود.
- `timeout-minutes` برای جاب‌ها + لغو ران‌های قدیمی روی همان برنچ
  (`concurrency`).
