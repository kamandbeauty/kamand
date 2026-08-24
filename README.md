# مدیر فروشگاه — Phase 1 + 2 + 3 (کامل)

اپلیکیشن اندروید مدیریت فروشگاه‌های اینستاگرامی/آنلاین.

> **وضعیت فاز ۳ (سفارش/پرداخت/ارسال/مرجوعی): کامل.** جزئیات در بخش
> «چه چیزی در فاز ۳ ساخته شد». فاز ۴ (موتور مالی) هنوز شروع نشده — این فاز فقط
> داده‌های عملیاتی پاک و قابل‌اتکا برای آن می‌سازد.

## وضعیت فاز ۲ — کامل ✅

فاز ۲ (محصولات/موجودی/مشتریان/تأمین‌کنندگان) کامل شده است. خلاصهٔ آنچه اضافه شد:

- **`ProductDetailScreen`** (صفحه‌ای که گم شده بود و کامپایل را می‌شکست): کارت موجودی
  با StockBadge و دکمهٔ تنظیم موجودی، کارت قیمت‌ها (خرید/فروش/بسته‌بندی/سود تخمینی)،
  مشخصات (SKU، بارکد، دسته‌بندی، وضعیت)، یادداشت و **تاریخچهٔ کامل حرکات موجودی**
  (نوع حرکت، دلتا، قبل/بعد، تاریخ، دلیل) + بایگانی محصول.
- **تنظیم دستی موجودی (Stock Adjustment)** — دو ورودی، هر دو با همین منطق (spec §4):
  دیالوگ `StockAdjustmentSheet` از صفحهٔ جزئیات محصول، و **صفحهٔ مستقل
  `StockAdjustmentScreen`** (مسیر `stock_adjustment`، از تب «بیشتر») که کاربر محصول را
  خودش انتخاب/جستجو می‌کند، موجودی فعلی را می‌بیند، موجودی جدید + دلیل را وارد می‌کند
  و سیستم اختلاف را خودش محاسبه و ADJUSTMENT_IN/OUT ثبت می‌کند.
- **انتخاب تأمین‌کننده در فرم محصول** — چیدمان chip برای `supplierId` (اختیاری) با
  گزینهٔ «بدون تأمین‌کننده».
- **مرجع در گردش کالا (spec §6)** — هر حرکت با «مرجع: سفارش #N / تنظیم موجودی /
  ثبت دستی» نمایش داده می‌شود.
- **هوک‌های داده در جزئیات** — جزئیات مشتری: تعداد سفارش‌ها (واقعی) + خرید کل/سود
  کل/مطالبات باز (placeholder تا فاز ۴). جزئیات تأمین‌کننده: خرید کل/پرداختی‌ها/
  بدهی باز + بخش‌های «تاریخچه خرید» و «تاریخچه پرداخت» (تا فاز ۴/۵).
- **دادهٔ نمونهٔ فقط-دیباگ (spec §۱۷)** — `SampleDataSeeder`: فقط در بیلد دیباگ و فقط
  وقتی دیتابیس خالی است، ۴ محصول (از جمله کم‌موجود و ناموجود)، ۳ مشتری، ۲
  تأمین‌کننده، ۳ دسته و چند حرکت موجودی می‌سازد. هیچ‌وقت روی دیتای موجود اجرا نمی‌شود
  و در ریلیز کاملاً غیرفعال است.
- **داشبورد (spec §۵)** — آیکن «امروز چه کار کنم؟» برای موجودی کم: «کالاهای رو به
  اتمام: N کالا».
- **مدیریت دسته‌بندی‌ها** — `CategoryListScreen`/`ViewModel`: فهرست با شمارندهٔ محصول،
  افزودن، ویرایش (تغییر نام)، بایگانی؛ ورودی از آیکن نوار بالای صفحهٔ محصولات.
- **مشتریان** — لیست + جستجو، فرم افزودن/ویرایش (با `ValidateCustomerUseCase`)،
  صفحهٔ جزئیات/پروفایل (اطلاعات تماس + تعداد سفارش‌ها از OrderDao).
- **تأمین‌کنندگان** — همان سه‌گانهٔ لیست/فرم/جزئیات + بایگانی تأمین‌کننده.
- **کامپوننت‌های قابل‌استفاده** — `ProductSelectorDialog` و `CustomerSelectorDialog`
  (با امکان ساخت مشتری درون‌خطی طبق §۹ اسپک) برای استفاده در فاز ۳ (سفارش).
