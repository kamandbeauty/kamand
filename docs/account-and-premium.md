# حساب کاربری و اشتراک پریمیوم

## معماری امنیتی

- ورود Google در اپ انجام می‌شود و `idToken` برای اعتبارسنجی به بک‌اند ارسال می‌شود.
- ارسال OTP موبایل ایران فقط توسط بک‌اند و وب‌سرویس ملی‌پیامک انجام می‌شود. نام کاربری، رمز و API Key ملی‌پیامک نباید داخل APK قرار بگیرد.
- خرید اشتراک با Poolakey کافه‌بازار آغاز می‌شود.
- توکن خرید به بک‌اند ارسال می‌شود و بک‌اند آن را با API توسعه‌دهندگان بازار اعتبارسنجی می‌کند.
- فقط پاسخ معتبر بک‌اند اجازه فعال‌شدن Premium را می‌دهد. فایل پشتیبان محلی نمی‌تواند Premium را فعال کند.

## تنظیم Build

```bash
flutter build apk \
  --dart-define=AUTH_API_BASE_URL=https://api.example.com \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_OAUTH_CLIENT_ID \
  --dart-define=BAZAAR_RSA_PUBLIC_KEY=YOUR_BAZAAR_RSA_PUBLIC_KEY \
  --dart-define=BAZAAR_PREMIUM_PRODUCT_ID=ruby_premium_monthly
```

کلید RSA بازار «کلید عمومی» است. کلید ملی‌پیامک و اطلاعات خصوصی API بازار فقط باید در Secretهای سرور قرار بگیرند.

## قرارداد API مورد انتظار اپ

### `POST /v1/auth/google`

درخواست:

```json
{"idToken":"google-id-token"}
```

بک‌اند باید امضا، issuer، audience و انقضای Google ID Token را بررسی کند.

### `POST /v1/auth/otp/request`

```json
{"phone":"+989121234567"}
```

بک‌اند یک کد یک‌بارمصرف کوتاه‌عمر ایجاد و با الگوی تایید ملی‌پیامک ارسال می‌کند. محدودیت تعداد درخواست بر اساس شماره، IP و دستگاه الزامی است.

### `POST /v1/auth/otp/verify`

```json
{"phone":"+989121234567","code":"12345"}
```

کد باید هش‌شده، تک‌مصرف و دارای زمان انقضا باشد.

### `GET /v1/account/me`

Header:

```text
Authorization: Bearer ACCESS_TOKEN
```

### `POST /v1/billing/bazaar/verify`

```json
{
  "productId":"ruby_premium_monthly",
  "purchaseToken":"bazaar-purchase-token"
}
```

بک‌اند باید مالکیت و فعال‌بودن اشتراک را از کافه‌بازار بررسی کند و Product ID را با پلن مجاز تطبیق دهد.

## پاسخ مشترک ورود و اعتبارسنجی اشتراک

```json
{
  "accessToken":"signed-access-token",
  "user":{
    "id":"user-id",
    "name":"نام کاربر",
    "phone":"+989121234567",
    "email":"user@example.com",
    "authProvider":"google"
  },
  "entitlement":{
    "isPremium":true,
    "expiresAt":"2026-12-31T23:59:59Z"
  }
}
```

در پاسخ ورود موبایل، `authProvider` باید مقدار `phone` داشته باشد.
