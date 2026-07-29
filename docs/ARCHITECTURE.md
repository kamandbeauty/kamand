# معماری حسابیار جاوید

## لایه‌بندی

```
feature (Compose Screen + ViewModel)
        ↓ Flow / command
 domain (Repository contracts + business input models)
        ↓
 data (Repository implementations + posting engine + Room)
        ↓
 SQLite on device
```

- UI فقط با `ViewModel` و قراردادهای repository کار می‌کند؛ هیچ DAO در UI استفاده نشده است.
- `HesabyarDatabase` منبع حقیقت محلی است. Room در عملیات حساس با `withTransaction` استفاده می‌شود.
- `JournalPoster` تنها نقطه‌ی ایجاد سند خودکار است و قبل از درج، تراز بودن بدهکار و بستانکار را کنترل می‌کند.
- مقادیر مالی در تمام لایه داده به ریال و `Long` هستند. تبدیل تومان/ریال و رقم فارسی تنها در مرز UI انجام می‌شود.

## جدول‌های اصلی

| حوزه | جدول‌ها |
|---|---|
| تنظیمات و مجوز | `app_settings`, `licenses` |
| کالا | `product_categories`, `products`, `inventory_transactions` |
| اشخاص | `parties`, `party_transactions` |
| فروش | `sales_invoices`, `sales_invoice_items` |
| خرید | `purchase_invoices`, `purchase_invoice_items` |
| نقدینگی | `cash_accounts`, `receipts`, `payments`, `expenses`, `incomes`, `cash_transfers` |
| حسابداری | `accounts`, `journal_entries`, `journal_items` |

## قواعد تراکنشی

### فروش نهایی

1. فاکتور و ردیف‌ها ثبت می‌شوند.
2. فقط کالاهای `trackInventory=true` از موجودی کم می‌شوند و گردش انبار می‌گیرند.
3. مانده‌ی مشتری برای بخش نسیه افزایش می‌یابد؛ دریافت نقدی به صندوق/بانک اضافه می‌شود.
4. سند دوبل ثبت می‌شود: صندوق/دریافتنی بدهکار، فروش و مالیات بستانکار؛ بهای تمام‌شده بدهکار و موجودی کالا بستانکار.

خرید، دریافت، پرداخت، هزینه، درآمد و انتقال وجه نیز به همین شکل اتمیک سند خودکار دارند. ابطال فاکتور، رکورد قبلی را تخریب نمی‌کند؛ گردش‌های معکوس و سند برگشتی ثبت می‌کند.

## آمادگی برای آینده

قرارداد repository امکان افزودن `RemoteDataSource`، صف همگام‌سازی و resolver تعارض را بدون تغییر Composableها فراهم می‌کند. کلیدهای محلی از نوع `Long` هستند تا در آینده با شناسه‌ی سرور یا نگاشت sync همراه شوند. نسخه فعلی عمداً هیچ permission اینترنتی ندارد.

## Backup

پیش از export دستور `wal_checkpoint(FULL)` اجرا می‌شود و فایل SQLite از طریق Storage Access Framework به محل انتخابی کاربر نوشته می‌شود. Restore ابتدا header فایل را بررسی می‌کند، سپس فایل را جایگزین می‌کند. برنامه باید پس از Restore بازسازی شود تا تمام Flowها به پایگاه بازیابی‌شده متصل شوند.