- **ناوبری کامل** — همهٔ مسیرها در `ModirNavGraph` تعریف و متصل شدند؛ تب «محصولات»
  دیگر placeholder نیست و تب «بیشتر» به مشتریان/تأمین‌کنندگان/تنظیمات وصل است.
  تب پایین در صفحات فرعی هم هایلایت می‌ماند.
- `DateTimeFormatter` — تاریخ/ساعت نمایشی با اعداد فارسی.

جزئیات فنی در بخش «چه چیزی در فاز ۲ ساخته شد» پایین‌تر.

## ⚠️ وضعیت Build (مهم، حتماً بخوانید)

این پروژه در محیطی ساخته شده که به **Maven گوگل (`dl.google.com`)** و سرویس دانلود Gradle
دسترسی نداشت، بنابراین:

- کد **کامپایل نشده و تست‌ها اجرا نشده‌اند** — همه‌چیز (شامل کد جدید فاز ۲) از نظر نحو
  Kotlin و منطق دستی بازبینی شده، اما تأیید نهایی build باید در Android Studio خودتان
  انجام شود.
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

## چه چیزی در فاز ۳ ساخته شد

### ۱. دامنهٔ سفارش (spec §1/§2)
مدل `Order`/`OrderItem` (عکس‌برداری قیمت در لحظه فروش برای سود تاریخی دقیق) با
همهٔ فیلدهای اسپک: شماره سفارش، مشتری، تاریخ، ردیف‌ها (جدا و نرمال‌شده)، تخفیف
ردیف/سفارش، مارجین ارسال دریافتی، هزینه واقعی ارسال، بسته‌بندی، روش پرداخت،
کانال فروش، وضعیت (۷ وضعیت با برچسب فارسی)، نوع پرداخت ارسال
(`SELLER_PAID`/`CUSTOMER_PREPAID`/`COD`). کلیدهای محاسباتی:
`productSubtotal`، `totalCustomerPayment` (فقط ارسال پیش‌پرداختی در مجموع
مشتری می‌آید؛ COD و فروشنده‌پرداخت نمی‌آیند — سناریوهای A/B/C اسپک دقیقاً همین
مدل‌اند).

### ۲. `OrderRepository` — هستهٔ تراکنشی (spec §19/§20/§26)
هر تغییر وضعیت در **یک تراکنش Room** است (سفارش + ردیف‌ها + حرکت موجودی +
رویدادهای مالی، یا همه یا هیچ):
- `createOrder`: ثبت سفارش + شمارهٔ نهایی `SF-<id>` + حرکت `SALE` برای هر ردیف
  از مسیر `InventoryRepository`. **فروش بیش از موجودی = خطا + برگشت کامل**
  (هرگز موجودی منفی خاموش). **ایدمپوتانس**: حرکت‌ها با
  (referenceType, referenceId, movementType) کلید می‌شوند و قبل از نوشتن
  شمارش می‌شوند — هیچ سفارشی دو بار موجودی کم نمی‌کند.
- `cancelOrder`: برگشت موجودی با حرکت `RETURN` ارجاع‌داده‌شده به سفارش،
  ایدمپوتان (لغو مکرر = یک‌بار برگشت).
- `createReturn`: مرجوعی کامل/جزئی با مقدار هر کالا؛ فقط واحدهای مرجوع‌شده
  به انبار برمی‌گردند؛ سقف بر اساس «سفارش‌شده − مرجوع‌شده قبلی»؛ مرجوعی کامل →
  وضعیت سفارش `RETURNED`.
- `recordPayment` (کامل/جزئی، بیش‌پرداخت ممنوع)، `createRefund` (هرگز بیش از
  پرداختی؛ سوابق پرداخت دست‌نخورده می‌مانند).
- **رویدادهای مالی** (spec §25): `ORDER_CREATED`، `ORDER_CANCELLED`،
  `PAYMENT_RECEIVED`، `REFUND`، `PACKAGING_EXPENSE`، `RETURN_CREATED` به‌صورت
  سطر در `financial_transactions` — بستر تمیز برای فاز ۴ بدون محاسبهٔ سود.

