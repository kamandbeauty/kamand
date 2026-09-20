import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../models/business_profile_model.dart';
import '../../models/app_settings_model.dart';
import '../../models/invoice_model.dart';
import '../../models/customer_model.dart';
import '../../models/product_model.dart';
import '../../models/bank_card_model.dart';
import '../../models/supplier_model.dart';
import '../../models/expense_model.dart';

/// ذخیره پایدار اطلاعات کاربر، فاکتورها و تنظیمات روی گوشی.
///
/// نکته‌ی مهم برای به‌روزرسانی نسخه‌ی نصب‌شده:
/// کلیدها (`ruby_*_v1`) بین نسخه‌ها **تغییر نمی‌کنند**، زیرا اندروید هنگام
/// به‌روزرسانی داده‌ی برنامه را نگه می‌دارد و تغییر نام کلید یعنی از دست رفتن
/// اطلاعات کاربر. خواندن JSON نیز همیشه با مقدار پیش‌فرض انجام می‌شود تا
/// رکوردهای قدیمی که فیلدهای تازه را ندارند بدون خطا خوانده شوند.
class PrefsStore {
  /// نسخه‌ی ساختار داده. نسخه‌ی ۱.۰.۴ تا ۱.۰.۷ نسخه‌ی ۱ بودند.
  static const int schemaVersion = 2;

  // ---- کلیدهای ذخیره‌سازی (پایدار و سازگار با نسخه‌های قبلی) ----
  static const String kUser = 'ruby_user_v1';
  static const String kBusiness = 'ruby_business_v1';
  static const String kSettings = 'ruby_settings_v1';
  static const String kInvoices = 'ruby_invoices_v1';
  static const String kCustomers = 'ruby_customers_v1';
  static const String kProducts = 'ruby_products_v1';
  static const String kDraft = 'ruby_invoice_draft_v1';
  static const String kBankCards = 'ruby_bank_cards_v1';
  static const String kSelectedBankCard = 'ruby_selected_bank_card_v1';
  static const String kSuppliers = 'ruby_suppliers_v1';
  static const String kExpenses = 'ruby_expenses_v1';

  /// کلید دفتر مهاجرت داده‌ها (وضعیت به‌روزرسانی ساختار داده).
  static const String kMigrationLedger = 'ruby_migration_ledger_v1';

  /// مسیر آخرین پشتیبان خودکار پیش از به‌روزرسانی ساختار داده.
  static const String kLastUpgradeBackup = 'ruby_last_upgrade_backup_v1';

  /// محل نگه‌داری رکوردهایی که ساختارشان قابل خواندن نبود. این‌ها پاک
  /// نمی‌شوند تا در صورت نیاز قابل بازیابی باشند.
  static const String kMigrationQuarantine = 'ruby_migration_quarantine_v1';

  /// همه‌ی کلیدهای فهرست‌گونه که مهاجرت باید بررسی‌شان کند.
  static const List<String> listKeys = <String>[
    kInvoices,
    kCustomers,
    kProducts,
    kBankCards,
    kSuppliers,
    kExpenses,
  ];

  /// همه‌ی کلیدهای تکی که مهاجرت باید بررسی‌شان کند.
  static const List<String> mapKeys = <String>[
    kUser,
    kBusiness,
    kSettings,
    kDraft,
  ];

  static Future<SharedPreferences> get _p async => SharedPreferences.getInstance();

  // ---------------------------------------------------------------------------
  // لایه‌ی خام (برای مهاجرت، پشتیبان‌گیری و ترمیم داده)
  // ---------------------------------------------------------------------------

  /// خواندن متن خام یک کلید (برای مهاجرت و پارس دستی).
  static Future<String?> readRawString(String key) async {
    final p = await _p;
    return p.getString(key);
  }

