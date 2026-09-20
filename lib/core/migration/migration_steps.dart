import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../database/app_database.dart';
import '../utils/jalali_helper.dart';
import '../utils/prefs_store.dart';
import 'migration_models.dart';

/// گام‌های مهاجرت داده‌ها از نسخه‌ی ۱.۰.۴–۱.۰.۷ (نسخه‌ی داده ۱) به نسخه‌ی
/// تازه (نسخه‌ی داده ۲).
///
/// همه‌ی گام‌ها با داده‌ی خام (raw map) کار می‌کنند تا هیچ فیلدی از دست نرود؛
/// حتی فیلدهایی که مدل‌های فعلی نمی‌شناسند. هیچ گامی داده‌ی کاربر را حذف
/// نمی‌کند.
List<MigrationStep> buildMigrationSteps({AppDatabase? database}) => <MigrationStep>[
      MigrationStep(
        id: 1,
        title: 'یکسان‌سازی ساختار داده‌های ذخیره‌شده',
        run: _normalizeStoredJson,
      ),
      MigrationStep(
        id: 2,
        title: 'تکمیل قیمت خرید و سود فاکتورهای قبلی',
        run: _backfillInvoiceCosts,
      ),
      MigrationStep(
        id: 3,
        title: 'ساخت کارت حساب تامین‌کنندگان و بازیابی مشتریان از فاکتورها',
        run: _linkPurchaseSuppliers,
      ),
      MigrationStep(
        id: 4,
        title: 'ترمیم شناسه‌ها، تاریخ‌ها و مبلغ‌های نامعتبر',
        run: _repairRecords,
      ),
      MigrationStep(
        id: 5,
        title: 'ارتقای جدول‌های SQLite و همگام‌سازی آینه‌ی داده',
        run: () => _upgradeSqlite(database),
      ),
    ];

// -----------------------------------------------------------------------------
// مقادیر پیش‌فرض نسخه‌ی ۲
// -----------------------------------------------------------------------------

const Map<String, Object> _userDefaults = <String, Object>{
  'id': 'u1',
  'name': '',
  'phone': '',
  'country': '',
  'province': '',
  'city': '',
  'usageType': '',
  'isOnboarded': false,
};

const Map<String, Object> _businessDefaults = <String, Object>{
  'id': 'b1',
  'shopName': '',
  'phone': '',
  'address': '',
  'taxId': '',
  'logoPath': '',
  'stampPath': '',
  'signaturePath': '',
  'bankCards': <String>[],
};

const Map<String, Object> _settingsDefaults = <String, Object>{
  'startingInvoiceNum': 1,
  'templateStyle': 'modern',
  'showLogo': true,
  'showCardNum': true,
  'showStamp': true,
  'showSignature': true,
  'themeMode': 'light',
  'autoBackup': true,
  'pinCode': '',
  'pinEnabled': false,
  'accentColor': 0xFFF97316,
};

const Map<String, Object> _invoiceDefaults = <String, Object>{
  'id': '',
  'number': '',
  'customerId': '',
  'customerName': '',
  'customerPhone': '',
  'type': 'sale',
  'paymentType': 'cash',
  'status': 'paid',
  'date': '',
  'subtotal': 0.0,
  'discountPercent': 0.0,
  'discountAmount': 0.0,
  'shippingFee': 0.0,
  'previousDebt': 0.0,
  'deposit': 0.0,
  'totalAmount': 0.0,
  'paidAmount': 0.0,
  'remainingAmount': 0.0,
  'notes': '',
  'cardNumber': '',
  'cardBank': '',
  'cardOwner': '',
  'createdAt': '',
  'supplierId': '',
  'supplierName': '',
  'totalBuyAmount': 0.0,
  'profitAmount': 0.0,
  'expenseAmount': 0.0,
  'expenseTitle': '',
};

const Map<String, Object> _itemDefaults = <String, Object>{
  'id': '',
  'title': '',
  'quantity': 1.0,
  'unit': 'عدد',
  'unitPrice': 0.0,
  'totalPrice': 0.0,
  'buyPrice': 0.0,
  'productId': '',
};

const Map<String, Object> _customerDefaults = <String, Object>{
  'id': '',
  'name': '',
  'mobile': '',
  'phone': '',
  'address': '',
  'notes': '',
  'balance': 0.0,
  'createdAt': '',
};

const Map<String, Object> _productDefaults = <String, Object>{
  'id': '',
  'code': '',
  'name': '',
  'unit': 'عدد',
  'buyPrice': 0.0,
  'sellPrice': 0.0,
  'stock': 0.0,
  'notes': '',
};

