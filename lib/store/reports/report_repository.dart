import '../core/accounts.dart';
import '../core/ledger.dart';
import '../db/store_database.dart';

class DashboardSummary {
  final int todaySales;
  final int todayInvoiceCount;
  final int todayCashSales;
  final int todayCreditSales;
  final int todayInstallmentSales;
  final int receivables;
  final int payables;
  final int todayExpenses;
  final int monthNetProfit;
  final int lowStockCount;
  final int dueTodayCount;
  final int dueTodayAmount;
  final int overdueCount;
  final int overdueAmount;
  final int expectedReceivables;
  final int expectedPayments;

  const DashboardSummary({
    required this.todaySales,
    required this.todayInvoiceCount,
    required this.todayCashSales,
    required this.todayCreditSales,
    required this.todayInstallmentSales,
    required this.receivables,
    required this.payables,
    required this.todayExpenses,
    required this.monthNetProfit,
    required this.lowStockCount,
    required this.dueTodayCount,
    required this.dueTodayAmount,
    required this.overdueCount,
    required this.overdueAmount,
    required this.expectedReceivables,
    required this.expectedPayments,
  });
}

class ProfitAndLoss {
  final int revenue;
  final int returns;
  final int netRevenue;
  final int cogs;
  final int grossProfit;
  final int providerCommissions;
  final int operatingExpenses;
  final Map<String, int> expensesByCategory;
  final int netProfit;
  final int cashReceived;
  final int cashPaidOut;
  final int outstandingProviderSettlement;
  final int outstandingStoreInstallments;

  const ProfitAndLoss({
    required this.revenue,
    required this.returns,
    required this.netRevenue,
    required this.cogs,
    required this.grossProfit,
    required this.providerCommissions,
    required this.operatingExpenses,
    required this.expensesByCategory,
    required this.netProfit,
    required this.cashReceived,
    required this.cashPaidOut,
    required this.outstandingProviderSettlement,
    required this.outstandingStoreInstallments,
  });
}

/// مخزن گزارش‌ها — همه با SQL تجمعی، بدون بارگذاری کل جدول‌ها در حافظه (§53)
class ReportRepository {
  final StoreDatabase store;
  final LedgerRepository ledger;
  ReportRepository(this.store, this.ledger);

  int _oneInt(String sql, [List<Object?> args = const []]) {
    final rows = store.db.select(sql, args);
    if (rows.isEmpty) return 0;
    final v = rows.first.values.first;
    if (v == null) return 0;
    return v is int ? v : (v as num).round();
  }

  List<Map<String, Object?>> _rows(String sql, [List<Object?> args = const []]) =>
      store.db.select(sql, args);

  /// مبلغ امضادار: رویداد معکوس (reversal) با علامت منفی جمع می‌شود تا
  /// اثر اصلاحی رویداد اصلی خنثی شود (حسابداری تصحیحی)
  static const signedAmount = LedgerRepository.signedAmountExpr;

  int _sumLedger(Set<String> types, String from, String to) {
    return ledger.sumField(signedAmount, 'v', from: from, to: to, types: types);
  }

  /// جمع امضادار رویدادها برای گزارش‌های UI
  int sumLedgerSigned(Set<String> types, {String? from, String? to}) =>
      ledger.sumField(signedAmount, 'v', from: from, to: to, types: types);

  // ---------------------------------------------------------------
  // داشبورد (§3، §47)
  // ---------------------------------------------------------------

