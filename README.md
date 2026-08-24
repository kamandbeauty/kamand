# مدیر فروشگاه — Phase 1 + Phase 2 (ناقص)

اپلیکیشن اندروید مدیریت فروشگاه‌های اینستاگرامی/آنلاین.

## ⚠️ وضعیت فاز ۲ در این زیپ

فاز ۲ **هنوز کامل نیست** — این خروجی در وسط کار گرفته شده. آنچه تا این لحظه ساخته شده:

**کامل:** مدل‌های دامنه و Room برای Product/Category/Customer/Supplier/InventoryMovement
(به‌روزرسانی‌شده طبق اسپک فاز ۲)، `InventoryRepository` (تراکنشی، جلوگیری از موجودی منفی)،
`StockMovementCalculator`، use case های اعتبارسنجی محصول/مشتری/تأمین‌کننده، Repository های
Product/Category/Customer/Supplier، تست‌های واحد، صفحه‌ی لیست محصولات، فرم افزودن/ویرایش محصول.

**ناقص/غایب:**
- `ProductDetailScreen.kt` — **ساخته نشده** (ذخیره‌اش با خطا مواجه شد). `ProductDetailViewModel.kt`
  هست ولی چون صفحه‌اش نیست، این بخش کامپایل نمی‌شود مگر اضافه شود.
- صفحه‌ی تنظیم دستی موجودی (Stock Adjustment)
- صفحه‌ی مدیریت دسته‌بندی‌ها
- صفحات لیست/جزئیات/فرم مشتریان و تأمین‌کنندگان
- کامپوننت‌های `ProductSelector` / `CustomerSelector`
- اتصال این صفحات به Navigation (تب «محصولات» هنوز به `PhaseUpcomingScreen` قدیمی وصل است)

اگر می‌خواهید فاز ۲ کامل شود، فقط بگویید «ادامه بده».

## ⚠️ وضعیت Build (مهم، حتماً بخوانید)

این پروژه در محیطی ساخته شده که به **Maven گوگل (`dl.google.com`)** و سرویس دانلود Gradle
دسترسی نداشت، بنابراین:

- کد **کامپایل نشده و تست‌ها اجرا نشده‌اند** — همه‌چیز از نظر نحو Kotlin و منطق دستی بازبینی
  شده، اما تأیید نهایی build باید در Android Studio خودتان انجام شود.
- پوشه‌ی `gradle/wrapper` فقط شامل `gradle-wrapper.properties` است؛ فایل باینری
  `gradle-wrapper.jar` و اسکریپت‌های `gradlew` / `gradlew.bat` وجود ندارند.
  **راه‌حل**: پروژه را در Android Studio باز کنید (خودش Wrapper را می‌سازد)، یا اگر Gradle
  به‌صورت local نصب دارید دستور `gradle wrapper` را در ریشه‌ی پروژه اجرا کنید.

### قدم بعدی شما
1. پروژه را در Android Studio (Koala یا جدیدتر) باز کنید.
2. صبر کنید Gradle Sync کامل شود (نیاز به اینترنت برای دانلود وابستگی‌ها از Google/Maven دارد).
3. `./gradlew testDebugUnitTest` را اجرا کنید تا تست‌های `MoneyTest` و
   `PersianNumberFormatterTest` را ببینید (تست‌های JVM خالص‌اند، به شبیه‌ساز نیاز ندارند).
4. `./gradlew assembleDebug` برای ساخت APK دیباگ.

اگر خطایی گرفتید (مثلاً نسخه‌ی ناسازگار AGP/Kotlin با نسخه‌ی Android Studio شما)، برام بفرستید
تا رفعش کنیم.

---

## چه چیزی در فاز ۱ ساخته شد

### ۱. راه‌اندازی پروژه و معماری
- Gradle Kotlin DSL (root + app)، Kotlin ۲.۰، AGP ۸.۵، minSdk 26 / targetSdk 34
- Clean Architecture سه‌لایه: `domain` (مدل‌ها، بدون وابستگی به اندروید) / `data` (Room،
  Repository) / `presentation` (Compose، ViewModel)
- Hilt برای Dependency Injection (`ModirApplication`, `DatabaseModule`)
- Navigation Compose با Bottom Navigation (۵ تب طبق اسپک)

### ۲. Design System
- `core/designsystem/theme`: پالت رنگ ایندیگو-تیل (حرفه‌ای، مناسب مالی)، رنگ‌های سمانتیک
  (موفقیت/هشدار/خطا/اطلاعات)، تایپوگرافی با سلسله‌مراتب مشخص، اشکال گرد (Rounded Cards)،
  پشتیبانی از Dark Mode (ساختار آماده، فعلاً بر اساس سیستم)
- **راست‌چین (RTL) به‌صورت اجباری** در سطح `ModirTheme`، مستقل از locale دستگاه
- کامپوننت‌های پایه‌ی قابل‌استفاده‌ی مجدد: `StatCard`, `EmptyState`