const Map<String, Object> _supplierDefaults = <String, Object>{
  'id': '',
  'name': '',
  'phone': '',
  'mobile': '',
  'address': '',
  'notes': '',
  'balance': 0.0,
  'createdAt': '',
};

const Map<String, Object> _expenseDefaults = <String, Object>{
  'id': '',
  'title': '',
  'amount': 0.0,
  'category': 'سایر',
  'date': '',
  'notes': '',
  'invoiceId': '',
  'createdAt': '',
};

const Map<String, Object> _bankCardDefaults = <String, Object>{
  'id': '',
  'cardNumber': '',
  'sheba': '',
  'bankName': '',
  'persianName': '',
};

/// نام‌های پیش‌فرضی که برنامه وقتی کاربر مشتری/تامین‌کننده را انتخاب نکرده
/// ثبت می‌کند. این‌ها نباید به کارت حساب تبدیل شوند.
const Set<String> _placeholderPartyNames = <String>{
  'مشتری عمومی',
  'تامین‌کننده عمومی',
};

// -----------------------------------------------------------------------------
// گام ۱ — یکسان‌سازی ساختار داده
// -----------------------------------------------------------------------------

Future<MigrationStepOutcome> _normalizeStoredJson() async {
  final warnings = <String>[];
  var changed = 0;

  final user = await PrefsStore.readRawMap(PrefsStore.kUser);
  if (user != null && await _rewriteMap(PrefsStore.kUser, _withDefaults(user, _userDefaults))) {
    changed++;
  }

  final business = await PrefsStore.readRawMap(PrefsStore.kBusiness);
  if (business != null && await _rewriteMap(PrefsStore.kBusiness, _withDefaults(business, _businessDefaults))) {
    changed++;
  }

  final settings = await PrefsStore.readRawMap(PrefsStore.kSettings);
  if (settings != null && await _rewriteMap(PrefsStore.kSettings, _withDefaults(settings, _settingsDefaults))) {
    changed++;
  }

  final draft = await PrefsStore.readRawMap(PrefsStore.kDraft);
  if (draft != null) {
    if (await _rewriteMap(PrefsStore.kDraft, _normalizeInvoice(draft))) changed++;
  }

  changed += await _rewriteList(
    PrefsStore.kInvoices,
    (record) => _normalizeInvoice(record),
    warnings,
    label: 'فاکتور',
  );
  changed += await _rewriteList(
    PrefsStore.kCustomers,
    (record) => _withDefaults(record, _customerDefaults),
    warnings,
    label: 'مشتری',
  );
  changed += await _rewriteList(
    PrefsStore.kProducts,
    (record) => _withDefaults(record, _productDefaults),
    warnings,
    label: 'کالا',
  );
  changed += await _rewriteList(
    PrefsStore.kSuppliers,
    (record) => _withDefaults(record, _supplierDefaults),
    warnings,
    label: 'تامین‌کننده',
  );
  changed += await _rewriteList(
    PrefsStore.kExpenses,
    (record) => _withDefaults(record, _expenseDefaults),
    warnings,
    label: 'هزینه',
  );
  changed += await _rewriteList(
    PrefsStore.kBankCards,
    (record) => _withDefaults(record, _bankCardDefaults),
    warnings,
    label: 'کارت بانکی',
  );

  return MigrationStepOutcome(changedRecords: changed, warnings: warnings);
}

// -----------------------------------------------------------------------------
// گام ۲ — بازسازی قیمت خرید و سود فاکتورهای قدیمی
// -----------------------------------------------------------------------------

Future<MigrationStepOutcome> _backfillInvoiceCosts() async {
  final warnings = <String>[];
  final catalog = await _catalogIndex();
  if (catalog.isEmpty) {
    return const MigrationStepOutcome();
  }

  var fixedItems = 0;
  var fixedInvoices = 0;
  var unmatchedItems = 0;

  for (final key in <String>[PrefsStore.kInvoices, PrefsStore.kDraft]) {
    if (key == PrefsStore.kInvoices) {
      final invoices = await PrefsStore.readRawList(key);
      if (invoices.isEmpty) continue;
      var touched = false;
      final updated = invoices.map((invoice) {
        final result = _backfillInvoice(invoice, catalog, (count, unmatched) {
          fixedItems += count;
          unmatchedItems += unmatched;
        });
        if (result.changed) {
          touched = true;
          fixedInvoices++;
        }
        return result.invoice;
      }).toList();
      if (touched) await PrefsStore.writeRawJson(key, updated);
    } else {
      final draft = await PrefsStore.readRawMap(key);
      if (draft == null) continue;
      final result = _backfillInvoice(draft, catalog, (count, unmatched) {
        fixedItems += count;
        unmatchedItems += unmatched;
      });
      if (result.changed) {
        fixedInvoices++;
        await PrefsStore.writeRawJson(key, result.invoice);
      }
    }
  }

  if (unmatchedItems > 0) {
    warnings.add(
      '$unmatchedItems قلم فاکتور در کاتالوگ پیدا نشد و قیمت خرید آن خالی مانده است؛ '
      'برای گزارش سود دقیق، قیمت خرید آن کالاها را در کاتالوگ ثبت کنید.',
    );
  }

  return MigrationStepOutcome(
    changedRecords: fixedInvoices + fixedItems,
    warnings: warnings,
  );
}

