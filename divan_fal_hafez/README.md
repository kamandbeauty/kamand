# دیوان و فال حافظ · Divan & Fal-e Hafez

اپلیکیشن فلاتر **دیوان کامل حافظ + فال حافظ** با طراحی ساده، کارآمد و زیبا — کاملاً آفلاین.
بر پایهٔ پروژهٔ متن‌باز [amirrezahaqi/FalamoBegir-falehafez](https://github.com/amirrezahaqi/FalamoBegir-falehafez).

## 📚 این مجموعه آثارهایی از حافظ را شامل می‌شود (۵۹۵ اثر)

| بخش | تعداد |
|---|---|
| غزلیات (با تعبیر فال) | ۴۹۵ |
| رباعیات | ۴۲ |
| قطعات | ۳۴ |
| قصاید | ۳ |
| اشعار منتسب | ۱۹ |
| مثنویات (ساقی‌نامه و الا ای آهوی وحشی) | ۲ |

## ✨ امکانات نرم‌افزار

- 🎴 **فال حافظ آفلاین** — هر بار یک غزل تصادفی با تعبیر
- 🔍 **جستجو در کل مجموعه** (متن، عنوان یا شمارهٔ شعر) + فیلتر بخش‌ها
- 📤 **اشتراک‌گذاری شعرها** در شبکه‌ها و برنامه‌های دیگر
- ❤️ **«اشعار دلخواه»** — ثبت شعرهای موردعلاقه (آفلاین ذخیره می‌شود)
- 📋 **کپی اشعار** برای استفاده در نرم‌افزارهای مختلف
- ✍️ **تنظیم قلم** (وزیرمتن / ساحل / شبنم)
- 🔠 **تنظیم اندازهٔ قلم** با اسلایدر + پیش‌نمایش زنده
- 🤏 **بزرگنمایی متن شعر با دو انگشت** (پینچ‌زوم، ذخیره می‌شود)
- 🎵 موسیقی آفلاین حافظ با توقف هوشمند در پس‌زمینه
- 📱 سازگار با انواع موبایل و **تبلت** (حاشیهٔ امن + عرض حداکثری محتوا) — بدون نیاز به اینترنت، توکن و سرور

## 🗂 ساختار

| مسیر | توضیح |
|---|---|
| `assets/data/hafez_divan.json` | دیتاست ۵۹۵ اثر در ۶ بخش + تعبیر غزلیات |
| `lib/data/poem.dart` | مدل شعر و بخش‌های دیوان |
| `lib/data/divan_repository.dart` | مخزن: بارگذاری، بخش‌ها، جستجو، غزل تصادفی |
| `lib/data/settings_service.dart` | تنظیمات + دلخواه‌ها (SharedPreferences) |
| `lib/divan_screen.dart` | فهرست دیوان + جستجو + چیپ بخش‌ها |
| `lib/poem_screen.dart` | خواندن شعر: تعبیر، اشتراک، کپی، دلخواه، زوم |
| `lib/favorites_screen.dart` | اشعار دلخواه |
| `lib/settings_screen.dart` | قلم و اندازهٔ قلم |
| `lib/falscreen.dart` | صفحهٔ فال تصادفی |
| `lib/homepage.dart` | صفحهٔ اصلی + موسیقی |

## 🚀 اجرا

```bash
flutter pub get
flutter run
```

## 🧪 تست

```bash
flutter test
```
شامل smoke test اپ، مسیر «دیوان ← خواندن شعر» و تست سلامت کامل دیتاست (۵۹۵ رکورد، تعبیر هر ۴۹۵ غزل).

## 🔏 امضای امن نسخهٔ اندروید

بیلد Release در GitHub Actions فقط با این چهار Repository Secret اجرا می‌شود:

- `DIVAN_RELEASE_KEYSTORE_BASE64`
- `DIVAN_RELEASE_KEYSTORE_PASSWORD`
- `DIVAN_RELEASE_KEY_ALIAS`
- `DIVAN_RELEASE_KEY_PASSWORD`

Keystore هنگام اجرا فقط در پوشهٔ موقت Runner بازسازی می‌شود، وارد مخزن یا artifact
نمی‌شود و پس از پایان Job از بین می‌رود. پایپ‌لاین پس از ساخت نیز امضای هر چهار APK
را با `apksigner` بررسی می‌کند و یکسان بودن اثر انگشت SHA-256 گواهی آن‌ها را تأیید
می‌کند. بیلد Release بدون اطلاعات کامل امضا متوقف می‌شود و هیچ fallback به کلید
Debug ندارد.

## 📜 مجوزها و سپاس

- **متن اشعار:** مجموعهٔ [ChronologicalPersianPoetryDataset](https://github.com/aghasemi/ChronologicalPersianPoetryDataset) (بر پایهٔ دادهٔ گنجور) با مجوز **CC BY-SA 4.0**
- **تعبیر فال غزلی‌ها:** [mahmoud-eskandari/HafezFaalDatabase](https://github.com/mahmoud-eskandari/HafezFaalDatabase) با مجوز **GPL-3.0** (متن مجوز: `assets/data/LICENSE-fal-dataset.txt`) — تعبیرها با تطبیق محتوایی مصرع اول به غزل‌های متن جدید متصل شده‌اند
- **قلم‌ها:** وزیرمتن، ساحل و شبنم از [راستیکردار](https://github.com/rastikerdar) با مجوز **SIL OFL**

## 👨‍💻 توسعه‌دهنده

**استودیو جاوید · Studio Javid**
