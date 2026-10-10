import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer_model.dart';
import '../models/invoice_model.dart';
import '../core/utils/prefs_store.dart';
import '../database/app_database.dart';

final customerListProvider =
    StateNotifierProvider<CustomerListNotifier, List<CustomerModel>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CustomerListNotifier(db);
});

class CustomerListNotifier extends StateNotifier<List<CustomerModel>> {
  final AppDatabase? db;
  final Map<String, Map<String, dynamic>> _invoiceBalanceLedger = {};
  late final Future<void> _hydrated;

  CustomerListNotifier([this.db]) : super(const []) {
    _hydrated = _hydrate();
  }

  Future<void> ensureLoaded() => _hydrated;

  Future<void> _hydrate() async {
    final loaded = await Future.wait<dynamic>([
      PrefsStore.loadCustomers(),
      PrefsStore.loadInvoiceBalanceLedger(),
    ]);
    state = loaded[0] as List<CustomerModel>;
    _invoiceBalanceLedger
      ..clear()
      ..addAll(loaded[1] as Map<String, Map<String, dynamic>>);
  }

  Future<void> _persist() => PrefsStore.saveCustomers(state);

  Future<void> addCustomer(CustomerModel customer) async {
    await _hydrated;
    state = [...state, customer];
    await _persist();
    await db?.persistCustomerRecord(
      customer.id,
      customer.name,
      customer.balance,
      customer.createdAt,
    );
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    await _hydrated;
    state = [
      for (final item in state)
        if (item.id == customer.id) customer else item,
    ];
    await _persist();
    await db?.persistCustomerRecord(
      customer.id,
      customer.name,
      customer.balance,
      customer.createdAt,
    );
  }

  Future<void> deleteCustomer(String id) async {
    await _hydrated;
    state = state.where((item) => item.id != id).toList();
    await _persist();
    await db?.deleteCustomerRecord(id);
  }

  Future<void> recordPayment(String id, double amount) async {
    await updateBalance(id, -amount);
  }

