# معماری «علم اسامی»

## لایه‌ها

```text
lib/
├── app/              # App shell, routing, global providers
├── core/             # normalization, theme, shared infrastructure
├── domain/           # entities and pure engines
├── data/             # SQLite database, repositories, seed content
└── features/         # presentation by product feature
```

## اصول

1. Nameology و Traditional Analysis دو حوزه جدا هستند.
2. هر نتیجه سنتی باید system و rule version داشته باشد.
3. هر ادعا باید Source Claim داشته باشد یا `unverified` باشد.
4. داده محلی منبع اصلی نسخه اول است؛ شبکه برای نسخه‌های بعدی اختیاری است.
5. موتورهای محاسباتی به Flutter و دیتابیس وابسته نیستند.
6. اطلاعات پروفایل فقط محلی و با حداقل‌گرایی ذخیره می‌شود.

## نسخه‌بندی

- `schema_version`: نسخه ساختار SQLite
- `content_version`: نسخه محتوای نام‌ها و منابع
- `app_version`: نسخه اپلیکیشن

## مراحل توسعه

- Phase 1: Foundation، نرمال‌سازی، دیتابیس، جست‌وجو، جزئیات نام، ابجد پایه و آرشیو پژوهشی اولیه
- Phase 2: منابع گسترده، سازگاری Rule-driven، انتخاب نام نوزاد و مقایسه
- Phase 3: تاریخ تولد، پروفایل چندگانه، Share و تحلیل روزانه deterministic
- Phase 4: Brand Analyzer، Generator، Remote Content Update و Monetization
