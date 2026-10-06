# طرح دیتابیس محلی

نسخه فعلی از SQLite مستقیم با Migration صریح استفاده می‌کند تا بدون کد تولیدشده، رفتار قابل بررسی و قابل تست داشته باشد. در صورت نیاز، لایه DAO می‌تواند در مرحله بعد به Drift منتقل شود؛ قرارداد Repository و Schema مستقل از این تصمیم نگه داشته شده‌اند.

## جدول‌های Phase 1

- `database_metadata`
- `sources`
- `names`
- `name_variants`
- `abjad_systems`
- `abjad_letters`
- `profiles`
- `archive_entries`

## وضعیت محتوا

مقادیر معتبر برای `status`:

- `verified`
- `unverified`
- `disputed`
- `deprecated`

مقادیر `confidence`:

- `high`
- `medium`
- `low`

## نسخه‌های آینده

جداول `name_meanings`، `name_etymologies`، `name_languages`، `name_cultures`، `name_genders`، `name_pronunciations`، `name_popularity`، `name_historical_usage`، `name_literary_references`، `name_famous_people`، `name_related_names`، `source_claims`، `numerology_systems`، `numerology_rules` و `compatibility_rules` در Migrationهای بعدی اضافه می‌شوند. تا قبل از ورود داده منبع‌دار، معنی و ریشه در رکورد پایه به‌صورت وضعیت‌دار نگه داشته می‌شود.