// -----------------------------------------------------------------------------
// گام ۳ — اتصال فاکتورهای خرید به کارت حساب تامین‌کننده
// -----------------------------------------------------------------------------

Future<MigrationStepOutcome> _linkPurchaseSuppliers() async {
  final invoices = await PrefsStore.readRawList(PrefsStore.kInvoices);
  if (invoices.isEmpty) return const MigrationStepOutcome();

  final suppliers = await PrefsStore.readRawList(PrefsStore.kSuppliers);
  final byId = <String, Map<String, dynamic>>{};
  final byName = <String, Map<String, dynamic>>{};
  for (final supplier in suppliers) {
    final id = '${supplier['id'] ?? ''}'.trim();
    if (id.isNotEmpty) byId[id] = supplier;
    final name = _normalizedName('${supplier['name'] ?? ''}');
    if (name.isNotEmpty && !byName.containsKey(name)) byName[name] = supplier;
  }

  final customers = await PrefsStore.readRawList(PrefsStore.kCustomers);
  final customerById = <String, Map<String, dynamic>>{};
  final customerByName = <String, Map<String, dynamic>>{};
  for (final customer in customers) {
    final id = '${customer['id'] ?? ''}'.trim();
    if (id.isNotEmpty) customerById[id] = customer;
    final name = _normalizedName('${customer['name'] ?? ''}');
    if (name.isNotEmpty && !customerByName.containsKey(name)) customerByName[name] = customer;
  }

  final warnings = <String>[];
  var linked = 0;
  var created = 0;
  var recoveredCustomers = 0;
  var changed = false;
  var customersChanged = false;
  final createdIds = <String, String>{}; // id تامین‌کننده‌ی ساخته‌شده → نام
  final createdCustomerIds = <String, String>{};

  final updated = <Map<String, dynamic>>[];
  for (final invoice in invoices) {
    var record = invoice;
    final type = '${invoice['type'] ?? 'sale'}';

    if (type == 'purchase') {
      // در نسخه‌های قبلی نام تامین‌کننده در customerName ذخیره می‌شد.
      var supplierName = '${record['supplierName'] ?? ''}'.trim();
      if (supplierName.isEmpty) {
        supplierName = '${record['customerName'] ?? ''}'.trim();
        if (supplierName.isNotEmpty) {
          record = Map<String, dynamic>.from(record)..['supplierName'] = supplierName;
          changed = true;
        }
      }

      if (supplierName.isNotEmpty) {
        var supplierId = '${record['supplierId'] ?? ''}'.trim();
        final known = byId[supplierId];
        if (known == null) {
          final existing = byName[_normalizedName(supplierName)];
          if (existing != null) {
            supplierId = '${existing['id']}';
          } else if (_placeholderPartyNames.contains(supplierName)) {
            supplierId = '';
          } else {
            supplierId = 'sup-${DateTime.now().millisecondsSinceEpoch}-$created';
            final createdSupplier = <String, dynamic>{
              ..._withDefaults(<String, dynamic>{}, _supplierDefaults),
              'id': supplierId,
              'name': supplierName,
              'balance': 0.0,
              'createdAt': _todayJalali(),
            };
            suppliers.add(createdSupplier);
            byId[supplierId] = createdSupplier;
            byName[_normalizedName(supplierName)] = createdSupplier;
            createdIds[supplierId] = supplierName;
            created++;
          }
          if (supplierId.isNotEmpty && supplierId != '${record['supplierId'] ?? ''}'.trim()) {
            record = Map<String, dynamic>.from(record)..['supplierId'] = supplierId;
            changed = true;
            linked++;
          }
        }
      } else {
        warnings.add('فاکتور خرید شماره ${record['number'] ?? ''} نام تامین‌کننده ندارد.');
      }
    } else if (type == 'sale') {
      // بازیابی مشتریانی که فاکتور دارند اما در فهرست مشتریان نیستند.
      //
      // در نسخه‌های قبلی، اگر کاربر پیش از کامل شدن خواندن اطلاعات ذخیره‌شده
      // روی «افزودن مشتری» ضربه می‌زد، فهرست مشتریان با لیست خالی بازنویسی
      // می‌شد و مشتری‌ها ناپدید می‌شدند؛ فاکتورها اما باقی می‌ماندند. این گام
      // مشتری را از روی فاکتور بازمی‌سازد تا هیچ اطلاعاتی از بین نرود.
      final customerName = '${record['customerName'] ?? ''}'.trim();
      if (customerName.isNotEmpty) {
        var customerId = '${record['customerId'] ?? ''}'.trim();
        var known = customerId.isEmpty ? null : customerById[customerId];
        if (known == null) {
          final existing = customerByName[_normalizedName(customerName)];
          if (existing != null) {
            customerId = '${existing['id']}';
            known = existing;
          } else if (_placeholderPartyNames.contains(customerName)) {
            customerId = '';
          } else {
            customerId = 'cus-${DateTime.now().millisecondsSinceEpoch}-$recoveredCustomers';
            final createdCustomer = <String, dynamic>{
              ..._withDefaults(<String, dynamic>{}, _customerDefaults),
              'id': customerId,
              'name': customerName,
              'mobile': '${record['customerPhone'] ?? ''}',
              'balance': 0.0,
              'createdAt':
                  '${record['date'] ?? ''}'.trim().isEmpty ? _todayJalali() : '${record['date']}',
            };
            customers.add(createdCustomer);
            customerById[customerId] = createdCustomer;
            customerByName[_normalizedName(customerName)] = createdCustomer;
            createdCustomerIds[customerId] = customerName;
            recoveredCustomers++;
            customersChanged = true;
          }
        }
        if (customerId.isNotEmpty && customerId != '${record['customerId'] ?? ''}'.trim()) {
          record = Map<String, dynamic>.from(record)..['customerId'] = customerId;
          changed = true;
          linked++;
        }
      } else {
        warnings.add('فاکتور فروش شماره ${record['number'] ?? ''} نام مشتری ندارد.');
      }
    }
    updated.add(record);
  }

  // مانده‌حساب تامین‌کنندگان تازه‌ساخته‌شده از روی فاکتورهای خرید همان
  // تامین‌کننده محاسبه می‌شود. برای تامین‌کننده‌هایی که کاربر خودش ساخته است
  // هیچ تغییری اعمال نمی‌شود تا مبلغی دو بار حساب نشود.
  if (createdIds.isNotEmpty) {
    final balances = <String, double>{};
    for (final invoice in updated) {
      final type = '${invoice['type'] ?? ''}';
      if (type != 'purchase') continue;
      final supplierId = '${invoice['supplierId'] ?? ''}';
      if (!createdIds.containsKey(supplierId)) continue;
      balances[supplierId] = (balances[supplierId] ?? 0) + _toDouble(invoice['remainingAmount']);
    }
    for (final supplier in suppliers) {
      final id = '${supplier['id'] ?? ''}';
      if (!createdIds.containsKey(id)) continue;
      final balance = balances[id] ?? 0;
      if (_toDouble(supplier['balance']) != balance) {
        supplier['balance'] = balance;
        changed = true;
      }
    }
  }

  // همان قاعده برای مشتریان بازیابی‌شده: مانده‌حساب فقط برای مشتریانی که در
  // همین گام ساخته شده‌اند و فقط یک بار محاسبه می‌شود.
  if (createdCustomerIds.isNotEmpty) {
    final balances = <String, double>{};
    for (final invoice in updated) {
      if ('${invoice['type'] ?? ''}' != 'sale') continue;
      final customerId = '${invoice['customerId'] ?? ''}';
      if (!createdCustomerIds.containsKey(customerId)) continue;
      balances[customerId] = (balances[customerId] ?? 0) + _toDouble(invoice['remainingAmount']);
    }
    for (final customer in customers) {
      final id = '${customer['id'] ?? ''}';
      if (!createdCustomerIds.containsKey(id)) continue;
      final balance = balances[id] ?? 0;
      if (_toDouble(customer['balance']) != balance) {
        customer['balance'] = balance;
        customersChanged = true;
      }
    }
    warnings.add(
      '$recoveredCustomers مشتری که در فهرست مشتریان نبود از روی فاکتورهایشان بازسازی شد؛ '
      'مانده‌حساب آن‌ها از روی فاکتورهای پرداخت‌نشده محاسبه شده است.',
    );
  }

  if (changed) {
    await PrefsStore.writeRawJson(PrefsStore.kInvoices, updated);
  }
  if (created > 0 || customersChanged) {
    await PrefsStore.writeRawJson(PrefsStore.kSuppliers, suppliers);
    await PrefsStore.writeRawJson(PrefsStore.kCustomers, customers);
  }

  return MigrationStepOutcome(
    changedRecords: linked + created + recoveredCustomers,
    warnings: warnings,
  );
}