  DashboardSummary dashboard(String today) {
    final monthStart = '${today.substring(0, 7)}-01';
    final salesRow = _rows(
      "SELECT COALESCE(SUM(revenue), 0) AS sales, COUNT(*) AS cnt, "
      "COALESCE(SUM(CASE WHEN remaining = 0 THEN total ELSE 0 END), 0) AS cash_sales, "
      "COALESCE(SUM(remaining), 0) AS credit_sales "
      "FROM sales_documents WHERE doc_date = ? AND status = 'active' AND deleted_at IS NULL",
      [today],
    ).first;
    final installmentToday = _oneInt(
      "SELECT COALESCE(SUM(gross), 0) FROM installment_sales WHERE sale_date = ? AND status NOT IN ('CANCELLED','REFUNDED')",
      [today],
    );
    final receivables = _sumPositiveCustomerDeltas();
    final payables = _sumPositiveSupplierDeltas();
    final todayExpenses = _oneInt(
        'SELECT COALESCE(SUM(amount), 0) FROM expenses WHERE expense_date = ? AND voided_at IS NULL',
        [today]);
    final pl = profitAndLoss(monthStart, today);
    final lowStock = _oneInt(
        'SELECT COUNT(*) FROM product_stock WHERE current_qty <= min_qty AND product_id != \'\'');
    final dueTodayRow = _rows(
      "SELECT COUNT(*) AS c, COALESCE(SUM(i.amount - i.paid_amount), 0) AS amt "
      "FROM installments i JOIN installment_sales s ON s.id = i.sale_id "
      "WHERE i.due_date = ? AND i.paid_amount < i.amount AND i.status NOT IN ('CANCELLED','WAIVED') "
      "AND s.status NOT IN ('CANCELLED','REFUNDED')",
      [today],
    ).first;
    final overdueRow = _rows(
      "SELECT COUNT(*) AS c, COALESCE(SUM(i.amount - i.paid_amount), 0) AS amt "
      "FROM installments i JOIN installment_sales s ON s.id = i.sale_id "
      "WHERE i.due_date < ? AND i.paid_amount < i.amount AND i.status NOT IN ('CANCELLED','WAIVED') "
      "AND s.status NOT IN ('CANCELLED','REFUNDED')",
      [today],
    ).first;
    final expectedReceivables = _oneInt(
      "SELECT (SELECT COALESCE(SUM(sc.amount - sc.received_amount), 0) FROM settlement_schedule sc "
      "JOIN installment_sales s2 ON s2.id = sc.sale_id WHERE sc.status != 'CANCELLED' "
      "AND s2.status NOT IN ('CANCELLED','REFUNDED') AND sc.received_amount < sc.amount) "
      "+ (SELECT COALESCE(SUM(i.amount - i.paid_amount), 0) FROM installments i "
      "JOIN installment_sales s3 ON s3.id = i.sale_id JOIN installment_providers p3 ON p3.id = s3.provider_id "
      "WHERE p3.provider_type = 'store' AND s3.status NOT IN ('CANCELLED','REFUNDED') "
      "AND i.status NOT IN ('CANCELLED','WAIVED') AND i.paid_amount < i.amount)",
    );
    return DashboardSummary(
      todaySales: salesRow['sales'] as int,
      todayInvoiceCount: salesRow['cnt'] as int,
      todayCashSales: salesRow['cash_sales'] as int,
      todayCreditSales: salesRow['credit_sales'] as int,
      todayInstallmentSales: installmentToday,
      receivables: receivables,
      payables: payables,
      todayExpenses: todayExpenses,
      monthNetProfit: pl.netProfit,
      lowStockCount: lowStock,
      dueTodayCount: dueTodayRow['c'] as int,
      dueTodayAmount: dueTodayRow['amt'] as int,
      overdueCount: overdueRow['c'] as int,
      overdueAmount: overdueRow['amt'] as int,
      expectedReceivables: expectedReceivables,
      expectedPayments: payables,
    );
  }

  int _sumPositiveCustomerDeltas() => _oneInt(
      'SELECT COALESCE(SUM(v), 0) FROM (SELECT customer_id, SUM(customer_delta) AS v '
      'FROM ledger_events e WHERE ${LedgerRepository.effectiveFilter} AND customer_id IS NOT NULL '
      'GROUP BY customer_id HAVING v > 0)');