### ۳. صفحات
- **ثبت سفارش** (یک صفحهٔ سریع، spec §3/§27): انتخاب مشتری (دیالوگ قابل‌استفاده +
  ساخت درون‌خطی)، افزودن کالا (دیالوگ انتخاب محصول)، استپر تعداد با سقف
  موجودی، قیمت واحد ویرایش‌پذیر، تخفیف ردیف/سفارش (درصد یا مبلغ با پیش‌نمایش)،
  پیک + نحوه پرداخت ارسال + مبالغ، روش پرداخت + کانال فروش، یادداشت، و
  **خلاصهٔ چسبان پایین** (کالاها/تخفیف/ارسال/مبلغ نهایی) + CTA «ثبت سفارش».
- **لیست سفارش‌ها** (spec §15/§16): جستجوی زنده (شماره/نام مشتری/موبایل — یک
  query با JOIN)، فیلتر وضعیت، ردیف با شماره/مشتری/تاریخ/مبلغ/وضعیت + نشان‌های
  کوچک (پس‌کرایه، اقساطی، پرداخت باقی‌مانده).
- **جزئیات سفارش** (spec §17): هدر (شماره/وضعیت/تاریخ/مبلغ)، مشتری، کالاها،
  ارسال (پیک/نحوه پرداخت/دریافتی/هزینه واقعی/بسته‌بندی)، پرداخت (مجموع/
  پرداخت‌شده/باقی‌مانده + سوابق + ثبت پرداخت)، استردادها، مرجوعی‌ها (با تغییر
  وضعیت)، یادداشت، لغو سفارش.
- **لیست مرجوعی‌ها** (spec §28) از آیکن نوار بالا.

### ۴. داده‌های پایهٔ قابل‌توسعه (spec §8/§9/§10)
`PaymentMethodEntity` + `SalesChannel` + `ShippingProvider` عمومی و قابل
افزودن؛ `ReferenceDataSeeder` در استارتاپ، آیدمپوتان، مقادیر پیش‌فرض:
کانال‌ها (اینستاگرام، وب‌سایت، باسلام، ترب، اسنپ‌پی، سایر)، پیک‌ها (پست،
تیپاکس، پیک، سایر)، روش‌های پرداخت (نقدی، کارت‌به‌کارت، کارت بانکی، درگاه،
اقساطی، سایر). کانال و روش پرداخت دو مفهوم جداست — در منطق محاسبه هیچ
پلتفرم خارجی hardcoded نشده.

### ۵. دیتابیس
`version = 3`: ستون‌های `createdAt/updatedAt` سفارش، `reference` و
`paymentMethodId` پرداخت، `status` مرجوعی، Entity های جدید `OrderReturnItem`
(مقادیر مرجوعی ردیفی)، `Refund`، `PaymentMethod`. (destructive migration
pre-release هنوز فعال است.)

### ۶. تست‌های فاز ۳
- `OrderPricingTest` — مثال‌های عددی اسپک: تخفیف ۱۰٪ روی ۱٬۰۰٬۰۰، سناریو
  A (۸۰٬۰۰+۷۰٬۰۰۰=۸۷٬۰۰)، B (COD)، C (فروشنده‌پرداخت)، جداگانه‌بودن
  بسته‌بندی.
- `ValidateOrderUseCaseTest` — همهٔ قوانین §29 با پیام‌های فارسی.
- `PaymentTotalsTest` — پرداخت کامل/جزئی/مانده (مثال ۵٬۰۰۰٬۰۰ ← ۲٬۰۰۰٬۰۰)،
  استرداد.
- `OrderRepositoryTest` (Robolectric + Room واقعی) — کسری موجودی هنگام ثبت
  (۲۰−۳=۱۷)، **رد فروش بیش از موجودی با rollback کامل**، برگشت موجودی در لغو
  + **ایدمپوتانس لغو مکرر**، مرجوعی کامل (→ وضعیت RETURNED)، مرجوعی جزئی
  (۲ از ) + سقف مرجوعی‌های بعدی، پرداخت/استرداد با حفظ سابقهٔ پرداخت.
  (Robolectric برای تست‌های repository اضافه شده؛ `testDebugUnitTest` همه را
  اجرا می‌کند.)

### ۷. ناوبری
تب «سفارش‌ها» به `OrderListRoute` واقعی وصل شد؛ مسیرهای `order_form`،
`order/{orderId}`، `returns`؛ تب پایین در همهٔ این صفحات هایلایت می‌ماند.

