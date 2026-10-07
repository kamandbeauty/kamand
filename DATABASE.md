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

## بسته نام‌های فارسی از GitHub

بسته `names.json` از مخزن [nabidam/persian-names](https://github.com/nabidam/persian-names) با commit `68f5cb39a25c19ecaf6f60f3181aea200f8206f` وارد می‌شود. این مجموعه ۸۸۱۶ صورت نام و برچسب جنسیت دارد و تحت MIT منتشر شده است؛ متن مجوز در `third_party/persian_names/LICENSE` نگهداری می‌شود.

این منبع فقط برای نام، صورت نوشتاری و برچسب جنسیت استفاده می‌شود. معنی، ریشه‌شناسی، لاتین‌نویسی و تلفظ از این فایل تولید نمی‌شوند و تا بررسی مستقل `نامشخص`/`unverified` باقی می‌مانند. صورت‌های تکراری پس از نرمال‌سازی به‌عنوان Variant ثبت و Claim آن‌ها به منبع متصل می‌شود.

## واژه‌یاب API

مستندات [Vajehyab API v3](https://api.vajehyab.com/api/documentation) به‌عنوان منبع فرهنگ واژگان ثبت شده است. API متدهای `search`، `word` و `suggest` دارد و طبق مستندات به توکن توسعه‌دهنده نیازمند است. دیتابیس `name` برای فرهنگ نام‌ها و دیتابیس‌های `dehkhoda`، `moein` و `amid` برای بررسی معنی و تلفظ قابل استفاده هستند.

توکن در کد، Git یا Seed قرار نمی‌گیرد. اتصال آنلاین باید اختیاری، قابل خاموش‌کردن، cache‌شونده و سازگار با Offline First باشد. تا دریافت توکن و تأیید شرایط استفاده، هیچ معنی یا تلفظی از API به‌صورت خودکار به رکوردهای تولیدی اضافه نمی‌شود.

## محاسبه سنتی جفر

منبع `JAFR` در Encyclopaedia Iranica توضیح می‌دهد که ابزار اصلی جفر، علم حروف و ارزش عددی ۲۸ حرف ابجد است. بر همین اساس، Rule نسخه اول برنامه فقط این بخش قابل بازبینی را پیاده می‌کند:

```text
جفر = جمع ارزش عددی حروف در نگاشت استاندارد ابجد
کاهش رقمی = مقدار مشتق‌شده برای نمایش، نه تفسیر جفری
```

حروف فارسی پ، چ، ژ و گ در نگاشت استاندارد مقدار حدس‌زده‌شده ندارند و نتیجه برای ورودی دارای آن‌ها `Unknown` می‌شود. این Feature هیچ ادعایی درباره غیب، شخصیت، رابطه، سرنوشت یا آینده تولید نمی‌کند و از محاسبه جفر با ابجد و عددشناسی سنتی جدا از دانش علمی نام‌ها نگهداری می‌شود.

Metadata فعلی:

```text
schema_version = 9
content_version = knowledge-6
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

بسته `knowledge-5` علاوه بر بسته کشف قبلی، دو منبع نام مستقل را نگه می‌دارد:

- `nabidam/persian-names`: تعداد ۸۸۱۶ رکورد خام با برچسب جنسیت؛ معنی، ریشه‌شناسی، لاتین‌نویسی و تلفظ از این مجموعه تولید نمی‌شوند.
- `بانک جامع نام‌ها و اسامی دختران و پسران ایرانی`: تعداد ۲۸۶۱ عنوان از فایل HTML ارائه‌شده؛ در این مرحله فقط عنوان نام، صورت‌های داخل پرانتز و Claim عضویت وارد می‌شوند و متن توضیحات کتاب کپی نمی‌شود.

هر دو منبع پس از نرمال‌سازی با وضعیت `unverified`/`pending` ثبت می‌شوند و رکوردهای مشترک به‌جای Duplicate مستقل، به‌عنوان Claim یا Variant منبع‌دار نگهداری می‌شوند.

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
