# ساختار دیتابیس محلی «فاکتور روبی» (Local Database Schema)

این دیتابیس کاملاً **Offline-First** بوده و روی دیتابیس SQLite / Drift پیاده‌سازی شده است.

---

## ۱. جدول کاربران (`users`)
ذخیره اطلاعات Onboarding و مشخصات فردی کاربر.

| نام فیلد | نوع داده | توضیحات |
| :--- | :--- | :--- |
| `id` | TEXT (PRIMARY KEY) | شناسه یکتای کاربر |
| `name` | TEXT | نام و نام خانوادگی کاربر |
| `country` | TEXT | کشور محل فعالیت (پیش‌فرض: ایران) |
| `province` | TEXT | استان (در صورت انتخاب ایران) |
| `city` | TEXT | شهر محل فعالیت |
| `usage_type` | TEXT | نوع استفاده (فروشگاه، خدمات، فریلنسر، ...) |
| `is_onboarded` | INTEGER (BOOLEAN) | آیا مراحل Onboarding تکمیل شده است؟ |
| `created_at` | TEXT | تاریخ ثبت |

---

## ۲. جدول مشخصات کسب و کار (`business_profile`)
اطلاعات سربرگ فاکتور و هویت تجاری.

| نام فیلد | نوع داده | توضیحات |
| :--- | :--- | :--- |
| `id` | TEXT (PRIMARY KEY) | شناسه کسب و کار |
| `shop_name` | TEXT | نام فروشگاه یا برند تجاری |
| `phone` | TEXT | شماره تماس ثابت یا همراه پشتیبانی |
| `address` | TEXT | آدرس کامل فروشگاه / دفتر |
| `tax_id` | TEXT | شناسه ملی یا کد اقتصادی مالیاتی |
| `logo_path` | TEXT | مسیر فایل لوگوی اختصاصی |
| `bank_cards_json` | TEXT | آرایه JSON شامل شماره کارت‌های بانکی |

---

## ۳. جدول مشتریان (`customers`)
مدیریت طرف حساب‌ها و مانده بدهی/طلب.

| نام فیلد | نوع داده | توضیحات |
| :--- | :--- | :--- |
| `id` | TEXT (PRIMARY KEY) | شناسه مشتری |
| `name` | TEXT | نام کامل یا نام شرکت |
| `mobile` | TEXT | شماره همراه |
| `phone` | TEXT | تلفن ثابت |
| `address` | TEXT | آدرس مشتری |
| `notes` | TEXT | توضیحات و یادداشت |
| `balance` | REAL | مانده حساب (بدهی فعلی مشتری) |
| `created_at` | TEXT | تاریخ ایجاد |

---

## ۴. جدول کالاها و خدمات (`products`)
کاتالوگ و موجودی محصولات.

| نام فیلد | نوع داده | توضیحات |
| :--- | :--- | :--- |
| `id` | TEXT (PRIMARY KEY) | شناسه کالا |
| `code` | TEXT | کد کالا / بارکد / SKU |
| `name` | TEXT | عنوان کالا یا خدمت |
| `unit` | TEXT | واحد سنجش (عدد، کیلوگرم، بسته، ...) |
| `buy_price` | REAL | قیمت خرید |
| `sell_price` | REAL | قیمت فروش |
| `stock` | REAL | موجودی انبار |
| `notes` | TEXT | توضیحات کالا |

---

## ۵. جدول فاکتورها (`invoices`)
اطلاعات اصلی فاکتورها (فروش، خرید، پیش‌فاکتور).

| نام فیلد | نوع داده | توضیحات |
| :--- | :--- | :--- |
| `id` | TEXT (PRIMARY KEY) | شناسه فاکتور |
| `number` | TEXT | شماره فاکتور |
| `customer_id` | TEXT (FOREIGN KEY) | لینک به جدول `customers.id` |
| `customer_name` | TEXT | نام مشتری |
| `customer_phone` | TEXT | شماره تماس مشتری |
| `type` | TEXT | نوع: `sale` (فروش), `proforma` (پیش‌فاکتور), `purchase` (خرید) |
| `payment_type` | TEXT | نوع پرداخت: `cash` (نقدی), `non_cash` (غیرنقدی/اقساط) |
| `status` | TEXT | وضعیت: `paid` (پرداخت شده), `unpaid` (بدهکار), `partial` (تسویه ناقص), `proforma` |
| `date` | TEXT | تاریخ شمسی (مثلاً 1405/05/20) |
| `subtotal` | REAL | جمع کل اقلام |
| `discount_percent` | REAL | درصد تخفیف |
| `discount_amount` | REAL | مبلغ تخفیف |
| `shipping_fee` | REAL | هزینه ارسال |
| `previous_debt` | REAL | بدهی قبلی مشتری |
| `deposit` | REAL | بیعانه دریافتی |
| `total_amount` | REAL | مبلغ نهایی قابل پرداخت |
| `paid_amount` | REAL | مبلغ دریافتی تاکنون |
| `remaining_amount` | REAL | مانده بدهی فاکتور |
| `notes` | TEXT | توضیحات فاکتور |
| `card_number` | TEXT | شماره کارت جهت واریز |
| `created_at` | TEXT | زمان ثبت |

