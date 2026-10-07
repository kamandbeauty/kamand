# معماری «علم اسامی»

## Stack

- Flutter / Dart برای Android
- Riverpod برای Dependency Injection و State
- SQLite با Migration صریح و FTS5
- Pure Dart Engines برای منطق قابل تست
- Material 3 با Design System فارسی و RTL

Flutter عمداً حفظ شده است؛ Repository از قبل Flutter بوده و مهاجرت به Kotlin/Compose در این مرحله Rewrite غیرضروری ایجاد می‌کند.

## لایه‌ها

```text
lib/
├── app/              # App shell, global providers
├── core/             # normalization, calendar, theme, deterministic utilities
├── domain/           # models, repository contracts, pure engines
├── data/             # SQLite database, migrations, seed, repository implementations
└── features/         # presentation by product feature
```

## دو لایه محصول

### Knowledge Layer

- Name
- Meaning
- Etymology
- Language
- Culture
- Pronunciation
- Historical usage
- Literary references
- Sources and Claims

### Traditional Analysis Layer

- Abjad Archive: Kabir, Saghir, Wasit/Medium, Akbar, Wazee و گونه‌های معادل‌سازی فارسی
- Numerology
- Vibration
- Compatibility
- Daily Reading

گزارش تحلیل نام اکنون یک گزارش قابل بازبینی است: ورودی، محاسبه حرف‌به‌حرف، مقایسه همه سیستم‌های ابجد، Formula، Version، Source، Status و Disclaimer را کنار هم نشان می‌دهد. گزارش تولد نیز تاریخ نرمال‌شده شمسی/میلادی، مجموع ابجد نام و فرمول کاهش رقمی را جدا می‌کند.

این دو Layer در مدل داده، Engine و متن UI از هم جدا می‌مانند.

## اصول

1. هر ادعای دانشی باید Source Claim داشته باشد یا `unverified` باشد.
2. هر نتیجه سنتی باید System و Rule Version داشته باشد.
3. حروف فارسی اضافه در ابجد بدون Source Claim مقداردهی نمی‌شوند.
4. Mapping، Numerology Rule و Compatibility Rule از SQLite و با Version خوانده می‌شوند؛ تفسیرهای عددی بدون منبع Seed نمی‌شوند.
5. Compatibility فعلاً فقط شاخص نوشتاری آزمایشی است و نباید به سازگاری عاطفی تعبیر شود.
6. تاریخ تولد پروفایل باید همراه با تقویم، Validation و تبدیل تست‌شده ذخیره شود.
7. موتورهای محاسباتی به Flutter و UI وابستگی ندارند.
8. جست‌وجو ابتدا Normalization و سپس FTS5 و Fallback امن دارد.
9. پروفایل‌ها و تنظیمات حریم خصوصی Local هستند.
10. هیچ اطلاعات شخصی به عنوان Analytics Event ارسال نمی‌شود.

## نسخه‌بندی

- `schema_version`: نسخه ساختار SQLite
- `content_version`: نسخه محتوای نام‌ها و منابع
- `app_version`: نسخه اپلیکیشن

## مراحل توسعه

- Phase 1: Foundation، نرمال‌سازی، دیتابیس، FTS، تاریخ، Privacy و تست
- Phase 2: منابع گسترده، Source Claims و Knowledge Base
- Phase 3: ابجد، عددشناسی، تاریخ تولد و تحلیل روزانه
- Phase 4: مقایسه محدود و شفاف نام‌ها؛ بدون ادعای سازگاری عاطفی
- Phase 5: سازگاری زوجین و خانواده
- Phase 6: انتخاب نوزاد، Ranking و مقایسه
- Phase 7: UI Polish، Share و Accessibility
- Phase 8: QA، Performance و Release
