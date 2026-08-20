<div dir="rtl">

# حکم با هوش مصنوعی — Hokm with AI

**بازی کارتی حکم چهارنفرهٔ آفلاین با Flutter + Flame — با هوش مصنوعی واقعی**

Flutter · Flame · Dart · بدون سرور · بدون حساب کاربری · کاملاً آفلاین

</div>

---

## ساختار

```
hokm/
├── lib/
│   ├── core/            ثابت‌ها، رشته‌های فارسی، تم اپ، ابزار ارقام فارسی
│   ├── game_engine/     ← منطق خالص بازی (بدون هیچ وابستگی به Flutter)
│   │   ├── models/      Card, Suit, Rank, Deck, Player, Team, Trick
│   │   ├── rules/       قوانین: رفتن به خال، برندهٔ دور
│   │   ├── state/       GameState سریالایزپذیر + enumها (مرحله/جایگاه/دشواری)
│   │   ├── scoring/     ScoreManager — کوت، حاکم‌کوت، هدف مسابقه
│   │   ├── managers/    TurnManager, HukumManager, DealManager
│   │   └── hokm_engine.dart  ارکستراتور + رویدادها
│   ├── ai/              ← هوش مصنوعی (هیچ‌وقت دست دیگران را نمی‌بیند)
│   │   ├── ai_view.dart          مرز ضدتقلب — فقط اطلاعات عمومی + دست خودی
│   │   ├── memory/      MemoryTracker — کارت‌های رفته، خال‌های خالیِ اثبات‌شده
│   │   ├── evaluation/  Card/Hand/Trick Evaluator
│   │   ├── probability/ ProbabilityEngine — تخمین توزیع کارت‌های نامعلوم
│   │   ├── strategy/    StrategyEngine (Easy/Normal/Hard) + HukumSelector
│   │   └── players/     AiPlayer
│   ├── game/            ← لایهٔ Flame (فقط نمایش و انیمیشن)
│   │   ├── cards/       رندر برداری کارت‌ها (رو/پشت) — بدون فایل تصویری
│   │   ├── table/       هندسهٔ میز و پالت تم‌ها
│   │   ├── components/  CardComponent, TableBackground
│   │   ├── animations/  SmoothMotion (حرکت قوس‌دار با منحنی طبیعی)
│   │   ├── effects/     هالهٔ نوبت، پالس برد دور
│   │   ├── hokm_game.dart      صحنه — بر، پخش، بازی، جمع‌کردن دور
│   │   └── game_controller.dart واسط موتور ↔ صحنه ↔ صدا ↔ ذخیره
│   ├── screens/         خانه — بازی (HUD) — تنظیمات
│   ├── audio/           SoundManager (افکت‌ها و موسیقی، تولید procedural)
│   ├── storage/         تنظیمات + ذخیرهٔ مسابقهٔ نیمه‌تمام (SharedPreferences)
│   └── main.dart
├── test/                تست‌های موتور، قوانین، امتیاز، ذخیره/بازیابی، AI
├── tool/gen_sfx.py      تولید افکت‌های صوتی (numpy) — دارایی کاملاً اختصاصی
├── assets/              فونت Vazirmatn (OFL)، صداها، لوگو
└── android/             پروژهٔ اندروید (Kotlin DSL)
```

## اجرا و تست

```bash
cd hokm
flutter pub get
flutter test                 # تست‌های موتور/قوانین/AI (مهم: قبل از UI اجرا شود)
flutter analyze
flutter run                  # اجرای دیباگ روی گوشی/شبیه‌ساز
```

## ساخت APK

```bash
cd hokm
flutter build apk --release
# خروجی: hokm/build/app/outputs/flutter-apk/app-release.apk
```

برای انتشار واقعی، امضای ریلیز را در `android/app/build.gradle.kts` جایگزین امضای دیباگ کنید
(`keystore.properties` + signingConfigs — هرگز keystore را کامیت نکنید).

## CI

تمپلیت گردکار در `hokm/ci/hokm-flutter.yml` است (قرارداد مخزن: تمپلیت‌ها کنار
خود پروژه نگه داشته می‌شوند). برای فعال‌سازی، آن را به `.github/workflows/`
ریشهٔ مخزن کپی کنید. این گردکار روی هر تغییر در `hokm/**`:
۱. `flutter analyze`
۲. `flutter test` (شامل شبیه‌سازی مسابقهٔ کامل AI↔AI و بررسی قانونی‌بودن همهٔ حرکت‌ها)
۳. ساخت APK ریلیز و آپلود به‌عنوان Artifact

## تصمیم‌های معماری کلیدی

* **جداسازی کامل منطق از UI** — `game_engine/` حتی یک import از Flutter ندارد؛
  می‌توان آن را جداگانه تست/بازاستفاده کرد (مثلاً برای سرور آنلاین آینده).
* **ضدتقلب AI در معماری** — AI فقط `AiGameView` می‌گیرد که از روی GameState
  ساخته می‌شود و عمداً هر دادهٔ غیرعمومی (دست دیگران) را حذف می‌کند.
* **رویدادمحوری** — موتور با رویداد حرف می‌زند؛ انیمیشن‌ها ریتم‌بندی جدا دارند.
* **کارت‌های برداری procedural** — هیچ تصویر PNG برای کارت نیست؛
  تیز در هر DPI و حجم APK بسیار کمتر.
* **صداها procedural** — با `tool/gen_sfx.py` تولید شده‌اند؛ بدون مشکل لایسنس.
* **استخر کارت** — ۵۲ کامپوننت کارت یک‌بار ساخته و هر دست بازاستفاده می‌شوند
  (بدون object creation مداوم → ۶۰ فریم روان).

## فونت

Vazirmatn (FD — ارقام فارسی) — SIL Open Font License. متن لایسنس:
`assets/fonts/Vazirmatn-OFL-LICENSE.txt`.