// -----------------------------------------------------------------------------
// گام ۴ — ترمیم شناسه‌ها، تاریخ‌ها و مبلغ‌های نامعتبر
// -----------------------------------------------------------------------------

Future<MigrationStepOutcome> _repairRecords() async {
  final warnings = <String>[];
  var changed = 0;

  changed += await _repairList(PrefsStore.kInvoices, 'inv-legacy', warnings, (record) {
    final result = Map<String, dynamic>.from(record);
    final total = _toDouble(result['totalAmount']);
    var paid = _toDouble(result['paidAmount']);
    if (paid < 0) paid = 0;
    if (paid > total) paid = total;
    final remaining = (total - paid) < 0 ? 0.0 : total - paid;
    if (_toDouble(result['paidAmount']) != paid) result['paidAmount'] = paid;
    if (_toDouble(result['remainingAmount']) != remaining) result['remainingAmount'] = remaining;
    if ('${result['createdAt'] ?? ''}'.trim().isEmpty) {
      final date = '${result['date'] ?? ''}'.trim();
      result['createdAt'] = date.isEmpty ? _todayJalali() : date;
    }
    return result;
  });

  changed += await _repairList(PrefsStore.kCustomers, 'cus-legacy', warnings, (record) {
    final result = Map<String, dynamic>.from(record);
    final balance = _toDouble(result['balance']);
    if (balance < 0) result['balance'] = 0.0;
    if ('${result['createdAt'] ?? ''}'.trim().isEmpty) result['createdAt'] = _todayJalali();
    return result;
  });

  changed += await _repairList(PrefsStore.kSuppliers, 'sup-legacy', warnings, (record) {
    final result = Map<String, dynamic>.from(record);
    final balance = _toDouble(result['balance']);
    if (balance < 0) result['balance'] = 0.0;
    if ('${result['createdAt'] ?? ''}'.trim().isEmpty) result['createdAt'] = _todayJalali();
    return result;
  });

  changed += await _repairList(PrefsStore.kProducts, 'prd-legacy', warnings, (record) {
    final result = Map<String, dynamic>.from(record);
    if (_toDouble(result['sellPrice']) < 0) result['sellPrice'] = 0.0;
    if (_toDouble(result['buyPrice']) < 0) result['buyPrice'] = 0.0;
    return result;
  });

  changed += await _repairList(PrefsStore.kExpenses, 'exp-legacy', warnings, (record) {
    final result = Map<String, dynamic>.from(record);
    if (_toDouble(result['amount']) < 0) result['amount'] = 0.0;
    if ('${result['createdAt'] ?? ''}'.trim().isEmpty) {
      final date = '${result['date'] ?? ''}'.trim();
      result['createdAt'] = date.isEmpty ? _todayJalali() : date;
    }
    return result;
  });

  changed += await _repairList(PrefsStore.kBankCards, 'card-legacy', warnings, (record) => record);

  final draft = await PrefsStore.readRawMap(PrefsStore.kDraft);
  if (draft != null) {
    final repaired = Map<String, dynamic>.from(draft);
    if ('${repaired['id'] ?? ''}'.trim().isEmpty) {
      repaired['id'] = 'draft-legacy-$_stamp';
    }
    if ('${repaired['createdAt'] ?? ''}'.trim().isEmpty) {
      repaired['createdAt'] = _todayJalali();
    }
    if (await _rewriteMap(PrefsStore.kDraft, repaired)) changed++;
  }

  return MigrationStepOutcome(changedRecords: changed, warnings: warnings);
}

