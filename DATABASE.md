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
- Schema 8: فراداده بانک منابع شامل مجوز، تاریخ دسترسی، دامنه پوشش و وضعیت بازبینی (`sources.license`, `sources.accessed_at`, `sources.coverage`, `sources.review_status`)
- Schema 9: زبان و منبع مستقل برای رکوردهای تلفظ (`name_pronunciations.language_code`, `name_pronunciations.language_title`, `name_pronunciations.source_id`)

Metadata فعلی:

```text
schema_version = 9
content_version = knowledge-3
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

## بانک محتوای نام‌ها

بسته `knowledge-3` یک بسته کشف و بازبینی‌پذیر با بیش از ۱۲۰ نام فارسی/ایرانی و معنی اولیه اضافه می‌کند. این رکوردها از فهرست `Appendix: Persian given names` در ویکی‌واژه به‌صورت Claim مستقل وارد شده‌اند و عمداً `unverified`/`pending` هستند؛ نمایش معنی به معنی تأیید قطعی ریشه‌شناختی نیست. نام‌های تاریخی با منبع تخصصی ایرانیکا همچنان Claimهای جداگانه و وضعیت مستقل خود را حفظ می‌کنند.

هر نام می‌تواند چند معنی، صورت نوشتاری، زبان، خاستگاه، تلفظ و Claim مستقل داشته باشد. توسعه بعدی باید به‌جای جایگزینی رکورد، منبع و Claim جدید اضافه کند تا اختلاف‌ها از بین نروند.

## بانک منابع

`sources` علاوه بر کتابشناسی پایه، اکنون مجوز محتوا، تاریخ دسترسی، دامنه پوشش و وضعیت بازبینی را نگه می‌دارد. منابع جامعه‌محور یا وبی برای کشف اولیه مفیدند اما تا بررسی مدخل‌به‌مدخل با وضعیت `editorial_pending`/`unverified` نمایش داده می‌شوند. متن منابع دارای حق نشر در دیتابیس کپی نمی‌شود؛ فقط فراداده، لینک و Claim کوتاه با ارجاع ذخیره می‌شود.

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