  int _sumPositiveSupplierDeltas() => _oneInt(
      'SELECT COALESCE(SUM(v), 0) FROM (SELECT supplier_id, SUM(supplier_delta) AS v '
      'FROM ledger_events e WHERE ${LedgerRepository.effectiveFilter} AND supplier_id IS NOT NULL '
      'GROUP BY supplier_id HAVING v > 0)');

  List<Map<String, Object?>> recentInvoices({int limit = 10}) => _rows(
      "SELECT source_id, number, customer_name, doc_date, revenue, total, paid, remaining, status "
      "FROM sales_documents WHERE deleted_at IS NULL ORDER BY updated_at DESC LIMIT ?",
      [limit]);

  List<LedgerEvent> recentTransactions({int limit = 15}) =>
      ledger.effectiveEvents(limit: limit);

  // ---------------------------------------------------------------
  // سود و زیان (§31) — درآمد/هزینه، نه جریان نقدی
  // ---------------------------------------------------------------

  ProfitAndLoss profitAndLoss(String from, String to) {
    // درآمد شناسایی‌شده: فروش نقدی/نسیه + دریافت‌های بسته‌بندی/ارسال +
    // فروش اقساطی (مبلغ تأمین‌شده) + بیعانهٔ نقدی فروش اقساطی (§15)
    final baseRevenue = _sumLedger(
        {LedgerEventType.sale,
          LedgerEventType.shippingCharge,
          LedgerEventType.packagingCharge,
          LedgerEventType.installmentCreated},
        from,
        to);
    final installmentDown = ledger.sumField(signedAmount, 'v',
        from: from,
        to: to,
        types: {LedgerEventType.paymentReceived},
        extraWhere: 'e.installment_id IS NOT NULL');
    final revenue = baseRevenue + installmentDown;
    final returns = _sumLedger({LedgerEventType.saleReturn}, from, to);
    final cogs = _oneInt(
        "SELECT COALESCE(SUM(cost), 0) FROM sales_documents WHERE doc_date >= ? AND doc_date <= ? AND status = 'active' AND deleted_at IS NULL",
        [from, to]);
    final commissions = _sumLedger({LedgerEventType.providerCommission}, from, to);
    final expenseRows = _rows(
      'SELECT c.title, COALESCE(SUM(e.amount), 0) AS total FROM expenses e '
      'JOIN expense_categories c ON c.id = e.category_id '
      'WHERE e.voided_at IS NULL AND e.expense_date >= ? AND e.expense_date <= ? '
      'GROUP BY c.id ORDER BY total DESC',
      [from, to],
    );
    final expensesByCategory = <String, int>{};
    var operatingExpenses = 0;
    for (final r in expenseRows) {
      final v = r['total'] as int;
      expensesByCategory[r['title'] as String] = v;
      operatingExpenses += v;
    }
    final grossProfit = revenue - returns - cogs;
    final netProfit = grossProfit - commissions - operatingExpenses;

    // وجوه واقعاً دریافت/پرداخت‌شده (جدا از سود) — انتقال/واریز/برداشت حساب نیست
    final cashInTypes = [
      LedgerEventType.paymentReceived,
      LedgerEventType.providerSettlement,
      LedgerEventType.installmentPaid,
      LedgerEventType.deposit,
    ];
    final cashOutTypes = [
      LedgerEventType.expense,
      LedgerEventType.shippingExpense,
      LedgerEventType.packagingExpense,
      LedgerEventType.refund,
      LedgerEventType.supplierPayment,
      LedgerEventType.purchasePayment,
      LedgerEventType.withdrawal,
    ];
    final cashReceived = _sumLedger(cashInTypes.toSet(), from, to);
    final cashPaidOut = _sumLedger(cashOutTypes.toSet(), from, to);

    final outstandingSettlement = _oneInt(
      "SELECT COALESCE(SUM(sc.amount - sc.received_amount), 0) "
      "FROM settlement_schedule sc JOIN installment_sales s ON s.id = sc.sale_id "
      "WHERE sc.status != 'CANCELLED' AND s.status NOT IN ('CANCELLED','REFUNDED') "
      "AND sc.received_amount < sc.amount",
    );
    final outstandingStore = _oneInt(
      "SELECT COALESCE(SUM(i.amount - i.paid_amount), 0) FROM installments i "
      "JOIN installment_sales s ON s.id = i.sale_id JOIN installment_providers p ON p.id = s.provider_id "
      "WHERE p.provider_type = 'store' AND s.status NOT IN ('CANCELLED','REFUNDED') AND i.status NOT IN ('CANCELLED','WAIVED') AND i.paid_amount < i.amount",
    );
    return ProfitAndLoss(
      revenue: revenue,
      returns: returns,
      netRevenue: revenue - returns,
      cogs: cogs,
      grossProfit: grossProfit,
      providerCommissions: commissions,
      operatingExpenses: operatingExpenses,
      expensesByCategory: expensesByCategory,
      netProfit: netProfit,
      cashReceived: cashReceived,
      cashPaidOut: cashPaidOut,
      outstandingProviderSettlement: outstandingSettlement,
      outstandingStoreInstallments: outstandingStore,
    );
  }