// -----------------------------------------------------------------------------
// گام ۵ — ارتقای SQLite و آینه‌کردن داده
// -----------------------------------------------------------------------------

Future<MigrationStepOutcome> _upgradeSqlite(AppDatabase? database) async {
  if (database == null) return const MigrationStepOutcome();
  final warnings = <String>[];
  try {
    await database.ready
        .timeout(const Duration(seconds: 15), onTimeout: () => null);
    if (!database.isReady) {
      return const MigrationStepOutcome(
        warnings: <String>['پایگاه‌داده‌ی محلی در دسترس نبود؛ اطلاعات اصلی سالم است.'],
      );
    }

    await database.mirrorInvoices(await PrefsStore.loadInvoices());
    await database.mirrorCustomers(await PrefsStore.loadCustomers());
    await database.mirrorProducts(await PrefsStore.loadProducts());
    await database.mirrorSuppliers(await PrefsStore.loadSuppliers());
    await database.mirrorExpenses(await PrefsStore.loadExpenses());
    await database.mirrorBankCards(await PrefsStore.loadBankCards());

    final invoiceCount = await database.countRows('invoices');
    await database.logEvent('last_data_migration', DateTime.now().toIso8601String());
    await database.logEvent('last_data_migration_invoice_count', '$invoiceCount');

    return MigrationStepOutcome(changedRecords: invoiceCount);
  } catch (error) {
    debugPrint('SQLite upgrade step failed: $error');
    warnings.add('به‌روزرسانی پایگاه‌داده‌ی محلی با خطا مواجه شد؛ داده‌های برنامه سالم است.');
    return MigrationStepOutcome(warnings: warnings);
  }
}

