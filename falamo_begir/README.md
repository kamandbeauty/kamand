# فالمو بگیر · FalamoBegir (فال حافظ)

![banner](https://github.com/amirrezahaqi/FalamoBegir-falehafez/assets/88787993/99d4b9e0-790e-4842-96a6-f8b0f3c9a956)

اپلیکیشن فلاتر فال حافظ — بر پایهٔ پروژهٔ متن‌باز
[amirrezahaqi/FalamoBegir-falehafez](https://github.com/amirrezahaqi/FalamoBegir-falehafez).

## ✨ امکانات

- 🎴 **۴۹۵ فال کاملاً آفلاین** — کل غزل‌های دیوان حافظ به همراه تعبیر هر فال، داخل خود برنامه ذخیره شده است؛ بدون اینترنت، توکن و سرور
- 🎵 موسیقی آفلاین حافظ با توقف هوشمند هنگام رفتن به پس‌زمینه
- ✍️ فونت داخلی وزیرمتن (بدون دانلود زمان اجرا)
- 📱 پشتیبانی از ناچ/status bar و حاشیه‌های امن صفحه

## 🗂 ساختار

| مسیر | توضیح |
|---|---|
| `assets/data/hafez_fals.json` | دیتاست ۴۹۵ غزل + تعبیر (آفلاین) |
| `lib/data/fal_repository.dart` | مخزن فال: بارگذاری، شمارش و انتخاب تصادفی |
| `lib/falscreen.dart` | صفحهٔ نمایش فال |
| `lib/homepage.dart` | صفحهٔ اصلی + موسیقی |
| `lib/config.dart` | اطلاعات نسخه |

## 🚀 اجرا

```bash
flutter pub get
flutter run
```

## 🧪 تست

```bash
flutter test
```
شامل smoke test اپ و تست سلامت کامل دیتاست آفلاین (۴۹۵ رکورد).

## 📜 مجوز دیتاست

دیتاست فال‌ها از پروژهٔ
[mahmoud-eskandari/HafezFaalDatabase](https://github.com/mahmoud-eskandari/HafezFaalDatabase)
با مجوز **GPL-3.0** گرفته شده است؛ متن مجوز در
`assets/data/LICENSE-fal-dataset.txt` قرار دارد.

## 👨‍💻 توسعه‌دهندهٔ نسخهٔ اولیه

امیررضا جلوس حقی — [github.com/amirrezahaqi](https://github.com/amirrezahaqi)
