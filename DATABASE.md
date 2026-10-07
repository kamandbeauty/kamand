# معماری دیتابیس محلی «علم اسامی»

نسخه فعلی از SQLite محلی با Migration صریح استفاده می‌کند. Repository و Engineها به API دیتابیس وابستگی مستقیم ندارند و در صورت نیاز می‌توان لایه پیاده‌سازی را بدون تغییر Domain به Drift منتقل کرد.

## نسخه Schema

- Schema 1: هسته نام‌ها، منابع، ابجد، پروفایل و آرشیو
- Schema 2: FTS5، Source Claims، تنظیمات حریم خصوصی، Meaning و Etymology
- Schema 3: Language، Culture و Pronunciation
- Schema 4: Abjad Mapping، Numerology Systems، Rules و Interpretation placeholders
- Schema 5: Compatibility Systems و Rules
- Schema 6: تقویم تولد پروفایل‌ها (`birth_calendar`)
- Schema 7: فرمول نسخه‌دار برای سیستم‌های ابجد (`abjad_systems.formula`)

Metadata فعلی:

```text
schema_version = 7
content_version = knowledge-2
```

## جداول فعلی

```text
database_metadata
sources
source_authors
source_categories
source_claims
names
name_variants
name_meanings
name_etymologies
name_languages
name_cultures
name_pronunciations
names_fts
abjad_systems
abjad_letters
profiles
archive_entries
app_settings
numerology_systems
numerology_rules
numerology_interpretations
compatibility_systems
compatibility_rules
```

## Calculation Layer

- `abjad_systems` و `abjad_letters` نگاشت و فرمول نسخه‌دار را نگه می‌دارند. آرشیو شامل کبیر، صغیر، وسیط/متوسط، اکبر، وضعی و گونه‌های معادل‌سازی‌شده فارسی است.
- `kabir` فقط ۲۸ حرف استاندارد را می‌پذیرد؛ `*-persian` یک روش مشتق‌شده و جدا برای پ، چ، ژ و گ است و جایگزین ابجد استاندارد نیست.
- `saghir` با باقی‌مانده بر ۹، `wasit` با باقی‌مانده بر ۱۲، `akbar` با مربع کبیر و `wazee` با شماره ترتیبی محاسبه می‌شوند؛ وضعیت derived/unverified و منبع ثانویه کنار آن‌ها نمایش داده می‌شود.
- `numerology_systems` و `numerology_rules` عملیات قابل تنظیم را نگه می‌دارند و Rule فعلی `unverified` است.
- `numerology_interpretations` فعلاً عمداً خالی است؛ بدون منبع معتبر هیچ تفسیر عددی Seed نمی‌شود.
- `compatibility_systems` و `compatibility_rules` شاخص‌های مقایسه‌ای را نسخه‌دار نگه می‌دارند؛ Rule فعلی فقط شباهت نوشتاری است و `unverified` باقی می‌ماند.
- پروفایل‌ها محلی هستند و `birth_calendar` تقویم تاریخ ذخیره‌شده را از مقدار تاریخ جدا نگه می‌دارد.
- UI باید Formula، Rule Version، وضعیت، منبع و Disclaimer را همراه نتیجه نمایش دهد.

## وضعیت محتوا

مقادیر معتبر برای `status`:

- `verified`
- `unverified`
- `disputed`
- `deprecated`
- `pending`

مقادیر `confidence`:

- `high`
- `medium`
- `low`

## Source Claims

`source_claims` با `claim_group_id` اجازه می‌دهد چند منبع درباره یک ادعا ثبت شوند و اختلاف یا پشتیبانی آن‌ها از بین نرود.

```text
claim_group_id
source_id
subject_type
subject_id
claim_type
claim_text
normalized_value
status
confidence
evidence_note
review_status
```

## جست‌وجو

جدول `names_fts` برای جست‌وجوی Full Text و Prefix ایجاد شده است. در صورت خطای FTS یا ورودی دارای عملگرهای خاص، Repository به صورت ایمن به LIKE fallback می‌کند.

## Privacy

تنظیمات زیر فقط Local نگهداری می‌شوند:

```text
analytics_enabled
personalized_ads_enabled
content_updates_enabled
```

پیش‌فرض Analytics و تبلیغات شخصی‌سازی‌شده خاموش است.

## Migration Rules

- Migrationها فقط افزایشی هستند.
- حذف جدول یا ستون بدون Migration صریح ممنوع است.
- هر تغییر Schema باید تست Migration داشته باشد.
- `content_version` مستقل از `schema_version` است.
- داده‌های محتوایی بدون Source یا با وضعیت Unverified نباید به عنوان Fact نمایش داده شوند.