## چه چیزی در فاز ۲ ساخته شد

### ۱. صفحهٔ جزئیات محصول (`ProductDetailScreen`)
- کارت موجودی: عدد بزرگ، `StockBadge` (همیشه نمایش)، حداقل موجودی هشدار، دکمهٔ «تنظیم موجودی».
- کارت قیمت‌ها: خرید/فروش/بسته‌بندی + **سود تخمینی هر واحد** (موجب/منفی با رنگ).
- کارت مشخصات: SKU، بارکد، نام دسته‌بندی (از `CategoryRepository`)، وضعیت.
- **تاریخچهٔ موجودی**: هر `InventoryMovement` با برچسب فارسی نوع (خرید/فروش/مرجوعی/
  تنظیم/آسیب‌دیده/سایر)، دلتا با علامت +/−، مقدار قبل→بعد، تاریخ فارسی و دلیل.
- اکشن‌های نوار بالا: **ویرایش** (رفتن به فرم) و **بایگانی** (با دیالوگ تأیید؛ بعد از
  بایگانی به صفحهٔ قبل برمی‌گردد). خطای اکشن‌ها با Snackbar گزارش می‌شود.
- ViewModel موجود (`ProductDetailViewModel`) گسترش یافت: `adjustStock` و `archiveProduct`
  با رویدادهای یک‌بار مصرف (`ProductDetailEvent`) — الگوی event برای UI بدون side-effect
  پنهان.

### ۲. تنظیم دستی موجودی (spec §۴)
`StockAdjustmentSheet` — دیالوگ خالص UI (بدون دسترسی به Repository): ورود موجودی جدیدِ
مطلق + دلیل اختیاری، پیش‌نمایش «افزایش/کاهش N واحد». ثبت فقط از مسیر رسمی
`InventoryRepository.adjustStockTo` انجام می‌شود (دلتا محاسبه می‌شود و
ADJUSTMENT_IN/ADJUSTMENT_OUT ثبت می‌شود) — یعنی قانون «هرگز بدون Movement موجودی را
تغییر نده» زیر پا نمی‌گذارد.

### ۳. مدیریت دسته‌بندی‌ها
`CategoryListScreen`/`CategoryListViewModel` (ورودی: آیکن نوار بالای صفحهٔ محصولات):
فهرست دسته‌ها با شمارندهٔ «N محصول»، افزودن با دیالوگ، تغییر نام (روی لمس سطر)،
بایگانی (با هشدار دربارهٔ سرنوشت محصولات دسته). رهنمود `parentId` در rename حفظ می‌شود.

### ۴. مشتریان (spec §۸)
- `CustomerListScreen`/`ViewModel` — لیست + جستجوی زنده (نام/موبایل)، سطر با آواتار
  حرف اول + موبایل.
- `CustomerFormScreen`/`ViewModel` — افزودن/ویرایش با اعتبارسنجی
  `ValidateCustomerUseCase`؛ `createdAt` در ویرایش حفظ می‌شود.
- `CustomerDetailScreen`/`ViewModel` — پروفایل از `PartyProfileRepository`: اطلاعات
  تماس + **تعداد سفارش‌ها واقعی** (از OrderDao) + یادداشت که آمار مالی در فاز ۴ می‌آید.

### ۵. تأمین‌کنندگان (spec §۷)
همان الگو: لیست + جستجو، فرم افزودن/ویرایش (`ValidateSupplierUseCase`)، صفحهٔ جزئیات
+ **بایگانی تأمین‌کننده** (با تأیید و Snackbar). آمار مالی (خرید/پرداخت/بدهی) placeholder
تا فاز ۴/۵ است — عمدی، طبق اسپک.

### ۶. کامپوننت‌های قابل‌استفاده (برای فاز ۳)
- `ProductSelectorDialog` — انتخاب محصول در صفحهٔ سفارش؛ stateless: ViewModel میزبان
  نتایج جستجو را از `ProductRepository.observeSearch` می‌آورد و می‌فرستد.
- `CustomerSelectorDialog` — انتخاب مشتری + **ساخت مشتری درون‌خطی** (spec §۹) با
  `onQuickCreate` (قابل اتصال به `CustomerRepository.quickCreate`).