  // ---------------------------------------------------------------
  // گزارش فروش (§32)
  // ---------------------------------------------------------------

  List<Map<String, Object?>> salesReport(String from, String to,
      {String groupBy = 'day'}) {
    final expr = groupBy == 'month'
        ? 'substr(doc_date, 1, 7)'
        : "doc_date";
    return _rows(
      "SELECT $expr AS period, COUNT(*) AS cnt, COALESCE(SUM(revenue), 0) AS sales, "
      "COALESCE(SUM(paid), 0) AS cash_in, COALESCE(SUM(remaining), 0) AS credit, "
      "COALESCE(SUM(discount), 0) AS discounts, COALESCE(SUM(cost), 0) AS cogs, "
      "COALESCE(SUM(revenue - cost), 0) AS gross_profit "
      "FROM sales_documents WHERE doc_date >= ? AND doc_date <= ? AND status = 'active' AND deleted_at IS NULL "
      "GROUP BY period ORDER BY period DESC",
      [from, to],
    );
  }

  // ---------------------------------------------------------------
  // جریان نقدی واقعی (§37) — جدا از سود و زیان
  // ---------------------------------------------------------------

  Map<String, int> cashflow(String from, String to) {
    final opening = _oneInt(
      'SELECT COALESCE(SUM(opening_balance), 0) FROM financial_accounts') +
        _netFlows(null, from);
    final inflow = _oneInt(
        'SELECT COALESCE(SUM(amount), 0) FROM ledger_events e WHERE ${LedgerRepository.effectiveFilter} AND direction = 1 AND event_date >= ? AND event_date <= ?',
        [from, to]);
    final outflow = _oneInt(
        'SELECT COALESCE(SUM(amount), 0) FROM ledger_events e WHERE ${LedgerRepository.effectiveFilter} AND direction = -1 AND event_date >= ? AND event_date <= ?',
        [from, to]);
    return {
      'opening': opening,
      'incoming': inflow,
      'outgoing': outflow,
      'closing': opening + inflow - outflow,
    };
  }

  int _netFlows(String? fromExclusive, String toExclusive) {
    // جمع خالص جریان‌های حساب‌ها قبل از یک تاریخ (برای ماندهٔ آغازین)
    var net = 0;
    final rows = _rows(
      'SELECT direction, COALESCE(SUM(amount), 0) AS v FROM ledger_events e '
      'WHERE ${LedgerRepository.effectiveFilter} AND direction != 0 AND event_date < ? '
      'GROUP BY direction',
      [toExclusive],
    );
    for (final r in rows) {
      final v = r['v'] as int;
      net += (r['direction'] as int) == 1 ? v : -v;
    }
    return net;
  }

