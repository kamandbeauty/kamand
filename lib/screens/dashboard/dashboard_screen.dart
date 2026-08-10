import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/jalali_helper.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../models/invoice_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/customer_provider.dart';
import '../invoice/invoice_create_screen.dart';
import '../customer/customer_list_screen.dart';
import '../product/product_list_screen.dart';
import '../financial/financial_dashboard_screen.dart';
import '../settings/settings_screen.dart';

/// Palette matching the web preview design language.
const _blue = Color(0xFF2563EB);
const _blueSoft = Color(0xFFEFF6FF);
const _emerald = Color(0xFF059669);
const _emeraldSoft = Color(0xFFECFDF5);
const _rose = Color(0xFFE11D48);
const _roseSoft = Color(0xFFFFF1F2);
const _amber = Color(0xFFD97706);
const _amberSoft = Color(0xFFFFFBEB);
const _indigo = Color(0xFF4F46E5);
const _indigoSoft = Color(0xFFEEF2FF);
const _purple = Color(0xFF7C3AED);
const _purpleSoft = Color(0xFFF5F3FF);
const _slate100 = Color(0xFFF1F5F9);
const _slate200 = Color(0xFFE2E8F0);
const _slate400 = Color(0xFF94A3B8);
const _slate600 = Color(0xFF475569);
const _slate700 = Color(0xFF334155);
const _slate800 = Color(0xFF1E293B);

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color get _cardColor => _dark ? _slate800 : Colors.white;
  Color get _cardBorder => _dark ? _slate700 : _slate200;
  Color get _titleColor => _dark ? Colors.white : _slate800;
  Color get _subtitleColor => _slate400;
  Color get _chipBg => _dark ? _slate700 : _slate100;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final business = ref.watch(businessProvider);
    final invoices = ref.watch(invoiceListProvider);
    final customers = ref.watch(customerListProvider);

    // Stats calculations
    final todayStr = JalaliHelper.getTodayJalali();
    final todayInvoices = invoices.where((inv) => inv.date == todayStr && inv.type == 'sale');
    final todaySales = todayInvoices.fold<double>(0, (sum, item) => sum + item.totalAmount);
    final todayReceived = todayInvoices.fold<double>(0, (sum, item) => sum + item.paidAmount);
    final customerDebt = customers.fold<double>(0, (sum, item) => sum + item.balance);
    final recentInvoices = invoices.reversed.take(6).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'ف',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            const SizedBox(width: 8),
            Text(business.shopName.isNotEmpty ? business.shopName : 'فاکتور روبی'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      drawer: _buildDrawer(user),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ================= Stats 2x2 Grid =================
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                _StatCard(
                  title: 'فروش امروز',
                  value: PersianNumberFormatter.formatCurrency(todaySales),
                  icon: Icons.trending_up,
                  chipColor: _blue,
                  chipBg: _dark ? const Color(0xFF1E3A5F) : _blueSoft,
                  caption: 'ثبت شده در امروز',
                  captionColor: _subtitleColor,
                ),
                _StatCard(
                  title: 'دریافت امروز',
                  value: PersianNumberFormatter.formatCurrency(todayReceived),
                  icon: Icons.credit_card,
                  chipColor: _emerald,
                  chipBg: _dark ? const Color(0xFF123B2D) : _emeraldSoft,
                  caption: 'نقدی و واریزی دریافتی',
                  captionColor: _emerald,
                  valueColor: _dark ? Colors.white : _slate800,
                ),
                _StatCard(
                  title: 'بدهی مشتریان',
                  value: PersianNumberFormatter.formatCurrency(customerDebt),
                  icon: Icons.warning_amber,
                  chipColor: _rose,
                  chipBg: _dark ? const Color(0xFF3B1220) : _roseSoft,
                  caption: 'مجموع طلبی از مشتریان',
                  captionColor: _subtitleColor,
                  valueColor: _rose,
                  onCaptionTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen()));
                  },
                ),
                _StatCard(
                  title: 'تعداد فاکتورها',
                  value: '${PersianNumberFormatter.toPersian(invoices.length)} فقره',
                  icon: Icons.description,
                  chipColor: _indigo,
                  chipBg: _dark ? const Color(0xFF252A4A) : _indigoSoft,
                  caption: 'شامل فروش، خرید و پیش‌فاکتور',
                  captionColor: _subtitleColor,
                  valueColor: _dark ? Colors.white : _slate800,
                  valueFontSize: 18,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ================= Quick Actions =================
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _QuickActionButton(
                    label: 'فاکتور جدید',
                    icon: Icons.add,
                    filled: true,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceCreateScreen()));
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: _QuickActionButton(
                    label: 'مشتری جدید',
                    icon: Icons.person_add,
                    chipColor: _emerald,
                    chipBg: _dark ? const Color(0xFF123B2D) : _emeraldSoft,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen()));
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: _QuickActionButton(
                    label: 'کالا جدید',
                    icon: Icons.inventory_2,
                    chipColor: _purple,
                    chipBg: _dark ? const Color(0xFF2E2340) : _purpleSoft,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListScreen()));
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ================= Recent Invoices =================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt_long, size: 20, color: _dark ? const Color(0xFF93C5FD) : _blue),
                          const SizedBox(width: 8),
                          Text(
                            'آخرین فاکتورها',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _titleColor),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: _showAllInvoices,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          child: Row(
                            children: [
                              Text(
                                'مشاهده همه',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _dark ? const Color(0xFF93C5FD) : _blue,
                                ),
                              ),
                              const Icon(Icons.chevron_left, size: 16, color: _blue),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Divider(color: _cardBorder, height: 20),

                  if (recentInvoices.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'هنوز فاکتوری ثبت نشده است.\nبا دکمه بالا اولین فاکتور خود را ایجاد کنید.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: _subtitleColor, height: 1.8),
                        ),
                      ),
                    )
                  else
                    ...recentInvoices.map((inv) => _InvoiceRow(inv: inv, dark: _dark)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(user) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text('${user.country} - ${user.city}'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                user.name.isNotEmpty ? user.name[0] : 'ف',
                style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w900, fontSize: 24),
              ),
            ),
            decoration: const BoxDecoration(color: AppTheme.primaryBlue),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('داشبورد اصلی'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('مدیریت فاکتورها'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceCreateScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('مشتریان و بدهی‌ها'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2),
            title: const Text('کالاها و خدمات'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet),
            title: const Text('گزارشات مالی'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialDashboardScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('تنظیمات'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
    );
  }

  void _showAllInvoices() {
    final invoices = ref.read(invoiceListProvider);
    final dark = _dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: dark ? _slate800 : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: dark ? _slate700 : _slate200,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.receipt_long, size: 20, color: dark ? const Color(0xFF93C5FD) : _blue),
                  const SizedBox(width: 8),
                  Text(
                    'همه فاکتورها',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: dark ? Colors.white : _slate800),
                  ),
                  const Spacer(),
                  Text(
                    '${PersianNumberFormatter.toPersian(invoices.length)} فقره',
                    style: TextStyle(fontSize: 11, color: _subtitleColor),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: invoices.length,
                itemBuilder: (ctx, idx) {
                  final inv = invoices.reversed.elementAt(idx);
                  return _InvoiceRow(inv: inv, dark: dark);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  Stat Card
// ============================================================
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color chipColor;
  final Color chipBg;
  final String caption;
  final Color captionColor;
  final Color? valueColor;
  final double valueFontSize;
  final VoidCallback? onCaptionTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.chipColor,
    required this.chipBg,
    required this.caption,
    required this.captionColor,
    this.valueColor,
    this.valueFontSize = 22,
    this.onCaptionTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = dark ? _slate800 : Colors.white;
    final border = dark ? _slate700 : _slate200;
    final titleColor = dark ? _slate400 : _slate600;
    final valueColor = this.valueColor ?? (dark ? Colors.white : _slate800);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: titleColor)),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: chipColor, size: 18),
              ),
            ],
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: valueFontSize,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
          GestureDetector(
            onTap: onCaptionTap,
            child: Text(
              caption,
              style: TextStyle(fontSize: 10, color: captionColor, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  Quick Action Button
// ============================================================
class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final Color chipColor;
  final Color chipBg;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.chipColor = _emerald,
    this.chipBg = _emeraldSoft,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (filled) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: Color(0x33FFFFFF), shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 8),
              const Text(
                'فاکتور جدید',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: dark ? _slate800 : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: dark ? _slate700 : _slate200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: chipBg, shape: BoxShape.circle),
              child: Icon(icon, color: chipColor, size: 17),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: dark ? Colors.white : _slate800,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  Invoice Row + Status Badge
// ============================================================
class _InvoiceRow extends StatelessWidget {
  final InvoiceModel inv;
  final bool dark;

  const _InvoiceRow({required this.inv, required this.dark});

  Color get _cardBorder => dark ? _slate700 : _slate200;
  Color get _titleColor => dark ? Colors.white : _slate800;

  Widget _statusBadge(String status, String type) {
    final (String text, Color fg, Color bg) = switch (type) {
      'proforma' => ('پیش‌فاکتور', _amber, dark ? const Color(0xFF3B2E12) : _amberSoft),
      _ => switch (status) {
        'paid' => ('پرداخت شده', _emerald, dark ? const Color(0xFF123B2D) : _emeraldSoft),
        'unpaid' || 'partial' => ('بدهکار / غیرنقدی', _rose, dark ? const Color(0xFF3B1220) : _roseSoft),
        _ => ('عادی', _slate600, dark ? _slate700 : _slate100),
      },
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark ? _slate700.withValues(alpha: 0.35) : _slate100.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dark ? _slate700.withValues(alpha: 0.6) : _slate200.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          // Number chip
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: dark ? _slate700 : _slate100,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '#${PersianNumberFormatter.toPersian(inv.number)}',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: dark ? Colors.white : _slate700),
            ),
          ),
          const SizedBox(width: 10),
          // Customer & meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inv.customerName.isEmpty ? 'مشتری عمومی' : inv.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _titleColor),
                ),
                const SizedBox(height: 2),
                Text(
                  'تاریخ: ${PersianNumberFormatter.toPersian(inv.date)}  •  ${PersianNumberFormatter.toPersian(inv.items.length)} آیتم',
                  style: TextStyle(fontSize: 10, color: _slate400),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Amount & status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                PersianNumberFormatter.formatCurrency(inv.totalAmount),
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: _titleColor),
              ),
              const SizedBox(height: 4),
              _statusBadge(inv.status, inv.type),
            ],
          ),
        ],
      ),
    );
  }
}