### ۷. تنظیم موجودی به‌صورت مستقل
`StockAdjustmentViewModel` + `StockAdjustmentScreen` (مسیر `stock_adjustment`):
جستجوی محصول → انتخاب → نمایش موجودی فعلی → ورود موجودی جدید + دلیل → پیش‌نمایش
«افزایش/کاهش N واحد» → ثبت. `ViewModel` با `flatMapLatest` بین حالت
«فهرست/جستجو» و «محصول انتخاب‌شده» (از `observeById`، پس از تغییر موجودی هم عدد
به‌روز می‌ماند) سوییچ می‌کند. رویداد موفقیت `Adjusted` صفحه را بازمی‌گرداند؛
خطاها Snackbar می‌شوند.

### ۸. دادهٔ نمونهٔ دیباگ
`data/sample/SampleDataSeeder` (از `ModirApplication` فراخوانی می‌شود):
نگهبانی `BuildConfig.DEBUG` + شمارندهٔ محصولات؛ ۲ تأمین‌کننده، ۳ دسته، ۳ مشتری،
۴ محصول (شامل `minimumStock` برای نمایش کم‌موجود و ناموجود) و ۳ حرکت
(PURCHASE/SALE با مرجع سفارش/ADJUSTMENT_OUT با دلیل). موجودی اولیهٔ محصولات هنگام
`create` تنظیم می‌شود (طبق اسپک، حرکت نیست) و همهٔ تغییرات بعدی از مسیر
`InventoryRepository` می‌گذرند.

### ۹. ناوبری
- همهٔ مسیرها در `Routes` و `ModirNavGraph`: `product/{id}`، `product_form/{id?}`،
  `categories`، `customers`، `customer/{id}`، `customer_form/{id?}`، `suppliers`،
  `supplier/{id}`، `supplier_form/{id?}`، `settings`.
- تب «محصولات» به `ProductListRoute` واقعی وصل شد (دیگر placeholder نیست).
- تب «بیشتر» به `MoreScreen` وصل شد: مشتریان / تأمین‌کنندگان / تنظیمات (placeholder).
- تب پایین در صفحات فرعی هم هایلایت می‌ماند (نقشهٔ route→tab در
  `routeBelongsToTab`).
- `versionName` به `0.2.0-phase2` ارتقا یافت.

## ساختار پروژه

```
app/src/main/java/com/modir/forushgah/
  core/common/          Money.kt, PersianNumberFormatter.kt, DateTimeFormatter.kt
  core/designsystem/    theme/, component/
  di/                   DatabaseModule.kt
  domain/model/         مدل‌های دامنه (بدون وابستگی به Android/Room)
  data/local/entity/    Room Entities
  data/local/dao/       Room DAOs
  data/local/           AppDatabase.kt, converter/
  data/repository/      Product, Category, Inventory, Party, Dashboard, StoreProfile
  presentation/         dashboard/, onboarding/, navigation/
                        products/, categories/, customers/, suppliers/,
                        common/ (ProductRow, SearchField, Selectors), more/
  MainActivity.kt, ModirApplication.kt, RootViewModel.kt
app/src/test/java/...   MoneyTest.kt, PersianNumberFormatterTest.kt,
                        StockMovementCalculatorTest.kt, ValidateProductUseCaseTest.kt,
                        PartyValidationTest.kt
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
فاز ۲: ✅ کامل شد (محصولات/موجودی/مشتریان/تأمین‌کنندگان/دسته‌بندی‌ها)
فاز ۳: ✅ کامل شد (سفارش/پرداخت/ارسال/مرجوعی + بستر رویدادهای مالی)
فاز ۴: موتور مالی کامل (سود و زیان واقعی، هزینه‌ها، مطالبات/بدهی‌ها به‌صورت end-to-end)
فاز ۵: موتور اقساط/تسویه کامل (فعلاً فقط اسکیمای دیتابیس آماده است)
فاز ۶ تا ۸: گزارش‌ها، جریان نقدی، پولیش UX، تست‌های سناریوی کامل، release build

از فاز ۳، تنها تب «مالی» placeholder دارد؛ «محصولات» (جزئیات، فرم، تنظیم موجودی،
دسته‌بندی‌ها)، «سفارش‌ها» (لیست، ثبت، جزئیات، پرداخت، مرجوعی) و «بیشتر» (مشتریان/
تأمین‌کنندگان/تنظیم موجودی) به‌طور کامل کاربردی‌اند. Dashboard و Onboarding هم
کاملاً کاربردی‌اند.
