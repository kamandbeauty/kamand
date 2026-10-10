import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../models/business_profile_model.dart';
import '../../models/app_settings_model.dart';
import '../../models/invoice_model.dart';
import '../../models/customer_model.dart';
import '../../models/product_model.dart';
import '../../models/bank_card_model.dart';

/// ذخیره پایدار اطلاعات کاربر، فاکتورها و تنظیمات روی گوشی.
class PrefsStore {
  static const _kUser = 'ruby_user_v1';
  static const _kBusiness = 'ruby_business_v1';
  static const _kSettings = 'ruby_settings_v1';
  static const _kInvoices = 'ruby_invoices_v1';
  static const _kCustomers = 'ruby_customers_v1';
  static const _kProducts = 'ruby_products_v1';
  static const _kDraft = 'ruby_invoice_draft_v1';
  static const _kBankCards = 'ruby_bank_cards_v1';
  static const _kSelectedBankCard = 'ruby_selected_bank_card_v1';
  static const _kInvoiceBalanceLedger = 'ruby_invoice_balance_ledger_v1';

  static Future<SharedPreferences> get _p async => SharedPreferences.getInstance();

  static Future<void> saveUser(UserModel u) async {
    await _saveJson(_kUser, u.toMap());
  }

  static Future<UserModel?> loadUser() async {
    return _loadModel(_kUser, UserModel.fromMap);
  }

  static Future<void> saveBusiness(BusinessProfileModel b) async {
    await _saveJson(_kBusiness, b.toMap());
  }

  static Future<BusinessProfileModel?> loadBusiness() async {
    return _loadModel(_kBusiness, BusinessProfileModel.fromMap);
  }

  static Future<void> saveSettings(AppSettingsModel s) async {
    await _saveJson(_kSettings, s.toMap());
  }

  static Future<AppSettingsModel?> loadSettings() async {
    return _loadModel(_kSettings, AppSettingsModel.fromMap);
  }

  static Future<void> saveInvoices(List<InvoiceModel> invoices) async {
    await _saveJson(_kInvoices, invoices.map((e) => e.toMap()).toList());
  }

  static Future<List<InvoiceModel>> loadInvoices() async {
    return _loadModels(_kInvoices, InvoiceModel.fromMap);
  }

  static Future<void> saveCustomers(List<CustomerModel> customers) async {
    await _saveJson(_kCustomers, customers.map((e) => e.toMap()).toList());
  }

  static Future<List<CustomerModel>> loadCustomers() async {
    return _loadModels(_kCustomers, CustomerModel.fromMap);
  }

  static Future<void> saveProducts(List<ProductModel> products) async {
    await _saveJson(_kProducts, products.map((e) => e.toMap()).toList());
  }

  static Future<List<ProductModel>> loadProducts() async {
    return _loadModels(_kProducts, ProductModel.fromMap);
  }

  static Future<void> saveBankCards(List<BankCardModel> cards) async {
    await _saveJson(_kBankCards, cards.map((e) => e.toMap()).toList());
  }

  static Future<List<BankCardModel>> loadBankCards() async {
    return _loadModels(_kBankCards, BankCardModel.fromMap);
  }

  static Future<void> saveSelectedBankCardId(String id) async {
    final p = await _p;
    await p.setString(_kSelectedBankCard, id);
  }

  static Future<String?> loadSelectedBankCardId() async {
    final p = await _p;
    return p.getString(_kSelectedBankCard);
  }

  static Future<void> clearSelectedBankCardId() async {
    final p = await _p;
    await p.remove(_kSelectedBankCard);
  }

  static Future<Map<String, Map<String, dynamic>>>
      loadInvoiceBalanceLedger() async {
    final map = await _loadMap(_kInvoiceBalanceLedger);
    if (map == null) return <String, Map<String, dynamic>>{};
    return map.map((key, value) {
      return MapEntry(key, _mapOrNull(value) ?? <String, dynamic>{});
    });
  }

  static Future<void> saveInvoiceBalanceLedger(
    Map<String, Map<String, dynamic>> ledger,
  ) async {
    await _saveJson(_kInvoiceBalanceLedger, ledger);
  }

  static Future<void> saveDraft(InvoiceModel draft) async {
    await _saveJson(_kDraft, draft.toMap());
  }

  static Future<InvoiceModel?> loadDraft() async {
    return _loadModel(_kDraft, InvoiceModel.fromMap);
  }

  static Future<void> clearDraft() async {
    final p = await _p;
    // Drafts use the same shadow-copy mechanism as the other JSON values.
    // Removing only the primary key caused the supposedly cleared draft to be
    // restored from `_last_good` on the next app launch.
    await Future.wait([
      p.remove(_kDraft),
      p.remove(_backupKey(_kDraft)),
    ]);
  }

