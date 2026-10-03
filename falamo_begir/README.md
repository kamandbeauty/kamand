# دیوان و فال حافظ · Divan & Fal-e Hafez

اپلیکیشن فلاتر **دیوان حافظ + فال حافظ** — نسخهٔ توسعه‌یافتهٔ پروژهٔ متن‌باز
[amirrezahaqi/FalamoBegir-falehafez](https://github.com/amirrezahaqi/FalamoBegir-falehafez).

## ✨ امکانات

- 📖 **دیوان کامل حافظ** — هر ۴۹۵ غزل با فهرست، **جستجو در متن و شمارهٔ غزل**، و پیمایش غزل قبلی/بعدی
- 🎴 **۴۹۵ فال کاملاً آفلاین** — تعبیر هر فال کنار هر غزل و در صفحهٔ فال؛ بدون اینترنت، توکن و سرور
- 🎵 موسیقی آفلاین حافظ با توقف هوشمند هنگام رفتن به پس‌زمینه
- ✍️ فونت داخلی وزیرمتن (بدون دانلود زمان اجرا)
- 📱 پشتیبانی از ناچ/status bar و حاشیه‌های امن صفحه

## 🗂 ساختار

| مسیر | توضیح |
|---|---|
| `assets/data/hafez_fals.json` | دیتاست ۴۹۵ غزل + تعبیر (آفلاین) |
| `lib/data/fal_repository.dart` | مخزن: بارگذاری، شمارش، تصادفی |
| `lib/divan_screen.dart` | فهرست دیوان + جستجو |
| `lib/ghazal_screen.dart` | صفحهٔ خواندن غزل + تعبیر فال |
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
شامل smoke test اپ، مسیر «دیوان ← خواندن غزل» و تست سلامت کامل دیتاست آفلاین (۴۹۵ رکورد).

## 📜 مجوز دیتاست

دیتاست فال‌ها از پروژهٔ
[mahmoud-eskandari/HafezFaalDatabase](https://github.com/mahmoud-eskandari/HafezFaalDatabase)
با مجوز **GPL-3.0** گرفته شده است؛ متن مجوز در
`assets/data/LICENSE-fal-dataset.txt` قرار دارد.

## 👨‍💻 توسعه‌دهنده

**استودیو جاوید · Studio Javid**

نسخهٔ اولیه: امیررضا جلوس حقی — [github.com/amirrezahaqi](https://github.com/amirrezahaqi)
