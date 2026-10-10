import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../core/config/service_config.dart';
import '../models/user_model.dart';

final accountServiceProvider = Provider<AccountService>((ref) {
  return AccountService();
});

class AccountSession {
  final UserModel user;
  final String accessToken;

  const AccountSession({required this.user, required this.accessToken});
}

/// Client for the app's authentication backend.
///
/// The MelliPayamak API key must exist only on the backend. The app calls the
/// backend to request/verify OTP and never talks to the SMS provider directly.
class AccountService {
  static const _tokenKey = 'ruby_account_access_token_v1';
  final FlutterSecureStorage _secureStorage;
  final http.Client _client;

  AccountService({
    FlutterSecureStorage? secureStorage,
    http.Client? client,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _client = client ?? http.Client();

  Future<String?> loadAccessToken() => _secureStorage.read(key: _tokenKey);

  Future<void> signOut() async {
    await _secureStorage.delete(key: _tokenKey);
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // Google may not have been the active provider.
    }
  }

  Future<AccountSession> signInWithGoogle() async {
    _require(ServiceConfig.hasGoogleAuth, 'تنظیمات ورود گوگل کامل نشده است');
    final google = GoogleSignIn(
      scopes: const ['email', 'profile'],
      serverClientId: ServiceConfig.googleServerClientId,
    );
    final account = await google.signIn();
    if (account == null) {
      throw const AccountException('ورود با گوگل لغو شد');
    }
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AccountException('توکن معتبر گوگل دریافت نشد');
    }
    return _exchange('/v1/auth/google', {'idToken': idToken});
  }

  Future<void> requestIranianOtp(String phone) async {
    _require(ServiceConfig.hasAuthApi, 'آدرس سرویس حساب کاربری تنظیم نشده است');
    final normalized = normalizeIranianPhone(phone);
    await _post('/v1/auth/otp/request', {'phone': normalized});
  }

  Future<AccountSession> verifyIranianOtp(String phone, String code) {
    final normalized = normalizeIranianPhone(phone);
    final otp = code.replaceAll(RegExp(r'\D'), '');
    if (otp.length < 4 || otp.length > 8) {
      throw const AccountException('کد تایید معتبر نیست');
    }
    return _exchange('/v1/auth/otp/verify', {
      'phone': normalized,
      'code': otp,
    });
  }

  Future<AccountSession> refreshProfile() async {
    final token = await loadAccessToken();
    if (token == null || token.isEmpty) {
      throw const AccountException('ابتدا وارد حساب کاربری شوید');
    }
    final payload = await _get('/v1/account/me', token: token);
    return _sessionFromPayload(payload, fallbackToken: token);
  }

  Future<AccountSession> verifyBazaarSubscription({
    required String productId,
    required String purchaseToken,
  }) async {
    final token = await loadAccessToken();
    if (token == null || token.isEmpty) {
      throw const AccountException('ابتدا وارد حساب کاربری شوید');
    }
    final payload = await _post(
      '/v1/billing/bazaar/verify',
      {
        'productId': productId,
        'purchaseToken': purchaseToken,
      },
      token: token,
    );
    return _sessionFromPayload(payload, fallbackToken: token);
  }

  Future<AccountSession> _exchange(
    String path,
    Map<String, dynamic> body,
  ) async {
    final payload = await _post(path, body);
    final session = _sessionFromPayload(payload);
    await _secureStorage.write(
      key: _tokenKey,
      value: session.accessToken,
    );
    return session;
  }

  AccountSession _sessionFromPayload(
    Map<String, dynamic> payload, {
    String? fallbackToken,
  }) {
    final userMap = payload['user'];
    if (userMap is! Map) {
      throw const AccountException('پاسخ حساب کاربری معتبر نیست');
    }
    final entitlement = payload['entitlement'];
    final entitlementMap = entitlement is Map
        ? Map<String, dynamic>.from(entitlement)
        : <String, dynamic>{};
    final token = '${payload['accessToken'] ?? fallbackToken ?? ''}';
    if (token.isEmpty) {
      throw const AccountException('توکن ورود دریافت نشد');
    }
    final map = Map<String, dynamic>.from(userMap);
    return AccountSession(
      accessToken: token,
      user: UserModel(
        id: '${map['id'] ?? ''}',
        name: '${map['name'] ?? ''}',
        phone: '${map['phone'] ?? ''}',
        email: '${map['email'] ?? ''}',
        authProvider: '${map['authProvider'] ?? ''}',
        country: '${map['country'] ?? 'ایران'}',
        province: '${map['province'] ?? ''}',
        city: '${map['city'] ?? ''}',
        usageType: '${map['usageType'] ?? 'store'}',
        isOnboarded: true,
        isPremium: entitlementMap['isPremium'] == true,
        premiumExpiresAt: '${entitlementMap['expiresAt'] ?? ''}',
      ),
    );
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final response = await _client
        .post(
          _uri(path),
          headers: _headers(token),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));
    return _decode(response);
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    String? token,
  }) async {
    final response = await _client
        .get(_uri(path), headers: _headers(token))
        .timeout(const Duration(seconds: 25));
    return _decode(response);
  }

  Uri _uri(String path) {
    _require(ServiceConfig.hasAuthApi, 'آدرس سرویس حساب کاربری تنظیم نشده است');
    final base = ServiceConfig.authApiBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  Map<String, String> _headers(String? token) => {
        'content-type': 'application/json; charset=utf-8',
        'accept': 'application/json',
        if (token != null && token.isNotEmpty) 'authorization': 'Bearer $token',
      };

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> payload = const {};
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
    } catch (_) {
      // A useful HTTP error is returned below.
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AccountException(
        '${payload['message'] ?? 'خطای ارتباط با سرویس حساب کاربری'}',
      );
    }
    return payload;
  }

  static String normalizeIranianPhone(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0098')) digits = digits.substring(4);
    if (digits.startsWith('98')) digits = digits.substring(2);
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.length != 10 || !digits.startsWith('9')) {
      throw const AccountException('شماره موبایل ایران معتبر نیست');
    }
    return '+98$digits';
  }

  static void _require(bool condition, String message) {
    if (!condition) throw AccountException(message);
  }
}

class AccountException implements Exception {
  final String message;
  const AccountException(this.message);

  @override
  String toString() => message;
}
