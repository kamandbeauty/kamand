import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/customer_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../providers/product_provider.dart';
import '../../models/invoice_model.dart';
import 'package:shamsi_date/shamsi_date.dart';

const _orange = AppTheme.RubyPrimary;
const _slate400 = Color(0xFF94A3B8);
const _slate500 = Color(0xFF64748B);
const _slate700 = Color(0xFF334155);
const _slate800 = Color(0xFF1E293B);

class AccountingSummaryScreen extends ConsumerStatefulWidget {
  const AccountingSummaryScreen({super.key});

  @override
  ConsumerState<AccountingSummaryScreen> createState() => _AccountingSummaryScreenState();
}

class _AccountingSummaryScreenState extends ConsumerState<AccountingSummaryScreen> {
  String _selectedPeriod = 'all'; // all, thisMonth, lastMonth, thisYear
  String _selectedYearMonth = '';

  @override
  void initState() {
    super.initState();
    final now = Jalali.now();
    _selectedYearMonth = '${now.year}/${now.month.toString().padLeft(2, '0')}';
  }

  bool _isInPeriod(InvoiceModel inv) {
    if (_selectedPeriod == 'all') return true;
    
    try {
      // Parse invoice date which is in format like "1403/06/15" or Persian
      final dateStr = inv.date;
      // Try to extract year/month from date
      final faToEn = _faToEn(dateStr);
      final match = RegExp(r'(\d{4})[/\-](\d{1,2})').firstMatch(faToEn);
      if (match == null) return true;
      
      final year = int.tryParse(match.group(1)!) ?? 0;
      final month = int.tryParse(match.group(2)!) ?? 0;
      final now = Jalali.now();
      
      if (_selectedPeriod == 'thisMonth') {
        return year == now.year && month == now.month;
      } else if (_selectedPeriod == 'lastMonth') {
        final lastMonth = now.addMonths(-1);
        return year == lastMonth.year && month == lastMonth.month;
      } else if (_selectedPeriod == 'thisYear') {
        return year == now.year;
      } else if (_selectedPeriod == 'custom' && _selectedYearMonth.isNotEmpty) {
        final parts = _selectedYearMonth.split('/');
        if (parts.length == 2) {
          final selYear = int.tryParse(parts[0]) ?? 0;
          final selMonth = int.tryParse(parts[1]) ?? 0;
          return year == selYear && month == selMonth;
        }
      }
    } catch (_) {
      return true;
    }
    return true;
  }