// -----------------------------------------------------------------------------
// کمکی‌ها
// -----------------------------------------------------------------------------

Future<Map<String, Map<String, dynamic>>> _catalogIndex() async {
  final products = await PrefsStore.readRawList(PrefsStore.kProducts);
  final byId = <String, Map<String, dynamic>>{};
  final byName = <String, Map<String, dynamic>>{};
  for (final product in products) {
    final id = '${product['id'] ?? ''}'.trim();
    if (id.isNotEmpty) byId[id] = product;
    final name = _normalizedName('${product['name'] ?? ''}');
    if (name.isNotEmpty && !byName.containsKey(name)) byName[name] = product;
  }
  return <String, Map<String, dynamic>>{...byId, ...byName};
}

({Map<String, dynamic> invoice, bool changed}) _backfillInvoice(
  Map<String, dynamic> invoice,
  Map<String, Map<String, dynamic>> catalog,
  void Function(int fixedItems, int unmatchedItems) onItemFix,
) {
  final result = Map<String, dynamic>.from(invoice);
  final items = invoice['items'];
  var changed = false;
  var itemFixes = 0;
  var unmatched = 0;

  if (items is List) {
    final updatedItems = <dynamic>[];
    for (final rawItem in items) {
      if (rawItem is! Map) {
        updatedItems.add(rawItem);
        continue;
      }
      final item = Map<String, dynamic>.from(rawItem);
      final quantity = _toDouble(item['quantity'], 1);
      final unitPrice = _toDouble(item['unitPrice']);
      var buyPrice = _toDouble(item['buyPrice']);
      var productId = '${item['productId'] ?? ''}'.trim();

      if (buyPrice <= 0) {
        final match = (productId.isNotEmpty ? catalog[productId] : null) ??
            catalog[_normalizedName('${item['title'] ?? ''}')];
        if (match != null) {
          final catalogBuy = _toDouble(match['buyPrice']);
          if (catalogBuy > 0) {
            buyPrice = catalogBuy;
            productId = '${match['id'] ?? productId}';
            itemFixes++;
          } else {
            unmatched++;
          }
        } else if ('${item['title'] ?? ''}'.trim().isNotEmpty) {
          unmatched++;
        }
      }

      final expectedTotal = quantity * unitPrice;
      if (_toDouble(item['totalPrice']) <= 0 && expectedTotal > 0) {
        item['totalPrice'] = expectedTotal;
        itemFixes++;
      }
      if (_toDouble(item['buyPrice']) != buyPrice) item['buyPrice'] = buyPrice;
      if ('${item['productId'] ?? ''}' != productId) item['productId'] = productId;
      updatedItems.add(item);
    }
    result['items'] = updatedItems;

    // بازمحاسبه‌ی بهای تمام شده و سود فاکتور
    final normalizedItems = updatedItems.whereType<Map>().map(Map<String, dynamic>.from).toList();
    var totalBuy = 0.0;
    var totalProfit = 0.0;
    for (final item in normalizedItems) {
      final quantity = _toDouble(item['quantity'], 1);
      final unitPrice = _toDouble(item['unitPrice']);
      final buyPrice = _toDouble(item['buyPrice']);
      totalBuy += buyPrice * quantity;
      totalProfit += (unitPrice - buyPrice) * quantity;
    }

    final isPurchase = '${result['type'] ?? ''}' == 'purchase';
    final expectedProfit = isPurchase ? 0.0 : totalProfit;
    if (_differs(_toDouble(result['totalBuyAmount']), totalBuy)) {
      result['totalBuyAmount'] = totalBuy;
      changed = true;
    }
    if (_differs(_toDouble(result['profitAmount']), expectedProfit)) {
      result['profitAmount'] = expectedProfit;
      changed = true;
    }
  }

  if (result['expenseAmount'] == null) {
    result['expenseAmount'] = 0.0;
    changed = true;
  }
  if (result['expenseTitle'] == null) {
    result['expenseTitle'] = '';
    changed = true;
  }

  onItemFix(itemFixes, unmatched);
  return (invoice: result, changed: changed || itemFixes > 0);
}

