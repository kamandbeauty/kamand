# فاکتور ساز روبی v1.0.5

## تغییرات اصلی
- سود فقط در گزارشات نمایش داده می‌شود، از فاکتورها حذف شد (dashboard, preview, list, create)
- حل کامل باگ‌های تنظیمات فاکتور

## باگ‌فیکس‌های تنظیمات فاکتور
- AppSettingsModel.fromMap: fix showSignature که اشتباه showStamp را می‌خواند
- HeaderCustomize: fix پاک شدن ناخواسته مهر هنگام null، حذف فایل قدیمی
- Settings: اعتبارسنجی شماره شروع، fallback امن templateStyle، اضافه شدن سوییچ‌های مهر/امضا
- InvoicePreview: رعایت showLogo/showCardNum/showStamp+showSignature
- Dashboard: _nextInvoiceNumber با provider، _removeRow پاکسازی LayerLink، _editInvoiceNumber و _saveInvoice جلوگیری از شماره تکراری
- ImageProcessHelper: پاکسازی فایل‌های قدیمی branding (نگه‌داری 5 آخر)

## باگ‌فیکس‌های کلی
- همه Providerها: hydration guard برای جلوگیری از overwrite داده با مقدار پیش‌فرض
- product/bank_card/customer/supplier/expense: persist async
- invoice_provider: copyInvoice با startingInvoiceNum، convertProforma و recordPayment با clamp به remaining
- backup import: invalidate همه providerها
- image_crop: حفظ minSize در move
- PrefsStore: حذف کلید کارت هنگام id خالی

## ورژن
- 1.0.4+4 -> 1.0.5+5

## فایل‌ها
- factor-ruby-1.0.5.zip - سورس کامل برنچ arena/01a0bed4-kamand
- factor-ruby-1.0.5.tar.gz - همین

## نصب
flutter pub get
flutter build apk --release