  // ---------------------------------------------------------------
  // پیش‌بینی جریان نقدی آینده (§17)
  // ---------------------------------------------------------------

  List<Map<String, Object?>> forecastRows(String from, String to) {
    final rows = <Map<String, Object?>>[];
    // اقساط تسویهٔ درگاه‌ها طبق برنامه (خالص پس از کارمزد، قسط‌به‌قسط)
    rows.addAll(_rows(
      "SELECT sc.expected_date AS d, 'تسویهٔ ' || p.name AS kind, "
      "(sc.amount - sc.received_amount) AS amount, "
      "s.customer_name, p.name AS provider_name "
      "FROM settlement_schedule sc "
      "JOIN installment_sales s ON s.id = sc.sale_id "
      "JOIN installment_providers p ON p.id = sc.provider_id "
      "WHERE p.provider_type != 'store' AND s.status NOT IN ('CANCELLED','REFUNDED') "
      "AND sc.status != 'CANCELLED' AND sc.received_amount < sc.amount "
      "AND sc.expected_date >= ? AND sc.expected_date <= ?",
      [from, to],
    ));
    // اقساط مستقیم فروشگاه (دریافت از مشتری)
    rows.addAll(_rows(
      "SELECT i.due_date AS d, 'قسط مستقیم فروشگاه' AS kind, (i.amount - i.paid_amount) AS amount, "
      "s.customer_name, p.name AS provider_name "
      "FROM installments i JOIN installment_sales s ON s.id = i.sale_id "
      "JOIN installment_providers p ON p.id = s.provider_id "
      "WHERE p.provider_type = 'store' AND s.status NOT IN ('CANCELLED','REFUNDED') "
      "AND i.status NOT IN ('CANCELLED','WAIVED') AND i.paid_amount < i.amount "
      "AND i.due_date >= ? AND i.due_date <= ?",
      [from, to],
    ));
    rows.sort((a, b) {
      final da = a['d'] as String? ?? '';
      final dbv = b['d'] as String? ?? '';
      return da.compareTo(dbv);
    });
    return rows;
  }

  Map<String, int> forecastTotals() {
    final providerOutstanding = _oneInt(
      "SELECT COALESCE(SUM(sc.amount - sc.received_amount), 0) "
      "FROM settlement_schedule sc JOIN installment_sales s ON s.id = sc.sale_id "
      "WHERE sc.status != 'CANCELLED' AND s.status NOT IN ('CANCELLED','REFUNDED') "
      "AND sc.received_amount < sc.amount",
    );
    final storeOutstanding = _oneInt(
      "SELECT COALESCE(SUM(i.amount - i.paid_amount), 0) FROM installments i "
      "JOIN installment_sales s ON s.id = i.sale_id JOIN installment_providers p ON p.id = s.provider_id "
      "WHERE p.provider_type = 'store' AND s.status NOT IN ('CANCELLED','REFUNDED') AND i.status NOT IN ('CANCELLED','WAIVED') AND i.paid_amount < i.amount",
    );
    final payables = _sumPositiveSupplierDeltas();
    return {
      'expectedIncoming': providerOutstanding + storeOutstanding,
      'expectedOutgoing': payables,
      'expectedNet': providerOutstanding + storeOutstanding - payables,
    };
  }

  // ---------------------------------------------------------------
  // گزارش سود کالا (§33)
  // ---------------------------------------------------------------