  static Future<Map<String, dynamic>> exportAll() async {
    final business = await loadBusiness();
    return {
      'schemaVersion': 3,
      'exportedAt': DateTime.now().toIso8601String(),
      'user': (await loadUser())?.toMap(),
      'business': business?.toMap(),
      'brandingImages': await _exportBrandingImages(business),
      'settings': (await loadSettings())?.toMap(),
      'invoices': (await loadInvoices()).map((e) => e.toMap()).toList(),
      'customers': (await loadCustomers()).map((e) => e.toMap()).toList(),
      'products': (await loadProducts()).map((e) => e.toMap()).toList(),
      'draft': (await loadDraft())?.toMap(),
      'bankCards': (await loadBankCards()).map((e) => e.toMap()).toList(),
      'selectedBankCardId': await loadSelectedBankCardId(),
      'invoiceBalanceLedger': await loadInvoiceBalanceLedger(),
    };
  }

  static Future<void> importAll(Map<String, dynamic> data) async {
    final schemaVersion = data['schemaVersion'];
    if (schemaVersion is! num || schemaVersion < 1 || schemaVersion > 3) {
      throw const FormatException('نسخه فایل پشتیبان پشتیبانی نمی‌شود');
    }

    // Parse and validate every section before changing any persisted value.
    // This prevents a malformed backup from being applied only halfway.
    final userMap = _mapOrNull(data['user']);
    final businessMap = _mapOrNull(data['business']);
    final settingsMap = _mapOrNull(data['settings']);
    final draftMap = _mapOrNull(data['draft']);
    final parsedUser = userMap == null ? null : UserModel.fromMap(userMap);
    var parsedBusiness = businessMap == null
        ? null
        : BusinessProfileModel.fromMap(businessMap);
    final parsedSettings = settingsMap == null
        ? null
        : AppSettingsModel.fromMap(settingsMap);
    final parsedDraft = draftMap == null ? null : InvoiceModel.fromMap(draftMap);
    final parsedInvoices = _requireMapList(data, 'invoices')
        .map(InvoiceModel.fromMap)
        .toList();
    final parsedCustomers = _requireMapList(data, 'customers')
        .map(CustomerModel.fromMap)
        .toList();
    final parsedProducts = _requireMapList(data, 'products')
        .map(ProductModel.fromMap)
        .toList();
    final parsedCards = _requireMapList(data, 'bankCards')
        .map(BankCardModel.fromMap)
        .toList();

    final normalizedLedger = <String, Map<String, dynamic>>{};
    final ledger = _mapOrNull(data['invoiceBalanceLedger']);
    if (ledger != null) {
      for (final entry in ledger.entries) {
        final value = _mapOrNull(entry.value);
        if (value == null ||
            value['customerId'] is! String ||
            value['impact'] is! num) {
          throw const FormatException('دفتر مانده حساب در فایل معتبر نیست');
        }
        normalizedLedger[entry.key] = {
          'customerId': value['customerId'],
          'impact': (value['impact'] as num).toDouble(),
          if (value['referenceImpact'] is num)
            'referenceImpact': (value['referenceImpact'] as num).toDouble(),
        };
      }
    }

    if (parsedBusiness != null) {
      parsedBusiness = await _restoreBrandingImages(
        parsedBusiness,
        _mapOrNull(data['brandingImages']),
      );
    }

    if (parsedUser != null) await saveUser(parsedUser);
    if (parsedBusiness != null) await saveBusiness(parsedBusiness);
    if (parsedSettings != null) await saveSettings(parsedSettings);
    await saveInvoices(parsedInvoices);
    await saveCustomers(parsedCustomers);
    await saveProducts(parsedProducts);
    await saveBankCards(parsedCards);
    await saveInvoiceBalanceLedger(normalizedLedger);

    final selectedCardId = data['selectedBankCardId'];
    if (selectedCardId is String && selectedCardId.isNotEmpty) {
      await saveSelectedBankCardId(selectedCardId);
    } else {
      await clearSelectedBankCardId();
    }
    if (parsedDraft != null) {
      await saveDraft(parsedDraft);
    } else {
      await clearDraft();
    }
  }

  static Future<Map<String, String>> _exportBrandingImages(
    BusinessProfileModel? business,
  ) async {
    if (business == null) return <String, String>{};
    final result = <String, String>{};
    final paths = {
      'logo': business.logoPath,
      'stamp': business.stampPath,
      if (business.signaturePath != business.stampPath)
        'signature': business.signaturePath,
    };
    for (final entry in paths.entries) {
      if (entry.value.isEmpty) continue;
      try {
        final file = File(entry.value);
        if (await file.exists()) {
          result[entry.key] = base64Encode(await file.readAsBytes());
        }
      } catch (_) {
        // A missing optional branding image must not prevent data backup.
      }
    }
    return result;
  }