Map<String, dynamic> _normalizeInvoice(Map<String, dynamic> raw) {
  final result = _withDefaults(raw, _invoiceDefaults);
  final items = result['items'];
  final normalizedItems = <Map<String, dynamic>>[];
  if (items is List) {
    for (final item in items) {
      if (item is Map) {
        normalizedItems.add(_withDefaults(Map<String, dynamic>.from(item), _itemDefaults));
      }
    }
  }
  result['items'] = normalizedItems;
  return result;
}

Map<String, dynamic> _withDefaults(Map<String, dynamic> source, Map<String, Object> defaults) {
  final result = Map<String, dynamic>.from(source);
  for (final entry in defaults.entries) {
    result[entry.key] = _coerce(result[entry.key], entry.value);
  }
  return result;
}

dynamic _coerce(dynamic value, Object fallback) {
  if (fallback is bool) return _toBool(value, fallback);
  if (fallback is int) return _toInt(value, fallback);
  if (fallback is double) return _toDouble(value, fallback);
  if (fallback is List) return value is List ? List<dynamic>.from(value) : <dynamic>[];
  return value == null ? '' : '$value';
}

Future<bool> _rewriteMap(String key, Map<String, dynamic> value) async {
  final current = await PrefsStore.readRawMap(key);
  if (current != null && _sameJson(current, value)) return false;
  await PrefsStore.writeRawJson(key, value);
  return true;
}

Future<int> _rewriteList(
  String key,
  Map<String, dynamic> Function(Map<String, dynamic> record) normalize,
  List<String> warnings, {
  required String label,
}) async {
  final loaded = await _readRecords(key);
  if (loaded.records.isEmpty) return 0;
  if (loaded.invalid.isNotEmpty) {
    await _quarantine(key, loaded.invalid, warnings, label: label);
  }
  final updated = <Map<String, dynamic>>[];
  var changedRecords = 0;
  for (final record in loaded.records) {
    final normalized = normalize(record);
    if (!_sameJson(record, normalized)) changedRecords++;
    updated.add(normalized);
  }
  if (changedRecords == 0) return 0;
  await PrefsStore.writeRawJson(key, updated);
  return changedRecords;
}

/// ترمیم لیست: شناسه‌ی خالی، شناسه‌ی تکراری و رکوردهای خراب.
Future<int> _repairList(
  String key,
  String idPrefix,
  List<String> warnings,
  Map<String, dynamic> Function(Map<String, dynamic> record) repair,
) async {
  final loaded = await _readRecords(key);
  if (loaded.records.isEmpty) {
    if (loaded.invalid.isNotEmpty) {
      await _quarantine(key, loaded.invalid, warnings, label: key);
    }
    return 0;
  }
  if (loaded.invalid.isNotEmpty) {
    await _quarantine(key, loaded.invalid, warnings, label: key);
  }

  final seen = <String>{};
  final updated = <Map<String, dynamic>>[];
  var changed = false;
  var duplicates = 0;

  for (final record in loaded.records) {
    final repaired = repair(record);
    var id = '${repaired['id'] ?? ''}'.trim();
    if (id.isEmpty) {
      id = '$idPrefix-${_stamp}-${updated.length}';
      repaired['id'] = id;
      changed = true;
    }
    if (seen.contains(id)) {
      // به‌جای حذف رکورد تکراری، شناسه‌ی تازه می‌گیرد تا داده‌ی کاربر از
      // دست نرود.
      duplicates++;
      id = '$id-dup$duplicates';
      repaired['id'] = id;
      changed = true;
    }
    seen.add(id);
    if (!_sameJson(record, repaired)) changed = true;
    updated.add(repaired);
  }

  if (duplicates > 0) {
    warnings.add('$duplicates رکورد با شناسه‌ی تکراری در «$key» پیدا شد؛ شناسه‌ی تازه گرفت و داده حذف نشد.');
  }
  if (!changed) return 0;
  await PrefsStore.writeRawJson(key, updated);
  return updated.length;
}