  List<Map<String, Object?>> productProfit(String from, String to) {
    return _rows(
      "SELECT si.product_id, si.title, SUM(si.quantity) AS units_sold, "
      "COALESCE(SUM(si.total_price), 0) AS revenue, COALESCE(SUM(si.unit_cost * si.quantity), 0) AS cost, "
      "COALESCE(SUM(si.total_price - si.unit_cost * si.quantity), 0) AS gross_profit, "
      "(SELECT COALESCE(SUM(-sm.quantity), 0) FROM stock_movements sm WHERE sm.product_id = si.product_id AND sm.movement_type = 'sale_return' AND sm.movement_date >= ? AND sm.movement_date <= ?) AS returned_units "
      "FROM sale_items si JOIN sales_documents sd ON sd.source_id = si.invoice_id "
      "WHERE si.product_id != '' AND sd.status = 'active' AND sd.deleted_at IS NULL "
      "AND si.doc_date >= ? AND si.doc_date <= ? "
      "GROUP BY si.product_id ORDER BY gross_profit DESC",
      [from, to, from, to],
    );
  }

  /// حاشیهٔ سود به درصد ×۱۰۰
  int marginBps(int revenue, int cost) {
    if (revenue <= 0) return 0;
    return ((revenue - cost) * 10000) ~/ revenue;
  }

  // ---------------------------------------------------------------
  // بدهکاران (§5)
  // ---------------------------------------------------------------

  List<Map<String, Object?>> debtors() {
    return _rows(
      'SELECT customer_id, SUM(customer_delta) AS debt, MAX(event_date) AS last_date '
      'FROM ledger_events e WHERE ${LedgerRepository.effectiveFilter} AND customer_id IS NOT NULL '
      'GROUP BY customer_id HAVING debt > 0 ORDER BY debt DESC',
    );
  }

  // ---------------------------------------------------------------
  // گزارش تأمین‌کنندگان (§35)
  // ---------------------------------------------------------------

  List<Map<String, Object?>> supplierReport() {
    return _rows(
      'SELECT sup.id, sup.name, '
      '(SELECT COALESCE(SUM(pi.total), 0) FROM purchase_invoices pi WHERE pi.supplier_id = sup.id AND pi.reversed_at IS NULL) AS purchases, '
      '(SELECT COALESCE(SUM(ps.amount), 0) FROM supplier_payments ps WHERE ps.supplier_id = sup.id AND ps.reversed_at IS NULL) AS payments, '
      'COALESCE((SELECT SUM(supplier_delta) FROM ledger_events e WHERE ${LedgerRepository.effectiveFilter} AND e.supplier_id = sup.id), 0) AS payable '
      'FROM suppliers sup ORDER BY payable DESC, sup.name',
    );
  }

  // ---------------------------------------------------------------
  // گزارش موجودی (§39)
  // ---------------------------------------------------------------

  List<Map<String, Object?>> inventoryReport() {
    return _rows(
      "SELECT ps.product_id, ps.current_qty, ps.min_qty, ps.avg_cost, "
      "(ps.current_qty * ps.avg_cost) AS stock_value, "
      "(SELECT COALESCE(SUM(-sm.quantity), 0) FROM stock_movements sm WHERE sm.product_id = ps.product_id AND sm.movement_type = 'sale') AS sold_total, "
      "(SELECT COALESCE(SUM(sm.quantity), 0) FROM stock_movements sm WHERE sm.product_id = ps.product_id AND sm.movement_type = 'purchase') AS purchased_total "
      "FROM product_stock ps WHERE ps.product_id != '' ORDER BY stock_value DESC",
    );
  }

  // ---------------------------------------------------------------
  // بستن روز (§38)
  // ---------------------------------------------------------------

  int expectedCashBalance() {
    final rows = _rows(
        "SELECT id FROM financial_accounts WHERE type IN ('cash','card')");
    var total = 0;
    for (final r in rows) {
      final id = r['id'] as String;
      final opening = _oneInt(
          'SELECT opening_balance FROM financial_accounts WHERE id = ?', [id]);
      final inflow = _oneInt(
          'SELECT COALESCE(SUM(amount), 0) FROM ledger_events e WHERE ${LedgerRepository.effectiveFilter} AND account_id = ? AND direction = 1',
          [id]);
      final outflow = _oneInt(
          'SELECT COALESCE(SUM(amount), 0) FROM ledger_events e WHERE ${LedgerRepository.effectiveFilter} AND account_id = ? AND direction = -1',
          [id]);
      total += opening + inflow - outflow;
    }
    return total;
  }