  static Future<BusinessProfileModel> _restoreBrandingImages(
    BusinessProfileModel business,
    Map<String, dynamic>? encoded,
  ) async {
    final restoredPaths = <String, String>{};
    if (encoded != null) {
      // Decode all values first so malformed base64 cannot partially alter the
      // imported profile.
      final decoded = <String, List<int>>{};
      for (final key in const ['logo', 'stamp', 'signature']) {
        final value = encoded[key];
        if (value == null) continue;
        if (value is! String || value.length > 16 * 1024 * 1024) {
          throw const FormatException('تصاویر فایل پشتیبان معتبر نیستند');
        }
        decoded[key] = base64Decode(value);
      }
      if (decoded.isNotEmpty) {
        final documents = await getApplicationDocumentsDirectory();
        final folder = Directory(p.join(documents.path, 'branding'));
        if (!await folder.exists()) await folder.create(recursive: true);
        for (final entry in decoded.entries) {
          final path = p.join(
            folder.path,
            '${entry.key}_restored_${DateTime.now().microsecondsSinceEpoch}.png',
          );
          await File(path).writeAsBytes(entry.value, flush: true);
          restoredPaths[entry.key] = path;
        }
      }
    }

    Future<String> usablePath(String key, String oldPath) async {
      final restored = restoredPaths[key];
      if (restored != null) return restored;
      if (oldPath.isNotEmpty && await File(oldPath).exists()) return oldPath;
      return '';
    }

    final logoPath = await usablePath('logo', business.logoPath);
    final stampPath = await usablePath('stamp', business.stampPath);
    final signaturePath = business.signaturePath == business.stampPath &&
            restoredPaths['signature'] == null
        ? stampPath
        : await usablePath('signature', business.signaturePath);
    return business.copyWith(
      logoPath: logoPath,
      stampPath: stampPath,
      signaturePath: signaturePath,
    );
  }

  static List<Map<String, dynamic>> _requireMapList(
    Map<String, dynamic> data,
    String key,
  ) {
    final value = data[key];
    if (value is! List) {
      throw FormatException('بخش $key در فایل پشتیبان معتبر نیست');
    }
    final result = <Map<String, dynamic>>[];
    for (final item in value) {
      final map = _mapOrNull(item);
      if (map == null) {
        throw FormatException('یکی از رکوردهای $key معتبر نیست');
      }
      result.add(map);
    }
    return result;
  }

  static String _backupKey(String key) => '${key}_last_good';

  static Future<void> _saveJson(String key, Object? value) async {
    final preferences = await _p;
    final encoded = jsonEncode(value);
    // Write a known-good shadow copy first. If the primary value is ever
    // truncated or corrupted, loaders can recover the latest complete value.
    final backupSaved = await preferences.setString(_backupKey(key), encoded);
    final primarySaved = await preferences.setString(key, encoded);
    if (!backupSaved || !primarySaved) {
      throw FileSystemException('ذخیره اطلاعات برنامه انجام نشد');
    }
  }

  static Future<dynamic> _loadDecoded(String key) async {
    final preferences = await _p;
    final primary = preferences.getString(key);
    final backup = preferences.getString(_backupKey(key));

    // The primary key can be missing after an interrupted/partial platform
    // write. In that case the shadow copy is still a valid recovery source.
    for (final candidate in [primary, backup]) {
      if (candidate == null || candidate.isEmpty) continue;
      try {
        final decoded = jsonDecode(candidate);
        if (candidate == backup) {
          await preferences.setString(key, candidate);
        }
        return decoded;
      } catch (_) {
        // Try the shadow copy before giving up.
      }
    }
    return null;
  }

  static Future<T?> _loadModel<T>(
    String key,
    T Function(Map<String, dynamic>) decode,
  ) async {
    final preferences = await _p;
    final primary = preferences.getString(key);
    final backup = preferences.getString(_backupKey(key));
    for (final candidate in [primary, backup]) {
      if (candidate == null || candidate.isEmpty) continue;
      try {
        final map = _mapOrNull(jsonDecode(candidate));
        if (map == null) continue;
        final model = decode(map);
        if (candidate == backup) await preferences.setString(key, candidate);
        return model;
      } catch (_) {
        // Try the last known-good copy before giving up.
      }
    }
    return null;
  }

  static Future<List<T>> _loadModels<T>(
    String key,
    T Function(Map<String, dynamic>) decode,
  ) async {
    final preferences = await _p;
    final primary = preferences.getString(key);
    final backup = preferences.getString(_backupKey(key));
    for (final candidate in [primary, backup]) {
      if (candidate == null || candidate.isEmpty) continue;
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is! List) continue;
        final models = decoded.map((item) {
          final map = _mapOrNull(item);
          if (map == null) throw const FormatException('رکورد نامعتبر');
          return decode(map);
        }).toList();
        if (candidate == backup) await preferences.setString(key, candidate);
        return models;
      } catch (_) {
        // Try the last known-good copy before returning an empty collection.
      }
    }
    return <T>[];
  }

  static Future<Map<String, dynamic>?> _loadMap(String key) async {
    return _mapOrNull(await _loadDecoded(key));
  }

  static Map<String, dynamic>? _mapOrNull(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}
