import 'installment_repository.dart';

/// نتیجهٔ عملیات پرووایدر اقساطی — بدون API جعلی، وضعیت را اپراتور ثبت می‌کند (§55)
class ProviderActionResult {
  final bool ok;
  final String message;
  final String? remoteRef;
  const ProviderActionResult(this.ok, this.message, {this.remoteRef});
}

/// رابط معماری برای اتصال آیندهٔ سیستم‌های اقساطی به API واقعی.
/// در این مرحله همهٔ پرووایدرها MANUAL هستند: کاربر نتیجه را دستی ثبت
/// می‌کند و سیستم حسابداری داخلی همان منبع حقیقت است.
/// هیچ فراخوانی شبکه‌ای جعلی در این فاز وجود ندارد (§54).
abstract class InstallmentProviderAdapter {
  String get providerKey;

  /// ایجاد درخواست پرداخت در سیستم اقساطی
  Future<ProviderActionResult> createPayment({
    required String saleId,
    required int gross,
    required int downPayment,
    required int installmentCount,
  });

  /// تأیید/_AUTHORIZE شدن درخواست
  Future<ProviderActionResult> authorize(String saleId);

  /// لغو درخواست
  Future<ProviderActionResult> cancel(String saleId, String reason);

  /// برگشت
  Future<ProviderActionResult> refund(String saleId, String reason);

  /// وضعیت تسویه
  Future<ProviderActionResult> getSettlement(String saleId);

  /// وضعیت فعلی
  Future<ProviderActionResult> getStatus(String saleId);
}

/// پیاده‌سازی دستی/آفلاین — همهٔ عملیات‌ها را اپراتور در اپ ثبت می‌کند
class ManualProviderAdapter implements InstallmentProviderAdapter {
  @override
  final String providerKey;

  ManualProviderAdapter(this.providerKey);

  @override
  Future<ProviderActionResult> createPayment({
    required String saleId,
    required int gross,
    required int downPayment,
    required int installmentCount,
  }) async =>
      const ProviderActionResult(true, 'ثبت دستی — در سیستم اقساطی ثبت کنید و نتیجه را اینجا وارد کنید');

  @override
  Future<ProviderActionResult> authorize(String saleId) async =>
      const ProviderActionResult(true, 'وضعیت را دستی به «تأییدشده» تغییر دهید');

  @override
  Future<ProviderActionResult> cancel(String saleId, String reason) async =>
      const ProviderActionResult(true, 'لغو را از صفحهٔ فروش اقساطی انجام دهید');

  @override
  Future<ProviderActionResult> refund(String saleId, String reason) async =>
      const ProviderActionResult(true, 'برگشت را از صفحهٔ فروش اقساطی انجام دهید');

  @override
  Future<ProviderActionResult> getSettlement(String saleId) async =>
      const ProviderActionResult(true, 'تسویه را از صفحهٔ تسویه‌ها ثبت کنید');

  @override
  Future<ProviderActionResult> getStatus(String saleId) async =>
      const ProviderActionResult(true, 'وضعیت دستی/آفلاین');
}
