# علم اسامی

اپلیکیشن فارسی، راست‌به‌چپ و Offline-First برای دانشنامه نام‌ها، نام‌شناسی، ریشه‌شناسی، ابجد و تحلیل‌های سنتی.

> محاسبات ابجد، عددشناسی و شاخص شباهت نوشتاری در این پروژه با برچسب «سنتی / تفسیری / آزمایشی» ارائه می‌شوند و ادعای علمی یا پیش‌بینی قطعی ندارند.

## وضعیت محصول

این مخزن شامل نسخه MVP قابل توسعه محصول Nameology است:

- دانشنامه نام‌ها با وضعیت، اعتماد و Source Claim
- جست‌وجوی فارسی با FTS5 و Smart Search
- Source Registry و آرشیو منابع
- محاسبه Abjad با Mapping ذخیره‌شده در SQLite
- Numerology Rule نسخه‌دار با وضعیت `unverified`
- تحلیل تاریخ تولد شمسی و میلادی با Validation
- پروفایل‌های محلی و Privacy Settings
- مقایسه دو نام و دو پروفایل با شاخص شفاف شباهت نوشتاری
- RTL، Empty/Error/Loading State و Accessibility پایه

داده یا تفسیر فاقد منبع معتبر به‌عنوان Fact نمایش داده نمی‌شود. Interpretationهای عددی نیز تا زمان ثبت منبع معتبر Seed نشده‌اند.

## اجرا

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

ساخت APK آزمایشی:

```bash
flutter build apk --release
```

برای ساخت Release در GitHub، Tag با الگوی `v*` ایجاد کنید. Workflow مربوطه پس از Analyze، Test و Build، APK آزمایشی را به GitHub Release پیوست می‌کند.

## معماری

- Flutter / Dart
- Riverpod برای State و ViewModel
- SQLite محلی با Migration صریح، اکنون Schema Version 6
- Engineهای Pure Dart برای نرمال‌سازی، ابجد، عددشناسی، تاریخ و مقایسه
- Feature-first + Clean Architecture
- RTL و فارسی در نسخه اول

## محدودیت انتشار

Application ID فعلی توسعه‌ای است: `com.kamand.nameology.dev`.
نام برند و Package نهایی هنوز تعیین نشده است. APKهای فعلی برای پیش‌نمایش و تست هستند و پیش از انتشار در کافه‌بازار یا مایکت باید موارد زیر نهایی شوند:

- Package و نام برند نهایی
- Keystore و امضای Release واقعی
- Privacy Policy
- بررسی حقوق محتوا و منابع
- QA روی دستگاه‌های Android هدف
