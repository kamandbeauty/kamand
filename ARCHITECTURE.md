# معماری افزونه ساینا ترک‌اوردر

افزونه روی ووکامرس و وردپرس اجرا می‌شود و پیش‌نمایش وب جداگانه‌ای برای دموی رابط دارد.

## لایه وردپرس

```
saina-track-order/
├── saina-track-order.php      # بارگذاری، سازگاری HPOS، هوک فعال‌سازی
├── includes/
│   ├── class-saina-plugin.php
│   ├── class-saina-helpers.php    # تنظیمات، حامل‌ها، تبدیل اعداد، متای سفارش
│   ├── class-saina-statuses.php   # بسته‌بندی و تحویل‌شده + کرون تبدیل خودکار
│   ├── class-saina-frontend.php   # شورتکد، نوار پیشرفت، حساب کاربری، ایمیل
│   ├── class-saina-ajax.php       # جستجوی سفارش و تأیید تحویل
│   ├── class-saina-admin.php      # متاباکس، تنظیمات، درج گروهی، CSV
│   └── class-saina-sms.php        # شورتکد پیامک ووکامرس فارسی
├── public/                    # فرم مشتری
└── admin/                     # پیشخوان
```

متای سفارش: `_saina_tracking_code`، `_saina_carrier`، `_saina_ship_date`، `_saina_delivery_date`.

## پیش‌نمایش وب

React 18 + Vite + Tailwind. وضعیت در `localStorage` با کلید `saina_track_order_v1` ذخیره می‌شود.
