import 'dart:convert';
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
    return {
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'user': (await loadUser())?.toMap(),
      'business': (await loadBusiness())?.toMap(),
      'settings': (await loadSettings())?.toMap(),
      'invoices': (await loadInvoices()).map((e) => e.toMap()).toList(),
      'customers': (await loadCustomers()).map((e) => e.toMap()).toList(),
      'products': (await loadProducts()).map((e) => e.toMap()).toList(),
      'draft': (await loadDraft())?.toMap(),
      'bankCards': (await loadBankCards()).map((e) => e.toMap()).toList(),
      'selectedBankCardId': await loadSelectedBankCardId(),
    };
  }

  static Future<void> importAll(Map<String, dynamic> data) async {
    final user = _mapOrNull(data['user']);
    final business = _mapOrNull(data['business']);
    final settings = _mapOrNull(data['settings']);
    final draft = _mapOrNull(data['draft']);

    if (user != null) await saveUser(UserModel.fromMap(user));
    if (business != null) await saveBusiness(BusinessProfileModel.fromMap(business));
    if (settings != null) await saveSettings(AppSettingsModel.fromMap(settings));
    if (data['invoices'] is List) {
      await saveInvoices(_mapList(data['invoices']).map(InvoiceModel.fromMap).toList());
    }
    if (data['customers'] is List) {
      await saveCustomers(_mapList(data['customers']).map(CustomerModel.fromMap).toList());
    }
    if (data['products'] is List) {
      await saveProducts(_mapList(data['products']).map(ProductModel.fromMap).toList());
    }
    if (data['bankCards'] is List) {
      await saveBankCards(_mapList(data['bankCards']).map(BankCardModel.fromMap).toList());
    }
    if (data['selectedBankCardId'] is String && (data['selectedBankCardId'] as String).isNotEmpty) {
      await saveSelectedBankCardId(data['selectedBankCardId'] as String);
    }
    if (draft != null) {
      await saveDraft(InvoiceModel.fromMap(draft));
    } else {
      await clearDraft();
    }
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