  Future<void> updateBalance(String id, double delta) async {
    await _hydrated;
    final index = state.indexWhere((item) => item.id == id);
    if (index < 0 || delta == 0) return;

    final updated = _withBalance(
      state[index],
      (state[index].balance + delta).clamp(0, double.infinity).toDouble(),
    );
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == index) updated else state[i],
    ];
    await _persist();
    await db?.persistCustomerRecord(
      updated.id,
      updated.name,
      updated.balance,
      updated.createdAt,
    );
  }

  /// Applies only the balance delta caused by an invoice mutation.
  ///
  /// The persisted ledger is an intentionally conservative migration boundary:
  /// invoices created by older versions have no ledger entry, so their first
  /// edit only establishes a baseline and their deletion does not guess at (or
  /// damage) an existing customer balance. All newly created invoices and all
  /// subsequent edits are tracked exactly.
  Future<void> applyInvoiceChange(
    InvoiceModel? before,
    InvoiceModel? after,
  ) async {
    await _hydrated;
    final invoiceId = after?.id ?? before?.id;
    if (invoiceId == null) return;

    final ledgerEntry = _invoiceBalanceLedger[invoiceId];
    if (ledgerEntry == null && before != null) {
      if (after != null) {
        _invoiceBalanceLedger[invoiceId] = _ledgerEntry(after);
        await PrefsStore.saveInvoiceBalanceLedger(_invoiceBalanceLedger);
      }
      return;
    }

    final beforeId = ledgerEntry?['customerId'] as String?;
    final beforeImpact = (ledgerEntry?['impact'] as num?)?.toDouble() ?? 0;
    final beforeReference =
        (ledgerEntry?['referenceImpact'] as num?)?.toDouble() ?? beforeImpact;
    final afterId = after == null ? null : _resolveCustomerId(after);
    final afterImpact = after?.customerBalanceImpact ?? 0;
    final deltas = <String, double>{};

    if (afterId != null && afterId == beforeId) {
      // Only the difference from the last invoice snapshot is new. The
      // separately tracked applied impact keeps legacy baseline amounts safe.
      deltas[afterId] = afterImpact - beforeReference;
    } else {
      if (beforeId != null && beforeId.isNotEmpty) {
        deltas[beforeId] = (deltas[beforeId] ?? 0) - beforeImpact;
      }
      if (afterId != null) {
        deltas[afterId] = (deltas[afterId] ?? 0) + afterImpact;
      }
    }

    final changed = <CustomerModel>[];
    final actualDeltas = <String, double>{};
    if (deltas.values.any((delta) => delta != 0)) {
      state = state.map((customer) {
        final delta = deltas[customer.id] ?? 0;
        if (delta == 0) return customer;
        final nextBalance =
            (customer.balance + delta).clamp(0, double.infinity).toDouble();
        final actualDelta = nextBalance - customer.balance;
        actualDeltas[customer.id] = actualDelta;
        if (actualDelta == 0) return customer;
        final updated = _withBalance(customer, nextBalance);
        changed.add(updated);
        return updated;
      }).toList();
      if (changed.isNotEmpty) await _persist();
    }

    if (after == null) {
      _invoiceBalanceLedger.remove(invoiceId);
    } else {
      var appliedImpact = 0.0;
      if (afterId != null) {
        appliedImpact = beforeId == afterId
            ? beforeImpact + (actualDeltas[afterId] ?? 0)
            : actualDeltas[afterId] ?? 0;
      }
      _invoiceBalanceLedger[invoiceId] = {
        'customerId': afterId ?? '',
        // Store the amount actually applied after the zero-balance clamp so a
        // future edit/delete can reverse it exactly.
        'impact': appliedImpact,
        'referenceImpact': afterImpact,
      };
    }
    await PrefsStore.saveInvoiceBalanceLedger(_invoiceBalanceLedger);

    for (final customer in changed) {
      await db?.persistCustomerRecord(
        customer.id,
        customer.name,
        customer.balance,
        customer.createdAt,
      );
    }
  }

  Map<String, dynamic> _ledgerEntry(InvoiceModel invoice) {
    final customerId = _resolveCustomerId(invoice);
    return {
      'customerId': customerId ?? '',
      // Legacy invoices establish a comparison baseline without assuming that
      // older app versions did (or did not) add them to the customer balance.
      'impact': 0,
      'referenceImpact': invoice.customerBalanceImpact,
    };
  }

  String? _resolveCustomerId(InvoiceModel invoice) {
    if (invoice.customerId.isNotEmpty &&
        state.any((customer) => customer.id == invoice.customerId)) {
      return invoice.customerId;
    }

    final phone = invoice.customerPhone.replaceAll(RegExp(r'\D'), '');
    if (phone.isNotEmpty) {
      final phoneMatches = state.where((customer) {
        final mobile = customer.mobile.replaceAll(RegExp(r'\D'), '');
        final landline = customer.phone.replaceAll(RegExp(r'\D'), '');
        return mobile == phone || landline == phone;
      }).toList();
      if (phoneMatches.length == 1) return phoneMatches.single.id;
    }

    final name = invoice.customerName.trim();
    if (name.isNotEmpty && name != 'مشتری عمومی') {
      final nameMatches = state
          .where((customer) => customer.name.trim() == name)
          .toList();
      if (nameMatches.length == 1) return nameMatches.single.id;
    }
    return null;
  }

  CustomerModel _withBalance(CustomerModel item, double balance) => CustomerModel(
        id: item.id,
        name: item.name,
        mobile: item.mobile,
        phone: item.phone,
        address: item.address,
        notes: item.notes,
        nationalId: item.nationalId,
        economicCode: item.economicCode,
        postalCode: item.postalCode,
        balance: balance,
        createdAt: item.createdAt,
      );
}