---

## ۶. جدول اقلام فاکتور (`invoice_items`)
سطرهای تفکیکی هر فاکتور.

| نام فیلد | نوع داده | توضیحات |
| :--- | :--- | :--- |
| `id` | TEXT (PRIMARY KEY) | شناسه سطر |
| `invoice_id` | TEXT (FOREIGN KEY) | کلید خارجی به `invoices.id` |
| `product_id` | TEXT (FOREIGN KEY) | کلید خارجی اختیاری به `products.id` |
| `title` | TEXT | عنوان کالا/خدمت |
| `quantity` | REAL | مقدار |
| `unit` | TEXT | واحد سنجش |
| `unit_price` | REAL | قیمت واحد |
| `total_price` | REAL | قیمت کل سطر |

---

## ۷. جدول دریافت‌ها و پرداخت‌ها (`payments`)
تاریخچه تراکنش‌های مالی فاکتورها و تسویه‌ها.

| نام فیلد | نوع داده | توضیحات |
| :--- | :--- | :--- |
| `id` | TEXT (PRIMARY KEY) | شناسه پرداخت |
| `invoice_id` | TEXT (FOREIGN KEY) | مربوط به فاکتور |
| `customer_id` | TEXT (FOREIGN KEY) | مربوط به مشتری |
| `amount` | REAL | مبلغ واریزی |
| `date` | TEXT | تاریخ شمسی |
| `payment_method` | TEXT | روش (کارت به کارت، نقدی، پوز) |
| `notes` | TEXT | توضیحات |

---

## ۸. جدول هزینه‌ها (`expenses`)
مدیریت هزینه‌های جاری کسب‌وکار.

| نام فیلد | نوع داده | توضیحات |
| :--- | :--- | :--- |
| `id` | TEXT (PRIMARY KEY) | شناسه هزینه |
| `title` | TEXT | عنوان هزینه (اجاره، قبوض، ...) |
| `category` | TEXT | دسته‌بندی |
| `amount` | REAL | مبلغ هزینه |
| `date` | TEXT | تاریخ ثبت |
| `notes` | TEXT | توضیحات |

---

## ۹. جدول درآمدها (`income`)
سایر درآمدهای غیرفروشگاهی.

| نام فیلد | نوع داده | توضیحات |
| :--- | :--- | :--- |
| `id` | TEXT (PRIMARY KEY) | شناسه درآمد |
| `title` | TEXT | عنوان درآمد |
| `category` | TEXT | دسته‌بندی |
| `amount` | REAL | مبلغ |
| `date` | TEXT | تاریخ |
| `notes` | TEXT | توضیحات |

---

## ۱۰. جدول تنظیمات (`settings`)

| نام فیلد | نوع داده | توضیحات |
| :--- | :--- | :--- |
| `id` | INTEGER (PRIMARY KEY) | تک سطر تنظیمات |
| `starting_invoice_num` | INTEGER | شماره شروع فاکتور بعدی |
| `template_style` | TEXT | قالب فاکتور: `modern`, `classic`, `simple` |
| `show_logo` | INTEGER (BOOLEAN) | نمایش لوگو |
| `show_card_num` | INTEGER (BOOLEAN) | نمایش کادر کارت بانکی |
| `theme_mode` | TEXT | پوسته: `light`, `dark`, `system` |
| `auto_backup` | INTEGER (BOOLEAN) | پشتیبان‌گیری خودکار |
| `pin_code` | TEXT | رمز ۴ رقمی قفل برنامه |
| `pin_enabled` | INTEGER (BOOLEAN) | فعال بودن قفل |

---

## ۱۱. جدول پشتیبان‌ها (`backups`)

| نام فیلد | نوع داده | توضیحات |
| :--- | :--- | :--- |
| `id` | TEXT (PRIMARY KEY) | شناسه نسخه پشتیبان |
| `file_name` | TEXT | نام فایل بکاپ JSON/SQLite |
| `created_at` | TEXT | تاریخ ایجاد |
| `size_bytes` | INTEGER | حجم فایل |

---

## روابط (Relationships) & Cascades:
- هر مشتری می‌تواند چندین فاکتور داشته باشد (`customers.id = invoices.customer_id`).
- هر فاکتور می‌تواند چندین آیتم داشته باشد (`invoices.id = invoice_items.invoice_id` با `ON DELETE CASCADE`).
- با حذف هر فاکتور یا ثبت واریزی، مانده حساب مشتری در جدول `customers.balance` به صورت اتوماتیک به‌روزرسانی می‌شود.