  int expectedBankBalance() {
    final rows = _rows(
        "SELECT id FROM financial_accounts WHERE type IN ('bank','other')");
    var total = 0;
    for (final r in rows) {
      final id = r['id'] as String;
      final opening = _oneInt(
          'SELECT opening_balance FROM financial_accounts WHERE id = ?', [id]);
      final inflow = _oneInt(
          'SELECT COALESCE(SUM(amount), 0) FROM ledger_events e WHERE ${LedgerRepository.effectiveFilter} AND account_id = ? AND direction = 1',
          [id]);
      final outflow = _oneInt(
          'SELECT COALESCE(SUM(amount), 0) FROM ledger_events e WHERE ${LedgerRepository.effectiveFilter} AND account_id = ? AND direction = -1',
          [id]);
      total += opening + inflow - outflow;
    }
    return total;
  }

  void saveDailyClosing({
    required String date,
    required int actualCash,
    required int actualBank,
    String notes = '',
  }) {
    store.db.execute(
      'INSERT INTO daily_closings (id, closing_date, expected_cash, actual_cash, expected_bank, actual_bank, notes, created_at) '
      'VALUES (?,?,?,?,?,?,?,?) '
      'ON CONFLICT(closing_date) DO UPDATE SET actual_cash = excluded.actual_cash, actual_bank = excluded.actual_bank, notes = excluded.notes, expected_cash = excluded.expected_cash, expected_bank = excluded.expected_bank',
      [
        'dc-$date',
        date,
        expectedCashBalance(),
        actualCash,
        expectedBankBalance(),
        actualBank,
        notes,
        DateTime.now().toIso8601String(),
      ],
    );
  }

  List<Map<String, Object?>> closingHistory({int limit = 60}) => _rows(
      'SELECT * FROM daily_closings ORDER BY closing_date DESC LIMIT ?', [limit]);

  // ---------------------------------------------------------------
  // موتور تطبیق (§51) — برای تست و ساخت دیتای دیباگ
  // ---------------------------------------------------------------

