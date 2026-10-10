import 'dart:async';

import 'package:flutter_poolakey/flutter_poolakey.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/service_config.dart';
import 'account_service.dart';

final premiumBillingServiceProvider = Provider<PremiumBillingService>((ref) {
  return PremiumBillingService(ref.read(accountServiceProvider));
});

class PremiumBillingService {
  final AccountService _accountService;
  bool _connected = false;

  PremiumBillingService(this._accountService);

  Future<void> connect() async {
    if (_connected) return;
    if (!ServiceConfig.hasBazaarBilling) {
      throw const AccountException('تنظیمات پرداخت کافه‌بازار کامل نشده است');
    }
    final completer = Completer<void>();
    await FlutterPoolakey.connect(
      ServiceConfig.bazaarRsaPublicKey,
      onSucceed: () {
        _connected = true;
        if (!completer.isCompleted) completer.complete();
      },
      onFailed: () {
        _connected = false;
        if (!completer.isCompleted) {
          completer.completeError(
            const AccountException('اتصال به کافه‌بازار انجام نشد'),
          );
        }
      },
      onDisconnected: () {
        _connected = false;
      },
    );
    await completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => throw const AccountException(
        'پاسخی از سرویس پرداخت بازار دریافت نشد',
      ),
    );
  }

  Future<AccountSession> subscribe() async {
    await connect();
    final token = await _accountService.loadAccessToken();
    if (token == null || token.isEmpty) {
      throw const AccountException('برای خرید اشتراک ابتدا وارد حساب شوید');
    }
    final payload = 'ruby-${DateTime.now().microsecondsSinceEpoch}';
    final purchase = await FlutterPoolakey.subscribe(
      ServiceConfig.bazaarPremiumProductId,
      payload: payload,
    );
    if (purchase.purchaseToken.isEmpty) {
      throw const AccountException('توکن خرید معتبر از بازار دریافت نشد');
    }
    // Premium is granted only after backend verification with Cafe Bazaar.
    return _accountService.verifyBazaarSubscription(
      productId: purchase.productId,
      purchaseToken: purchase.purchaseToken,
    );
  }

  Future<AccountSession> restoreSubscription() async {
    await connect();
    final purchases = await FlutterPoolakey.getAllSubscribedProducts();
    for (final purchase in purchases) {
      if (purchase.productId == ServiceConfig.bazaarPremiumProductId &&
          purchase.purchaseToken.isNotEmpty) {
        return _accountService.verifyBazaarSubscription(
          productId: purchase.productId,
          purchaseToken: purchase.purchaseToken,
        );
      }
    }
    throw const AccountException('اشتراک فعال برای این حساب بازار پیدا نشد');
  }
}
