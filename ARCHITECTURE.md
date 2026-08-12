# معماری و راهنمای سیستم «فاکتور روبی» (Architecture Overview)

اپلیکیشن «فاکتور روبی» بر پایه اصول **معماری تمیز (Clean Architecture)** و معماری لایه‌ای Flutter/Dart پیاده‌سازی شده است.

---

## ۱. لایه‌های معماری (Layered Architecture)

```
lib/
├── core/                  # هسته برنامه (تم‌ها، ثابت‌ها، تبدیل اعداد فارسی، تاریخ شمسی)
│   ├── constants/
│   ├── theme/
│   └── utils/
├── database/              # لایه دیتابیس محلی (Drift / SQLite / Migrations)
├── models/                # لایه مدل‌های داده (Data Models & JSON Mappers)
├── providers/             # لایه مدیریت وضعیت (Riverpod State Notifiers)
└── screens/               # لایه رابط کاربری (UI Components & Screens)
    ├── onboarding/
    ├── dashboard/
    ├── invoice/
    ├── customer/
    ├── product/
    └── settings/
```

---

## ۲. تکنولوژی‌های اصلی (Tech Stack)

- **فریم‌ورک:** Flutter & Dart
- **مدیریت وضعیت (State Management):** Flutter Riverpod (`StateNotifierProvider`)
- **دیتابیس محلی (Offline Database):** SQLite / Drift (`drift`, `sqlite3_flutter_libs`)
- **تقویم و تاریخ شمسی:** `shamsi_date`, `intl`
- **تولید PDF و چاپ:** `pdf`, `printing`
- **اشتراک‌گذاری:** `share_plus` (پشتیبانی از Android Share Sheet)
- **کیوآرکد (QR Code):** `qr_flutter`
- **امنیتی:** `local_auth` (بیومتریک / PIN Lock)

---

## ۳. ویژگی‌های کلیدی آفلاین (Offline-First Approach)

1. **بدون نیاز به اینترنت:** تمامی محاسبات فاکتور، تخفیف، هزینه ارسال و مانده مشتری به صورت ۱۰۰٪ آفلاین محاسبه و ذخیره می‌شود.
2. **پشتیبان‌گیری محلی:** خروجی مستقیم JSON برای فایل‌های بکاپ که به راحتی قابل انتقال به گوشی جدید است.
3. **پشتیبانی کامل RTL:** چیدمان تمامی المان‌ها، فونت استاندارد Vazirmatn و تبدیل اعداد انگلیسی به فارسی.

---

## ۴. دستورات ساخت و اجرا (Build & Run Instructions)

### اجرای برنامه در محیط توسعه:
```bash
flutter pub get
flutter run
```

### ساخت نسخه‌های Release اندروید:
```bash
./build_apk.sh
# یا با فرمان مستقیم فلاتر:
flutter build apk --release --split-per-abi
```

APKهای کم‌حجم در مسیر زیر قرار می‌گیرند:
`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

برای Google Play از AAB استفاده کنید:
`build/app/outputs/bundle/release/app-release.aab`