  /// خواندن خام و بدون مدل؛ کلیدهای ناشناخته حفظ می‌شوند.
  static Future<Map<String, dynamic>?> readRawMap(String key) async {
    final p = await _p;
    final raw = p.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return _mapOrNull(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  /// خواندن خام یک لیست؛ اگر یکی از عضوها خراب بود، همان عضو نادیده گرفته
  /// می‌شود و بقیه‌ی داده‌ها حفظ می‌شوند.
  static Future<List<Map<String, dynamic>>> readRawList(String key) async {
    final p = await _p;
    final raw = p.getString(key);
    if (raw == null || raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      return _mapList(jsonDecode(raw));
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  /// نوشتن خام یک مقدار JSON.
  static Future<void> writeRawJson(String key, Object? value) async {
    final p = await _p;
    if (value == null) {
      await p.remove(key);
      return;
    }
    await p.setString(key, jsonEncode(value));
  }

  /// آیا کلید ذخیره‌شده است؟
  static Future<bool> hasKey(String key) async {
    final p = await _p;
    return p.containsKey(key);
  }

  /// همه‌ی کلیدهای ذخیره‌شده روی دستگاه (برای تشخیص نصب تازه).
  static Future<Set<String>> storedKeys() async {
    final p = await _p;
    return p.getKeys();
  }

  // ---------------------------------------------------------------------------
  // کاربر
  // ---------------------------------------------------------------------------

  static Future<void> saveUser(UserModel u) async {
    final p = await _p;
    await p.setString(kUser, jsonEncode(u.toMap()));
  }

  static Future<UserModel?> loadUser() async {
    final map = await _loadMap(kUser);
    return map == null ? null : UserModel.fromMap(map);
  }

  // ---------------------------------------------------------------------------
  // کسب‌وکار
  // ---------------------------------------------------------------------------

  static Future<void> saveBusiness(BusinessProfileModel b) async {
    final p = await _p;
    await p.setString(kBusiness, jsonEncode(b.toMap()));
  }

  static Future<BusinessProfileModel?> loadBusiness() async {
    final map = await _loadMap(kBusiness);
    return map == null ? null : BusinessProfileModel.fromMap(map);
  }

  // ---------------------------------------------------------------------------
  // تنظیمات
  // ---------------------------------------------------------------------------

  static Future<void> saveSettings(AppSettingsModel s) async {
    final p = await _p;
    await p.setString(kSettings, jsonEncode(s.toMap()));
  }

  static Future<AppSettingsModel?> loadSettings() async {
    final map = await _loadMap(kSettings);
    return map == null ? null : AppSettingsModel.fromMap(map);
  }

  // ---------------------------------------------------------------------------
  // فاکتورها
  // ---------------------------------------------------------------------------

  static Future<void> saveInvoices(List<InvoiceModel> invoices) async {
    final p = await _p;
    await p.setString(kInvoices, jsonEncode(invoices.map((e) => e.toMap()).toList()));
  }

  static Future<List<InvoiceModel>> loadInvoices() async {
    final list = await _loadList(kInvoices);
    return list.map(InvoiceModel.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // مشتریان
  // ---------------------------------------------------------------------------

  static Future<void> saveCustomers(List<CustomerModel> customers) async {
    final p = await _p;
    await p.setString(kCustomers, jsonEncode(customers.map((e) => e.toMap()).toList()));
  }

  static Future<List<CustomerModel>> loadCustomers() async {
    final list = await _loadList(kCustomers);
    return list.map(CustomerModel.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // کالاها و خدمات
  // ---------------------------------------------------------------------------

  static Future<void> saveProducts(List<ProductModel> products) async {
    final p = await _p;
    await p.setString(kProducts, jsonEncode(products.map((e) => e.toMap()).toList()));
  }

  static Future<List<ProductModel>> loadProducts() async {
    final list = await _loadList(kProducts);
    return list.map(ProductModel.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // کارت‌های بانکی
  // ---------------------------------------------------------------------------

  static Future<void> saveBankCards(List<BankCardModel> cards) async {
    final p = await _p;
    await p.setString(kBankCards, jsonEncode(cards.map((e) => e.toMap()).toList()));
  }

  static Future<List<BankCardModel>> loadBankCards() async {
    final list = await _loadList(kBankCards);
    return list.map(BankCardModel.fromMap).toList();
  }

  static Future<void> saveSelectedBankCardId(String id) async {
    final p = await _p;
    if (id.isEmpty) {
      await p.remove(kSelectedBankCard);
    } else {
      await p.setString(kSelectedBankCard, id);
    }
  }

  static Future<String?> loadSelectedBankCardId() async {
    final p = await _p;
    return p.getString(kSelectedBankCard);
  }

  static Future<void> clearSelectedBankCardId() async {
    final p = await _p;
    await p.remove(kSelectedBankCard);
  }

  // ---------------------------------------------------------------------------
  // پیش‌نویس فاکتور
  // ---------------------------------------------------------------------------

  static Future<void> saveDraft(InvoiceModel draft) async {
    final p = await _p;
    await p.setString(kDraft, jsonEncode(draft.toMap()));
  }

  static Future<InvoiceModel?> loadDraft() async {
    final map = await _loadMap(kDraft);
    return map == null ? null : InvoiceModel.fromMap(map);
  }

  static Future<void> clearDraft() async {
    final p = await _p;
    await p.remove(kDraft);
  }

  // ---------------------------------------------------------------------------
  // تامین‌کنندگان و هزینه‌ها (جدید در نسخه ۱.۰.۷)
  // ---------------------------------------------------------------------------

  static Future<void> saveSuppliers(List<SupplierModel> suppliers) async {
    final p = await _p;
    await p.setString(kSuppliers, jsonEncode(suppliers.map((e) => e.toMap()).toList()));
  }

  static Future<List<SupplierModel>> loadSuppliers() async {
    final list = await _loadList(kSuppliers);
    return list.map(SupplierModel.fromMap).toList();
  }

  static Future<void> saveExpenses(List<ExpenseModel> expenses) async {
    final p = await _p;
    await p.setString(kExpenses, jsonEncode(expenses.map((e) => e.toMap()).toList()));
  }

  static Future<List<ExpenseModel>> loadExpenses() async {
    final list = await _loadList(kExpenses);
    return list.map(ExpenseModel.fromMap).toList();
  }

  // ---------------------------------------------------------------------------
  // پشتیبان‌گیری و بازگردانی
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> exportAll() async {
    return {
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'user': (await loadUser())?.toMap(),
      'business': (await loadBusiness())?.toMap(),
      'settings': (await loadSettings())?.toMap(),
      'invoices': (await loadInvoices()).map((e) => e.toMap()).toList(),
      'customers': (await loadCustomers()).map((e) => e.toMap()).toList(),
      'products': (await loadProducts()).map((e) => e.toMap()).toList(),
      'suppliers': (await loadSuppliers()).map((e) => e.toMap()).toList(),
      'expenses': (await loadExpenses()).map((e) => e.toMap()).toList(),
      'draft': (await loadDraft())?.toMap(),
      'bankCards': (await loadBankCards()).map((e) => e.toMap()).toList(),
      'selectedBankCardId': await loadSelectedBankCardId(),
    };
  }

  /// پشتیبان خام از همه‌ی کلیدهای ذخیره‌شده، بدون تبدیل مدل.
  /// برای مهاجرت استفاده می‌شود تا حتی رکورد خراب هم در پشتیبان بماند.
  static Future<Map<String, dynamic>> exportRawSnapshot() async {
    final p = await _p;
    final snapshot = <String, dynamic>{};
    for (final key in p.getKeys()) {
      if (key == kMigrationLedger) continue;
      final value = p.get(key);
      if (value is String) {
        try {
          snapshot[key] = jsonDecode(value);
          continue;
        } catch (_) {
          snapshot[key] = value;
          continue;
        }
      }
      snapshot[key] = value;
    }
    return {
      'snapshotVersion': 1,
      'dataVersion': schemaVersion,
      'createdAt': DateTime.now().toIso8601String(),
      'values': snapshot,
    };
  }

  /// بازگردانی پشتیبان خام (خروجی [exportRawSnapshot]).
  static Future<void> importRawSnapshot(Map<String, dynamic> snapshot) async {
    final values = _mapOrNull(snapshot['values']);
    if (values == null) {
      throw const FormatException('ساختار پشتیبان پیش از به‌روزرسانی معتبر نیست');
    }
    final p = await _p;
    for (final entry in values.entries) {
      if (entry.key == kMigrationLedger) continue;
      final value = entry.value;
      if (value == null) continue;
      if (value is String) {
        await p.setString(entry.key, value);
      } else {
        await p.setString(entry.key, jsonEncode(value));
      }
    }
  }

  /// بازگردانی پشتیبان استاندارد برنامه.
  /// پشتیبان نسخه‌های قدیمی فیلدهای تازه را ندارد؛ مقدارهای پیش‌فرض
  /// جای‌شان را پر می‌کنند و بعد از بازگردانی، مهاجرت داده اجرا می‌شود.
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
    if (data['suppliers'] is List) {
      await saveSuppliers(_mapList(data['suppliers']).map(SupplierModel.fromMap).toList());
    }
    if (data['expenses'] is List) {
      await saveExpenses(_mapList(data['expenses']).map(ExpenseModel.fromMap).toList());
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

  // ---------------------------------------------------------------------------
  // کمکی‌ها
  // ---------------------------------------------------------------------------

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