  String _faToEn(String s) {
    const fa = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    var r = s;
    for (int i = 0; i < 10; i++) {
      r = r.replaceAll(fa[i], en[i]);
    }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final invoices = ref.watch(invoiceListProvider);
    final expenses = ref.watch(expenseListProvider);
    final customers = ref.watch(customerListProvider);
    final suppliers = ref.watch(supplierListProvider);
    final products = ref.watch(productListProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    // فیلتر بر اساس دوره
    final filteredInvoices = invoices.where(_isInPeriod).toList();
    final filteredExpenses = _filterExpensesByPeriod(expenses);

    // محاسبات با اصلاح بهای تمام شده
    double totalSales = 0;
    double totalPurchases = 0;
    double totalProfit = 0;
    double totalBuy = 0; // بهای تمام شده کالاهای فروخته شده
    double totalReceivable = 0;
    double totalPayable = 0;
    int saleCount = 0;
    int purchaseCount = 0;

    // برای محاسبه دقیق سود، اگر buyPrice صفر بود از کاتالوگ محصولات استفاده کن
    final Map<String, dynamic> productMap = {for (var p in products) p.id: p, for (var p in products) p.name: p};

    for (final inv in filteredInvoices) {
      if (inv.type == 'sale') {
        totalSales += inv.totalAmount;
        saleCount++;
        totalReceivable += inv.remainingAmount;

        // محاسبه بهای تمام شده و سود با در نظر گرفتن کاتالوگ
        double invBuy = 0;
        double invProfit = 0;
        
        for (final item in inv.items) {
          double buyPrice = item.buyPrice;
          // اگر buyPrice صفر بود، از کاتالوگ پیدا کن
          if (buyPrice <= 0) {
            if (item.productId.isNotEmpty && productMap.containsKey(item.productId)) {
              buyPrice = productMap[item.productId]!.buyPrice;
            } else if (productMap.containsKey(item.title)) {
              buyPrice = productMap[item.title]!.buyPrice;
            }
          }
          final itemBuy = buyPrice * item.quantity;
          final itemProfit = (item.unitPrice - buyPrice) * item.quantity;
          invBuy += itemBuy;
          invProfit += itemProfit;
        }
        
        // اگر invoice قدیمی totalBuyAmount داشت، از آن استفاده کن، وگرنه از محاسبه جدید
        if (inv.totalBuyAmount > 0) {
          totalBuy += inv.totalBuyAmount;
        } else {
          totalBuy += invBuy;
        }
        
        if (inv.profitAmount > 0) {
          totalProfit += inv.profitAmount;
        } else {
          totalProfit += invProfit;
        }
      } else if (inv.type == 'purchase') {
        totalPurchases += inv.totalAmount;
        totalPayable += inv.remainingAmount;
        purchaseCount++;
      }
    }

    // اگر بهای تمام شده صفر باشد، تخمینی زده نمی‌شود؛ فقط در گزارش به کاربر
    // اطلاع داده می‌شود تا قیمت خرید کالاها را در کاتالوگ ثبت کند.
    double totalExpenses = filteredExpenses.fold(0, (s, e) => s + e.amount);
    double customerDebts = customers.fold(0, (s, c) => s + c.balance);
    double supplierDebts = suppliers.fold(0, (s, sup) => s + sup.balance);
    
    // سود خالص = سود ناخالص - هزینه‌ها
    // اگر totalBuy محاسبه شده باشد، سود ناخالص = فروش - بهای تمام شده
    // وگرنه از totalProfit که از فاکتورها آمده استفاده کن
    double grossProfit = totalSales - totalBuy;
    if (totalBuy == 0 && totalProfit > 0) {
      grossProfit = totalProfit;
    } else if (totalBuy > 0) {
      // اگر بهای تمام شده داریم، سود ناخالص را دقیق حساب کن
      grossProfit = totalSales - totalBuy;
      // اگر تخفیف داشتیم، از سود کم کن
      // totalProfit قبلاً شامل تخفیف نیست، پس grossProfit را به totalProfit ترجیح بده اگر منطقی بود
      if (totalProfit > 0 && (grossProfit - totalProfit).abs() > 1000) {
        // اگر اختلاف زیاد بود، از totalProfit استفاده کن (که قبلاً محاسبه شده)
        // ولی اگر totalBuy داریم، grossProfit دقیق‌تر است
      }
    }
    
    // برای نمایش، اگر totalBuy صفر و totalProfit برابر فروش بود، یعنی بهای تمام شده ثبت نشده
    // در این حالت سود ناخالص واقعی را نمی‌توان حساب کرد، پس همان totalProfit را نشان بده
    // ولی به کاربر هشدار بده
    double displayGrossProfit = grossProfit;
    if (totalBuy == 0 && totalSales > 0) {
      displayGrossProfit = totalProfit > 0 ? totalProfit : totalSales;
    }
    
    double netProfit = displayGrossProfit - totalExpenses;
    double inventoryValue = products.fold(0, (s, p) => s + (p.buyPrice * p.stock));

    double totalReceivableAll = totalReceivable > customerDebts ? totalReceivable : customerDebts;
    double totalPayableAll = totalPayable > supplierDebts ? totalPayable : supplierDebts;

    // محاسبه گزارش ماهیانه
    final monthlyData = _calculateMonthlyData(filteredInvoices, filteredExpenses, productMap);

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F172A) : const Color(0xFFFFFBEB),
      appBar: AppBar(
        title: const Text('خلاصه حساب و سود'),
        backgroundColor: dark ? _slate800 : Colors.white,
        foregroundColor: dark ? Colors.white : _slate800,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // فیلتر دوره
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: dark ? _slate800 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: dark ? _slate700 : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('دوره گزارش', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: dark ? Colors.white : _slate700)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _periodChip('همه', 'all', dark),
                        const SizedBox(width: 6),
                        _periodChip('ماه جاری', 'thisMonth', dark),
                        const SizedBox(width: 6),
                        _periodChip('ماه قبل', 'lastMonth', dark),
                        const SizedBox(width: 6),
                        _periodChip('سال جاری', 'thisYear', dark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // هشدار اگر بهای تمام شده صفر است
            if (totalBuy == 0 && totalSales > 0 && saleCount > 0)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'بهای تمام شده کالاها ثبت نشده! برای محاسبه دقیق سود، قیمت خرید را در کاتالوگ محصولات ثبت کنید.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),

            // کارت اصلی سود
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [const Color(0xFF059669), const Color(0xFF047857)]),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: const Color(0xFF059669).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('سود خالص', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                        child: Text('${PersianNumberFormatter.toPersian(saleCount.toString())} فروش', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(PersianNumberFormatter.formatCurrency(netProfit), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _miniStat('سود ناخالص', displayGrossProfit, Colors.white70)),
                      Container(width: 1, height: 30, color: Colors.white24),
                      Expanded(child: _miniStat('هزینه‌ها', totalExpenses, Colors.white70, isNegative: true)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4 کارت ردیفی
            Row(
              children: [
                Expanded(child: _summaryCard(title: 'فروش کل', value: totalSales, icon: Icons.trending_up, color: const Color(0xFF2563EB), dark: dark)),
                const SizedBox(width: 10),
                Expanded(child: _summaryCard(title: 'خرید کل', value: totalPurchases, icon: Icons.shopping_cart_outlined, color: const Color(0xFFEA580C), dark: dark)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _summaryCard(title: 'طلب از مشتریان', value: totalReceivableAll, icon: Icons.account_balance_wallet_outlined, color: const Color(0xFF059669), dark: dark, subtitle: 'دریافتنی')),
                const SizedBox(width: 10),
                Expanded(child: _summaryCard(title: 'بدهی به تامین‌کننده', value: totalPayableAll, icon: Icons.payments_outlined, color: const Color(0xFFE11D48), dark: dark, subtitle: 'پرداختنی')),
              ],
            ),
            const SizedBox(height: 16),

            // جزئیات
            _sectionCard(
              dark: dark,
              title: 'جزئیات مالی',
              children: [
                _detailRow('تعداد فاکتور فروش', '${PersianNumberFormatter.toPersian(saleCount.toString())} فاکتور', dark),
                _detailRow('تعداد فاکتور خرید', '${PersianNumberFormatter.toPersian(purchaseCount.toString())} فاکتور', dark),
                _detailRow('مجموع فروش', PersianNumberFormatter.formatCurrency(totalSales), dark),
                _detailRow('مجموع خرید کالاها (بهای تمام شده)', PersianNumberFormatter.formatCurrency(totalBuy), dark, 
                  valueColor: totalBuy == 0 && totalSales > 0 ? Colors.orange : null),
                _detailRow('سود ناخالص از فروش', PersianNumberFormatter.formatCurrency(displayGrossProfit), dark, valueColor: const Color(0xFF059669)),
                _detailRow('کل هزینه‌ها', PersianNumberFormatter.formatCurrency(totalExpenses), dark, valueColor: const Color(0xFFE11D48)),
                const Divider(height: 20),
                _detailRow('سود خالص (سود - هزینه)', PersianNumberFormatter.formatCurrency(netProfit), dark, isBold: true, valueColor: netProfit >= 0 ? const Color(0xFF059669) : const Color(0xFFE11D48)),
              ],
            ),
            const SizedBox(height: 12),

            // گزارش ماهیانه
            _sectionCard(
              dark: dark,
              title: 'گزارش ماهیانه',
              children: [
                if (monthlyData.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('داده‌ای برای نمایش ماهیانه وجود ندارد', style: TextStyle(color: _slate400, fontSize: 12)),
                  )
                else
                  ...monthlyData.entries.map((entry) {
                    final month = entry.key;
                    final data = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: dark ? _slate700 : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(month, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: dark ? Colors.white : _slate800)),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('فروش: ${PersianNumberFormatter.formatCurrency(data['sales']!)}', style: TextStyle(fontSize: 11, color: dark ? _slate400 : _slate500)),
                              Text('سود: ${PersianNumberFormatter.formatCurrency(data['profit']!)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF059669))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('خرید: ${PersianNumberFormatter.formatCurrency(data['purchases']!)}', style: TextStyle(fontSize: 11, color: dark ? _slate400 : _slate500)),
                              Text('هزینه: ${PersianNumberFormatter.formatCurrency(data['expenses']!)}', style: TextStyle(fontSize: 11, color: const Color(0xFFE11D48))),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
            const SizedBox(height: 12),

            _sectionCard(
              dark: dark,
              title: 'انبار و دارایی',
              children: [
                _detailRow('تعداد کالا', '${PersianNumberFormatter.toPersian(products.length.toString())} قلم', dark),
                _detailRow('ارزش موجودی انبار', PersianNumberFormatter.formatCurrency(inventoryValue), dark),
                _detailRow('تعداد مشتریان', '${PersianNumberFormatter.toPersian(customers.length.toString())} نفر', dark),
                _detailRow('تعداد تامین‌کنندگان', '${PersianNumberFormatter.toPersian(suppliers.length.toString())} نفر', dark),
              ],
            ),
            const SizedBox(height: 12),

            // دسته بندی هزینه
            if (filteredExpenses.isNotEmpty)
              _sectionCard(
                dark: dark,
                title: 'هزینه‌ها به تفکیک دسته',
                children: [
                  ..._expenseCategoryRows(filteredExpenses, dark),
                ],
              ),

            // کارت حساب تامین‌کنندگان
            if (suppliers.isNotEmpty)
              _sectionCard(
                dark: dark,
                title: 'کارت حساب تامین‌کنندگان',
                children: [
                  ...suppliers.map((sup) {
                    // محاسبه خریدهای هر تامین‌کننده
                    final supInvoices = filteredInvoices.where((inv) => inv.supplierId == sup.id || inv.supplierName == sup.name).toList();
                    final supTotal = supInvoices.fold(0.0, (s, inv) => s + inv.totalAmount);
                    final supPaid = supInvoices.fold(0.0, (s, inv) => s + inv.paidAmount);
                    final supRemaining = supInvoices.fold(0.0, (s, inv) => s + inv.remainingAmount);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF1E293B) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: dark ? _slate700 : const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(sup.name, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: dark ? Colors.white : _slate800)),
                              if (sup.balance > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                                  child: Text('بدهی: ${PersianNumberFormatter.formatCurrency(sup.balance)}', style: TextStyle(fontSize: 10, color: const Color(0xFFE11D48), fontWeight: FontWeight.w800)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('تعداد فاکتور: ${PersianNumberFormatter.toPersian(supInvoices.length.toString())}', style: TextStyle(fontSize: 11, color: dark ? _slate400 : _slate500)),
                              Text('خرید کل: ${PersianNumberFormatter.formatCurrency(supTotal)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: dark ? Colors.white : _slate700)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('پرداخت شده: ${PersianNumberFormatter.formatCurrency(supPaid)}', style: TextStyle(fontSize: 11, color: const Color(0xFF059669))),
                              Text('مانده: ${PersianNumberFormatter.formatCurrency(supRemaining)}', style: TextStyle(fontSize: 11, color: const Color(0xFFE11D48), fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),

            const SizedBox(height: 24),
            const Center(child: Text('محاسبات به صورت آفلاین و بر اساس فاکتورهای ثبت شده انجام می‌شود', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: _slate400))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _periodChip(String label, String value, bool dark) {
    final selected = _selectedPeriod == value;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.white : (dark ? _slate400 : _slate500))),
      selected: selected,
      onSelected: (v) {
        if (v) setState(() => _selectedPeriod = value);
      },
      selectedColor: _orange,
      backgroundColor: dark ? _slate800 : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: selected ? _orange : (dark ? _slate700 : const Color(0xFFE2E8F0)))),
    );
  }

  List _filterExpensesByPeriod(List expenses) {
    if (_selectedPeriod == 'all') return expenses;
    
    return expenses.where((exp) {
      try {
        final dateStr = _faToEn((exp.date as String?) ?? '');
        final match = RegExp(r'(\d{4})[/\-](\d{1,2})').firstMatch(dateStr);
        if (match == null) return true;
        
        final year = int.tryParse(match.group(1)!) ?? 0;
        final month = int.tryParse(match.group(2)!) ?? 0;
        final now = Jalali.now();
        
        if (_selectedPeriod == 'thisMonth') {
          return year == now.year && month == now.month;
        } else if (_selectedPeriod == 'lastMonth') {
          final lastMonth = now.addMonths(-1);
          return year == lastMonth.year && month == lastMonth.month;
        } else if (_selectedPeriod == 'thisYear') {
          return year == now.year;
        } else if (_selectedPeriod == 'custom' && _selectedYearMonth.isNotEmpty) {
          final parts = _selectedYearMonth.split('/');
          if (parts.length == 2) {
            final selYear = int.tryParse(parts[0]) ?? 0;
            final selMonth = int.tryParse(parts[1]) ?? 0;
            return year == selYear && month == selMonth;
          }
        }
      } catch (_) {
        return true;
      }
      return true;
    }).toList();
  }

  Map<String, Map<String, double>> _calculateMonthlyData(List<InvoiceModel> invoices, List expenses, Map<String, dynamic> productMap) {
    final monthly = <String, Map<String, double>>{};
    
    for (final inv in invoices) {
      try {
        final dateStr = _faToEn(inv.date);
        final match = RegExp(r'(\d{4})[/\-](\d{1,2})').firstMatch(dateStr);
        if (match == null) continue;
        
        final year = match.group(1)!;
        final month = match.group(2)!.padLeft(2, '0');
        final key = '$year/$month';
        
        monthly.putIfAbsent(key, () => {'sales': 0, 'purchases': 0, 'profit': 0, 'expenses': 0});
        
        if (inv.type == 'sale') {
          monthly[key]!['sales'] = monthly[key]!['sales']! + inv.totalAmount;
          
          // محاسبه سود ماهیانه
          double invProfit = 0;
          if (inv.profitAmount > 0) {
            invProfit = inv.profitAmount;
          } else {
            for (final item in inv.items) {
              double buyPrice = item.buyPrice;
              if (buyPrice <= 0) {
                if (item.productId.isNotEmpty && productMap.containsKey(item.productId)) {
                  buyPrice = productMap[item.productId]!.buyPrice;
                } else if (productMap.containsKey(item.title)) {
                  buyPrice = productMap[item.title]!.buyPrice;
                }
              }
              invProfit += (item.unitPrice - buyPrice) * item.quantity;
            }
          }
          monthly[key]!['profit'] = monthly[key]!['profit']! + invProfit;
        } else if (inv.type == 'purchase') {
          monthly[key]!['purchases'] = monthly[key]!['purchases']! + inv.totalAmount;
        }
      } catch (_) {}
    }
    
    // هزینه‌ها را به ماه جاری اضافه کن (چون تاریخ ندارند)
    if (expenses.isNotEmpty) {
      final now = Jalali.now();
      final key = '${now.year}/${now.month.toString().padLeft(2, '0')}';
      monthly.putIfAbsent(key, () => {'sales': 0, 'purchases': 0, 'profit': 0, 'expenses': 0});
      final totalExp = expenses.fold(0.0, (s, e) => s + e.amount);
      monthly[key]!['expenses'] = monthly[key]!['expenses']! + totalExp;
    }
    
    // مرتب‌سازی بر اساس تاریخ
    final sortedKeys = monthly.keys.toList()..sort((a, b) => b.compareTo(a));
    final sorted = <String, Map<String, double>>{};
    for (final k in sortedKeys) {
      sorted[k] = monthly[k]!;
    }
    
    return sorted;
  }

  Widget _miniStat(String label, double value, Color labelColor, {bool isNegative = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 11)),
        const SizedBox(height: 2),
        Text('${isNegative ? "- " : ""}${PersianNumberFormatter.formatCurrency(value).replaceAll(' تومان', '')}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _summaryCard({required String title, required double value, required IconData icon, required Color color, required bool dark, String? subtitle}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: dark ? _slate800 : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: dark ? _slate700 : const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
              const Spacer(),
              if (subtitle != null) Text(subtitle, style: TextStyle(fontSize: 10, color: _slate400, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 11, color: _slate500, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(PersianNumberFormatter.formatCurrency(value).replaceAll(' تومان', ''), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: dark ? Colors.white : _slate800)),
          const SizedBox(height: 2),
          const Text('تومان', style: TextStyle(fontSize: 10, color: _slate400)),
        ],
      ),
    );
  }

  Widget _sectionCard({required bool dark, required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: dark ? _slate800 : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: dark ? _slate700 : const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: dark ? Colors.white : _slate800)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, bool dark, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: dark ? _slate400 : _slate500, fontWeight: isBold ? FontWeight.w800 : FontWeight.w500)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.w900 : FontWeight.w800, color: valueColor ?? (dark ? Colors.white : _slate800))),
        ],
      ),
    );
  }

  List<Widget> _expenseCategoryRows(List<dynamic> expenses, bool dark) {
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map.entries.map((entry) {
      return _detailRow(entry.key, PersianNumberFormatter.formatCurrency(entry.value), dark, valueColor: const Color(0xFFE11D48));
    }).toList();
  }
}