/// خواندن رکوردهای یک کلید، با جدا کردن عضوهای ناخوانا به‌جای حذف آن‌ها.
Future<({List<Map<String, dynamic>> records, List<dynamic> invalid})> _readRecords(String key) async {
  final raw = await PrefsStore.readRawString(key);
  if (raw == null || raw.trim().isEmpty) {
    return (records: <Map<String, dynamic>>[], invalid: <dynamic>[]);
  }
  dynamic parsed;
  try {
    parsed = jsonDecode(raw);
  } catch (_) {
    return (records: <Map<String, dynamic>>[], invalid: <dynamic>[raw]);
  }
  if (parsed is Map) {
    // اگر یک رکورد تنها (بدون لیست) ذخیره شده باشد، به لیست تبدیل می‌شود.
    return (records: <Map<String, dynamic>>[Map<String, dynamic>.from(parsed)], invalid: <dynamic>[]);
  }
  if (parsed is! List) {
    return (records: <Map<String, dynamic>>[], invalid: <dynamic>[parsed]);
  }
  final records = <Map<String, dynamic>>[];
  final invalid = <dynamic>[];
  for (final item in parsed) {
    if (item is Map) {
      records.add(Map<String, dynamic>.from(item));
    } else {
      invalid.add(item);
    }
  }
  return (records: records, invalid: invalid);
}

/// نگه‌داری عضوهای ناخوانا در کلید قرنطینه (هیچ چیزی دور ریخته نمی‌شود).
Future<void> _quarantine(String key, List<dynamic> invalid, List<String> warnings, {required String label}) async {
  try {
    final current = await PrefsStore.readRawMap(PrefsStore.kMigrationQuarantine) ?? <String, dynamic>{};
    final entries = current[key];
    final list = entries is List ? List<dynamic>.from(entries) : <dynamic>[];
    list.addAll(invalid);
    current[key] = list;
    current['updatedAt'] = DateTime.now().toIso8601String();
    await PrefsStore.writeRawJson(PrefsStore.kMigrationQuarantine, current);
    warnings.add('${invalid.length} رکورد ناخوانا در «$label» پیدا شد؛ حذف نشد و در نسخه‌ی پشتیبان نگه داشته شد.');
  } catch (_) {}
}

bool _sameJson(Map<String, dynamic> a, Map<String, dynamic> b) {
  final left = _canonicalJson(a);
  final right = _canonicalJson(b);
  return left == right;
}

String _canonicalJson(Map<String, dynamic> map) {
  final keys = map.keys.toList()..sort();
  final buffer = StringBuffer('{');
  for (final key in keys) {
    buffer.write('"$key":');
    final value = map[key];
    if (value is Map) {
      buffer.write(_canonicalJson(Map<String, dynamic>.from(value)));
    } else if (value is List) {
      buffer.write('[');
      for (final item in value) {
        if (item is Map) {
          buffer.write(_canonicalJson(Map<String, dynamic>.from(item)));
        } else {
          buffer.write('$item');
        }
        buffer.write(',');
      }
      buffer.write(']');
    } else {
      buffer.write('$value');
    }
    buffer.write(',');
  }
  buffer.write('}');
  return buffer.toString();
}

double _toDouble(dynamic value, [double fallback = 0]) {
  if (value is num) {
    final result = value.toDouble();
    return result.isFinite ? result : fallback;
  }
  if (value is String) {
    final cleaned = _toEnglishDigits(value).replaceAll(',', '').trim();
    final parsed = double.tryParse(cleaned);
    if (parsed != null && parsed.isFinite) return parsed;
  }
  return fallback;
}

int _toInt(dynamic value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(_toEnglishDigits(value).trim());
    if (parsed != null) return parsed;
    final asDouble = double.tryParse(_toEnglishDigits(value).trim());
    if (asDouble != null) return asDouble.toInt();
  }
  return fallback;
}

bool _toBool(dynamic value, bool fallback) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return fallback;
}

bool _differs(double a, double b) => (a - b).abs() > 0.009;

String _normalizedName(String value) {
  return _toEnglishDigits(value)
      .replaceAll('\u200c', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();
}

String _toEnglishDigits(String value) {
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  var result = value;
  for (var i = 0; i < 10; i++) {
    result = result.replaceAll(persian[i], '$i').replaceAll(arabic[i], '$i');
  }
  return result;
}

String _todayJalali() {
  try {
    return JalaliHelper.getTodayJalali();
  } catch (_) {
    return DateTime.now().toIso8601String().split('T').first;
  }
}

int get _stamp => DateTime.now().millisecondsSinceEpoch;