  List<Map<String, Object>> reconciliationChecks() {
    final checks = <Map<String, Object>>[];

    // ۱) جمع برنامهٔ اقساط == مبلغ تأمین‌شدهٔ هر فروش فعال
    final badSchedules = _rows(
      "SELECT s.id, s.financed, COALESCE(SUM(i.amount), 0) AS scheduled "
      "FROM installment_sales s LEFT JOIN installments i ON i.sale_id = s.id AND i.status NOT IN ('CANCELLED','WAIVED') "
      "WHERE s.status NOT IN ('CANCELLED','REFUNDED') GROUP BY s.id "
      "HAVING scheduled != s.financed",
    );
    checks.add({
      'name': 'جمع اقساط = مبلغ تأمین‌شده',
      'ok': badSchedules.isEmpty,
      'detail': badSchedules.isEmpty ? '' : '${badSchedules.length} فروش ناسازگار',
    });

    // ۲) کارمزد + مالیات + کسور + خالص تسویه = مبلغ تأمین‌شده
    final badCommissions = _rows(
      "SELECT id FROM installment_sales "
      "WHERE (commission + commission_vat + other_deductions + net_settlement) != financed",
    );
    checks.add({
      'name': 'کارمزد + کسور + تسویهٔ خالص = مبلغ تأمین',
      'ok': badCommissions.isEmpty,
      'detail': badCommissions.isEmpty ? '' : '${badCommissions.length} فروش ناسازگار',
    });

    // ۳) تسویهٔ ثبت‌شده ≤ تسویهٔ مورد انتظار
    final badSettlements = _rows(
      "SELECT ps.sale_id, SUM(ps.amount) AS total_settled, s.net_settlement "
      "FROM provider_settlements ps JOIN installment_sales s ON s.id = ps.sale_id "
      "WHERE ps.reversed_at IS NULL GROUP BY ps.sale_id HAVING total_settled > s.net_settlement",
    );
    checks.add({
      'name': 'تسویه ≤ مورد انتظار',
      'ok': badSettlements.isEmpty,
      'detail': badSettlements.isEmpty ? '' : '${badSettlements.length} فروش ناسازگار',
    });

    // ۳.۵) جمع برنامهٔ تسویهٔ درگاه = خالص تسویه (کارمزد اول کسر و باقیمانده تقسیم شده)
    final badSchedules3 = _rows(
      "SELECT s.id FROM installment_sales s "
      "LEFT JOIN settlement_schedule sc ON sc.sale_id = s.id AND sc.status != 'CANCELLED' "
      "WHERE s.status NOT IN ('CANCELLED','REFUNDED') "
      "AND (SELECT EXISTS(SELECT 1 FROM installment_providers p WHERE p.id = s.provider_id AND p.provider_type != 'store')) "
      "GROUP BY s.id HAVING COALESCE(SUM(sc.amount), 0) != s.net_settlement",
    );
    checks.add({
      'name': 'جمع برنامهٔ تسویه = خالص پس از کارمزد',
      'ok': badSchedules3.isEmpty,
      'detail': badSchedules3.isEmpty ? '' : '${badSchedules3.length} فروش ناسازگار',
    });

    // ۴) ماندهٔ مشتری هرگز منفی نیست
    final negativeCustomers = _rows(
      'SELECT customer_id, SUM(customer_delta) AS v FROM ledger_events e '
      'WHERE ${LedgerRepository.effectiveFilter} AND customer_id IS NOT NULL GROUP BY customer_id HAVING v < 0',
    );
    checks.add({
      'name': 'ماندهٔ مشتری غیرمنفی',
      'ok': negativeCustomers.isEmpty,
      'detail': negativeCustomers.isEmpty ? '' : '${negativeCustomers.length} مشتری',
    });

    // ۵) بدهی تأمین‌کننده منفی نیست
    final negativeSuppliers = _rows(
      'SELECT supplier_id, SUM(supplier_delta) AS v FROM ledger_events e '
      'WHERE ${LedgerRepository.effectiveFilter} AND supplier_id IS NOT NULL GROUP BY supplier_id HAVING v < 0',
    );
    checks.add({
      'name': 'بدهی تأمین‌کننده غیرمنفی',
      'ok': negativeSuppliers.isEmpty,
      'detail': negativeSuppliers.isEmpty ? '' : '${negativeSuppliers.length} تأمین‌کننده',
    });

    // ۶) موجودی هیچ کالایی منفی نیست
    final negativeStock = _rows(
        'SELECT product_id FROM product_stock WHERE current_qty < 0');
    checks.add({
      'name': 'موجودی غیرمنفی',
      'ok': negativeStock.isEmpty,
      'detail': negativeStock.isEmpty ? '' : '${negativeStock.length} کالا',
    });

    // ۷) موجودی مشتق = جمع حرکت‌ها
    final stockMismatch = _rows(
      'SELECT ps.product_id, ps.current_qty, COALESCE((SELECT SUM(quantity) FROM stock_movements sm WHERE sm.product_id = ps.product_id), 0) AS derived '
      'FROM product_stock ps WHERE ps.current_qty != derived',
    );
    checks.add({
      'name': 'موجودی = جمع حرکت‌های موجودی',
      'ok': stockMismatch.isEmpty,
      'detail': stockMismatch.isEmpty ? '' : '${stockMismatch.length} کالا',
    });

    return checks;
  }
}
