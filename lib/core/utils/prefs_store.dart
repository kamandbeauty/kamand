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
    final p = await _p;
    await p.setString(_kUser, jsonEncode(u.toMap()));
  }

  static Future<UserModel?> loadUser() async {
    final map = await _loadMap(_kUser);
    return map == null ? null : UserModel.fromMap(map);
  }

  static Future<void> saveBusiness(BusinessProfileModel b) async {
    final p = await _p;
    await p.setString(_kBusiness, jsonEncode(b.toMap()));
  }

  static Future<BusinessProfileModel?> loadBusiness() async {
    final map = await _loadMap(_kBusiness);
    return map == null ? null : BusinessProfileModel.fromMap(map);
  }

  static Future<void> saveSettings(AppSettingsModel s) async {
    final p = await _p;
    await p.setString(_kSettings, jsonEncode(s.toMap()));
  }

  static Future<AppSettingsModel?> loadSettings() async {
    final map = await _loadMap(_kSettings);
    return map == null ? null : AppSettingsModel.fromMap(map);
  }

  static Future<void> saveInvoices(List<InvoiceModel> invoices) async {
    final p = await _p;
    await p.setString(_kInvoices, jsonEncode(invoices.map((e) => e.toMap()).toList()));
  }

  static Future<List<InvoiceModel>> loadInvoices() async {
    final list = await _loadList(_kInvoices);
    return list.map(InvoiceModel.fromMap).toList();
  }

  static Future<void> saveCustomers(List<CustomerModel> customers) async {
    final p = await _p;
    await p.setString(_kCustomers, jsonEncode(customers.map((e) => e.toMap()).toList()));
  }

  static Future<List<CustomerModel>> loadCustomers() async {
    final list = await _loadList(_kCustomers);
    return list.map(CustomerModel.fromMap).toList();
  }

  static Future<void> saveProducts(List<ProductModel> products) async {
    final p = await _p;
    await p.setString(_kProducts, jsonEncode(products.map((e) => e.toMap()).toList()));
  }

  static Future<List<ProductModel>> loadProducts() async {
    final list = await _loadList(_kProducts);
    return list.map(ProductModel.fromMap).toList();
  }

  static Future<void> saveBankCards(List<BankCardModel> cards) async {
    final p = await _p;
    await p.setString(_kBankCards, jsonEncode(cards.map((e) => e.toMap()).toList()));
  }

  static Future<List<BankCardModel>> loadBankCards() async {
    final list = await _loadList(_kBankCards);
    return list.map(BankCardModel.fromMap).toList();
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
    final p = await _p;
    await p.setString(_kInvoiceBalanceLedger, jsonEncode(ledger));
  }

  static Future<void> saveDraft(InvoiceModel draft) async {
    final p = await _p;
    await p.setString(_kDraft, jsonEncode(draft.toMap()));
  }

  static Future<InvoiceModel?> loadDraft() async {
    final map = await _loadMap(_kDraft);
    return map == null ? null : InvoiceModel.fromMap(map);
  }

  static Future<void> clearDraft() async {
    final p = await _p;
    await p.remove(_kDraft);
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

  static Future<Map<String, dynamic>?> _loadMap(String key) async {
    final p = await _p;
    final raw = p.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return _mapOrNull(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> _loadList(String key) async {
    final p = await _p;
    final raw = p.getString(key);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      return _mapList(jsonDecode(raw));
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  static Map<String, dynamic>? _mapOrNull(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value.map(_mapOrNull).whereType<Map<String, dynamic>>().toList();
  }
}