### ۳. هسته‌ی مالی (مهم‌ترین بخش فاز ۱)
- `Money` — یک `value class` روی `Long` (تومان). **هیچ‌جا از Double/Float استفاده نشده.**
  - جمع/تفریق/ضرب دقیق
  - `percentOf` با رُند نیمه‌به‌بالا
  - `splitEvenly` — تقسیم اقساط بدون گم‌شدن حتی یک تومان (باقیمانده به قسط‌های اول اضافه می‌شود)
  - فرمت نمایش فارسی (`toPersianDisplayString`)
- `PersianNumberFormatter` — تبدیل ارقام به فارسی + جداکننده‌ی هزارگان (٬)

### ۴. مدل‌های دامنه (کامل طبق بخش ۶ تا ۲۲ اسپک)
Product, Category, InventoryMovement, Customer, Supplier, Order/OrderItem (با محاسبه‌ی
`realProfit` طبق مثال بخش ۲۲، و منطق `shippingMargin`/COD طبق بخش ۱۱)، Payment, SalesChannel,
ShippingProvider, Expense/ExpenseCategory, Employee/EmployeeCommissionRule, Receivable/Payable/
SupplierPayment/OrderReturn/FinancialTransaction, SettlementPlan/Installment (اسکیمای پایه —
موتور محاسبه‌ی کامل در فاز ۵)

### ۵. پایگاه‌داده (Room)
- ۲۲ Entity نرمال‌شده با Foreign Key و Index مناسب (بدون یک جدول غول‌پیکر)
- `MoneyConverters` (Long) و `EnumConverters` (String) — بدون هیچ مقدار مالی به‌صورت Double
- DAO برای هر Entity + چند Query تجمیعی برای داشبورد (تعداد سفارش امروز، ارزش موجودی، مطالبات/
  بدهی‌های معوق)

### ۶. Dashboard (شل اولیه) + Onboarding
- `DashboardRepository` چند Flow را ترکیب می‌کند → `DashboardSnapshot`
- `DashboardScreen`: کارت‌های آماری (فروش امروز/این‌ماه، سود خالص، سفارش‌ها، مطالبات، بدهی‌ها،
  ارزش موجودی) + بخش «امروز چه کار کنم؟» با شدت رنگی (بحرانی/مهم/متوسط)
- Empty State کامل طبق بخش ۲۷ اسپک برای حالت بدون داده
- Onboarding سه‌مرحله‌ای (نام فروشگاه، صاحب، دسته‌بندی/موجودی نقدی اولیه)
- `MainActivity` بین Onboarding و اپ اصلی گیت می‌زند (بر اساس `StoreProfileEntity`)

## ساختار پروژه

```
app/src/main/java/com/modir/forushgah/
  core/common/          Money.kt, PersianNumberFormatter.kt
  core/designsystem/    theme/, component/
  di/                   DatabaseModule.kt
  domain/model/         مدل‌های دامنه (بدون وابستگی به Android/Room)
  data/local/entity/    Room Entities
  data/local/dao/       Room DAOs
  data/local/           AppDatabase.kt, converter/
  data/repository/      DashboardRepository, StoreProfileRepository
  presentation/         dashboard/, onboarding/, navigation/
  MainActivity.kt, ModirApplication.kt, RootViewModel.kt
app/src/test/java/...   MoneyTest.kt, PersianNumberFormatterTest.kt
```

## Entity های دیتابیس
Product, Category, InventoryMovement, Customer, Supplier, Order, OrderItem, Payment,
SalesChannel, ShippingProvider, Expense, ExpenseCategory, Employee, EmployeeCommissionRule,
Receivable, Payable, SupplierPayment, OrderReturn, FinancialTransaction, SettlementPlan,
Installment, StoreProfile — **۲۲ Entity**

## تست‌ها
`MoneyTest.kt` (۹ تست) و `PersianNumberFormatterTest.kt` (۵ تست) — شامل بازتولید دقیق مثال‌های
عددی خودِ اسپک (کمیسیون ۷٪ روی ۱۰,۰۰۰,۰۰۰؛ سود واقعی سفارش؛ مارجین ارسال). این تست‌ها خالص
JVM‌اند و بدون شبیه‌ساز اجرا می‌شوند، اما در این محیط اجرا نشدند (به دلیل نبود Gradle/کیت‌لین
مدرن) — لطفاً پس از باز کردن پروژه در Android Studio اجرایشان کنید.

## چیزی که هنوز ساخته نشده (فازهای بعدی طبق برنامه)
فاز ۲: صفحات کامل محصولات/موجودی/مشتریان/تأمین‌کنندگان
فاز ۳: صفحات کامل سفارش/پرداخت/ارسال/مرجوعی
فاز ۴: موتور مالی کامل (سود و زیان واقعی، هزینه‌ها، مطالبات/بدهی‌ها به‌صورت end-to-end)
فاز ۵: موتور اقساط/تسویه کامل (فعلاً فقط اسکیمای دیتابیس آماده است)
فاز ۶ تا ۸: گزارش‌ها، جریان نقدی، پولیش UX، تست‌های سناریوی کامل، release build

تب‌های «سفارش‌ها»، «محصولات»، «مالی»، «بیشتر» در ناوبری فعال‌اند اما فعلاً یک پیام
«در فاز بعدی تکمیل می‌شود» نشان می‌دهند — این تنها بخشی است که placeholder دارد؛ Dashboard و
Onboarding کاملاً کاربردی‌اند.
