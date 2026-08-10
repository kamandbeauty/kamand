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

// ──────────────────────────────────────────────────────────────
//  HomeScreen — Modern Mobile Invoice Dashboard (Spec §4, §27)
// ──────────────────────────────────────────────────────────────
//
//  Structure (exact order per spec §4):
//   Header
//   Welcome (سلام + subtitle)
//   CreateInvoice CTA
//   TodaySummaryCard (فروش امروز + دریافت + طلب)
//   QuickActions (2 columns)
//   RecentInvoices (last 5)
//   BottomNavigation (5 items)
// ──────────────────────────────────────────────────────────────

// ── Design tokens — all via AppTheme where possible (Spec §22)
const _orange = AppTheme.RubyPrimary; // #F97316
const _orangeContainer = AppTheme.RubyPrimaryContainer;
const _orangeDark = AppTheme.RubyPrimaryDark;
const _bgLight = AppTheme.bgLight; // #FFFBEB warm
const _success = AppTheme.RubySuccess;
const _warning = AppTheme.RubyWarning;
const _error = AppTheme.RubyError;
const _slate100 = Color(0xFFF1F5F9);
const _slate200 = Color(0xFFE2E8F0);
const _slate300 = Color(0xFFCBD5E1);
const _slate400 = Color(0xFF94A3B8);
const _slate500 = Color(0xFF64748B);
const _slate600 = Color(0xFF475569);
const _slate700 = Color(0xFF334155);
const _slate800 = Color(0xFF1E293B);
const _slate900 = Color(0xFF0F172A);

// ──────────────────────────────────────────────────────────────
//  Main HomeScreen (Stateful for loading/error handling)
// ──────────────────────────────────────────────────────────────
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _navIndex = 0; // 0=خانه active (Spec §20-21)
  bool _isLoading = true;
  String? _errorMsg;
  bool _hasPaymentModule = false; // auto-detected: spec §13

  @override
  void initState() {
    super.initState();
    // Simulate async load + detect payment module (Spec §18, §30)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // Check if Payment module exists: look for financial provider with payment-like records
        // Current project has no dedicated Payment entity (§11) → hide "دریافت‌ها" card
        _hasPaymentModule = false;
      });
    });
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() => _isLoading = false);
    });
  }

  // Bottom nav tap
  void _onNavTap(int idx) {
    if (idx == _navIndex) return;
    // Preserve existing routes (Spec §20)
    switch (idx) {
      case 0:
        setState(() => _navIndex = 0);
        break;
      case 1: // فاکتورها
        _openInvoiceList();
        break;
      case 2: // مشتریان
        Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen()));
        break;
      case 3: // محصولات
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListScreen()));
        break;
      case 4: // بیشتر
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
        break;
    }
  }

  void _openInvoiceList() {
    // Invoice List: use bottom sheet with full list (no dedicated list screen exists)
    // This preserves existing logic and avoids creating orphan routes (Spec §28)
    final invoices = ref.read(invoiceListProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
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
        builder: (context, sc) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: dark ? _slate700 : _slate200, borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, size: 20, color: _orange),
                  const SizedBox(width: 8),
                  Text('همه فاکتورها', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: dark ? Colors.white : _slate800)),
                  const Spacer(),
                  Text('${PersianNumberFormatter.toPersian(invoices.length)} فقره', style: TextStyle(fontSize: 11, color: _slate400)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: invoices.isEmpty
                  ? Center(child: Text('فاکتوری وجود ندارد', style: TextStyle(color: _slate400)))
                  : ListView.builder(
                      controller: sc,
                      padding: const EdgeInsets.all(16),
                      itemCount: invoices.length,
                      itemBuilder: (c, i) {
                        final inv = invoices.reversed.elementAt(i);
                        return InvoiceListItem(inv: inv);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(userProvider);
    final business = ref.watch(businessProvider);
    final invoices = ref.watch(invoiceListProvider);
    final customers = ref.watch(customerListProvider);

    // Error state (Spec §19)
    if (_errorMsg != null) {
      return Scaffold(
        backgroundColor: dark ? _slate900 : _bgLight,
        body: Center(child: _ErrorState(message: _errorMsg!, onRetry: _retry)),
        bottomNavigationBar: _buildBottomNav(dark),
      );
    }

    // Compute summaries (Spec §9-12) — with error guard (Spec §31)
    double todaySales = 0;
    double todayReceived = 0;
    double receivable = 0;
    List<InvoiceModel> recentFive = [];
    int unpaidCount = 0;
    try {
      final todayStr = JalaliHelper.getTodayJalali();
      // Spec §10: only today's sale invoices, exclude cancelled/deleted
      final todaySaleInvoices = invoices.where((inv) =>
          inv.date == todayStr &&
          inv.type == 'sale' &&
          inv.status != 'cancelled' &&
          inv.status != 'deleted');
      todaySales = todaySaleInvoices.fold(0, (s, i) => s + i.totalAmount);

      // Spec §11: if no Payment entity, sum paidAmount today
      todayReceived = todaySaleInvoices.fold(0, (s, i) => s + i.paidAmount);

      // Spec §12: receivable = total - paid for debt invoices
      receivable = invoices
          .where((inv) => inv.remainingAmount > 0 && inv.status != 'paid' && inv.status != 'cancelled' && inv.status != 'deleted')
          .fold(0, (s, i) => s + i.remainingAmount);
      // Fallback: if remainingAmount zero but customers have balance
      if (receivable == 0) {
        receivable = customers.fold(0, (s, c) => s + c.balance);
      }

      // Spec §14: last 5 newest first
      final sorted = List<InvoiceModel>.from(invoices);
      // invoices are insertion order; newest last → reversed, take 5
      recentFive = sorted.reversed.take(5).toList();

      unpaidCount = invoices.where((i) => i.remainingAmount > 0 && i.status != 'paid').length;
    } catch (e) {
      // Don't crash whole home (Spec §19)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _errorMsg == null) setState(() => _errorMsg = 'دریافت اطلاعات با مشکل مواجه شد');
      });
    }

    return Scaffold(
      backgroundColor: dark ? _slate900 : _bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header 56-64dp (Spec §5)
              HomeHeader(
                shopName: business.shopName,
                notificationCount: unpaidCount,
              ),

              // ── Content padding
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Welcome (Spec §7)
                    WelcomeSection(userName: user.name),

                    const SizedBox(height: 16),

                    // ── CTA (Spec §8)
                    CreateInvoiceButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceCreateScreen()));
                      },
                    ),

                    const SizedBox(height: 20),

                    // ── Today Summary (Spec §9)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('خلاصه امروز', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: dark ? Colors.white : _slate800)),
                        InkWell(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialDashboardScreen())),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              children: [
                                Text('گزارش کامل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _orange)),
                                const SizedBox(width: 2),
                                const Icon(Icons.chevron_left, size: 16, color: _orange),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_isLoading)
                      const TodaySummarySkeleton()
                    else
                      TodaySummaryCard(
                        salesAmount: todaySales,
                        receivedAmount: todayReceived,
                        receivableAmount: receivable,
                      ),

                    const SizedBox(height: 20),

                    // ── Quick Actions (Spec §13)
                    Text('دسترسی سریع', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: dark ? Colors.white : _slate800)),
                    const SizedBox(height: 10),
                    if (_isLoading)
                      const QuickActionsSkeleton()
                    else
                      QuickActionsSection(
                        hasPaymentModule: _hasPaymentModule,
                        onCustomers: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen())),
                        onProducts: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListScreen())),
                        onInvoices: _openInvoiceList,
                        onReceivables: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialDashboardScreen())),
                      ),

                    const SizedBox(height: 20),

                    // ── Recent Invoices (Spec §14)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('آخرین فاکتورها', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: dark ? Colors.white : _slate800)),
                        InkWell(
                          onTap: _openInvoiceList,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              children: [
                                Text('مشاهده همه', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _orange)),
                                const SizedBox(width: 2),
                                const Icon(Icons.chevron_left, size: 16, color: _orange),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_isLoading)
                      const RecentInvoicesSkeleton()
                    else if (recentFive.isEmpty)
                      EmptyInvoiceState(
                        onCreate: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceCreateScreen())),
                      )
                    else
                      RecentInvoicesSection(invoices: recentFive),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(dark),
    );
  }

  Widget _buildBottomNav(bool dark) {
    return Container(
      decoration: BoxDecoration(
        color: dark ? _slate800 : Colors.white,
        border: Border(top: BorderSide(color: dark ? _slate700 : _slate200)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(label: 'خانه', iconFilled: Icons.home, iconOutlined: Icons.home_outlined, active: _navIndex == 0, onTap: () => _onNavTap(0), dark: dark),
              _NavItem(label: 'فاکتورها', iconFilled: Icons.receipt_long, iconOutlined: Icons.receipt_long_outlined, active: _navIndex == 1, onTap: () => _onNavTap(1), dark: dark),
              _NavItem(label: 'مشتریان', iconFilled: Icons.people, iconOutlined: Icons.people_outline, active: _navIndex == 2, onTap: () => _onNavTap(2), dark: dark),
              _NavItem(label: 'محصولات', iconFilled: Icons.inventory_2, iconOutlined: Icons.inventory_2_outlined, active: _navIndex == 3, onTap: () => _onNavTap(3), dark: dark),
              _NavItem(label: 'بیشتر', iconFilled: Icons.menu, iconOutlined: Icons.menu_outlined, active: _navIndex == 4, onTap: () => _onNavTap(4), dark: dark),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  HomeHeader  (Spec §5-6) — 56..64dp, logo Ruby fox + title, notif icon
// ──────────────────────────────────────────────────────────────
class HomeHeader extends StatelessWidget {
  final String shopName;
  final int notificationCount;

  const HomeHeader({super.key, required this.shopName, this.notificationCount = 0});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 60, // within 56-64dp
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: dark ? _slate800 : Colors.white,
        border: Border(bottom: BorderSide(color: dark ? _slate700 : _slate200)),
      ),
      child: Row(
        children: [
          // Right: Logo fox Ruby (small, professional) + title
          // Use existing asset exactly (Spec §6)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/logo.png',
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: const Text('ر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              shopName.isNotEmpty ? shopName : 'فاکتور ساز روبی',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: dark ? Colors.white : _slate800),
            ),
          ),
          // Left: Notification Icon with badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Icon(Icons.notifications_none_rounded, color: dark ? Colors.white : _slate600, size: 24),
                onPressed: () {},
                tooltip: 'اعلان‌ها',
              ),
              if (notificationCount > 0)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: _error, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      PersianNumberFormatter.toPersian(notificationCount > 99 ? '99+' : notificationCount.toString()),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  WelcomeSection (Spec §7)
// ──────────────────────────────────────────────────────────────
class WelcomeSection extends StatelessWidget {
  final String userName;
  const WelcomeSection({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final displayName = userName.trim().isEmpty ? '' : ' $userName';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سلام$displayName 👋',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: dark ? Colors.white : _slate800),
        ),
        const SizedBox(height: 4),
        Text(
          'امروز آماده‌ای فاکتور بسازی؟',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: dark ? _slate400 : _slate500),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  CreateInvoiceButton (Spec §8) — match parent, 52-56dp, radius 16, Ruby Orange via token
// ──────────────────────────────────────────────────────────────
class CreateInvoiceButton extends StatelessWidget {
  final VoidCallback onPressed;
  const CreateInvoiceButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54, // within 52-56dp
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add, size: 20, color: Colors.white),
        label: const Text('+ ساخت فاکتور', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _orange, // via token AppTheme.RubyPrimary
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  TodaySummaryCard (Spec §9-12)
//  Card white radius 18 padding 16 shadow minimal
// ──────────────────────────────────────────────────────────────
class TodaySummaryCard extends StatelessWidget {
  final double salesAmount;
  final double receivedAmount;
  final double receivableAmount;

  const TodaySummaryCard({
    super.key,
    required this.salesAmount,
    required this.receivedAmount,
    required this.receivableAmount,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16), // spec §9
      decoration: BoxDecoration(
        color: dark ? _slate800 : Colors.white,
        borderRadius: BorderRadius.circular(18), // spec §9
        border: Border.all(color: dark ? _slate700 : _slate200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.15 : 0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sales — full width hero metric (Spec §9)
          SalesMetric(amount: salesAmount),
          const SizedBox(height: 14),
          Divider(color: dark ? _slate700 : _slate200, height: 1),
          const SizedBox(height: 14),
          // Two cols: دریافت | طلب مشتریان
          Row(
            children: [
              Expanded(child: PaymentMetric(amount: receivedAmount)),
              Container(width: 1, height: 44, color: dark ? _slate700 : _slate200, margin: const EdgeInsets.symmetric(horizontal: 12)),
              Expanded(child: ReceivableMetric(amount: receivableAmount)),
            ],
          ),
        ],
      ),
    );
  }
}

class SalesMetric extends StatelessWidget {
  final double amount;
  const SalesMetric({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: dark ? const Color(0xFF431407) : _orangeContainer, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.trending_up, color: _orange, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('فروش امروز', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dark ? _slate400 : _slate500)),
              const SizedBox(height: 2),
              Text(
                PersianNumberFormatter.formatCurrency(amount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark ? Colors.white : _slate800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PaymentMetric extends StatelessWidget {
  final double amount;
  const PaymentMetric({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: dark ? const Color(0xFF052E1F) : const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.payments_outlined, color: _success, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('دریافت', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: dark ? _slate400 : _slate500)),
              const SizedBox(height: 2),
              Text(
                PersianNumberFormatter.formatCurrency(amount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: dark ? Colors.white : _slate800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ReceivableMetric extends StatelessWidget {
  final double amount;
  const ReceivableMetric({super.key, required this.amount});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: dark ? const Color(0xFF450A0A) : const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.account_balance_wallet_outlined, color: _error, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('طلب مشتریان', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: dark ? _slate400 : _slate500)),
              const SizedBox(height: 2),
              Text(
                PersianNumberFormatter.formatCurrency(amount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: dark ? Colors.white : _slate800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  QuickActionsSection (Spec §13) — 2 columns
// ──────────────────────────────────────────────────────────────
class QuickActionsSection extends StatelessWidget {
  final bool hasPaymentModule;
  final VoidCallback onCustomers;
  final VoidCallback onProducts;
  final VoidCallback onInvoices;
  final VoidCallback onReceivables;

  const QuickActionsSection({
    super.key,
    required this.hasPaymentModule,
    required this.onCustomers,
    required this.onProducts,
    required this.onInvoices,
    required this.onReceivables,
  });

  @override
  Widget build(BuildContext context) {
    // Build list, hide "دریافت‌ها" if no payment module (Spec §13)
    final actions = <_QA>[
      _QA('مشتریان', Icons.people_alt_outlined, const Color(0xFF2563EB), const Color(0xFFEFF6FF), onCustomers),
      _QA('محصولات', Icons.inventory_2_outlined, const Color(0xFF7C3AED), const Color(0xFFF5F3FF), onProducts),
      _QA('فاکتورها', Icons.receipt_long_outlined, const Color(0xFF059669), const Color(0xFFECFDF5), onInvoices),
      if (hasPaymentModule) _QA('دریافت‌ها', Icons.payments_outlined, const Color(0xFFD97706), const Color(0xFFFFFBEB), onReceivables),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.3, // compact, no horizontal scroll, no clipping (Spec §26)
      ),
      itemCount: actions.length,
      itemBuilder: (ctx, i) => QuickActionCard(data: actions[i]),
    );
  }
}

class _QA {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  _QA(this.label, this.icon, this.color, this.bg, this.onTap);
}

class QuickActionCard extends StatelessWidget {
  final _QA data;
  const QuickActionCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: dark ? _slate800 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dark ? _slate700 : _slate200),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: dark ? data.color.withValues(alpha: 0.18) : data.bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(data.icon, color: data.color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: dark ? Colors.white : _slate800),
              ),
            ),
            Icon(Icons.chevron_left, size: 16, color: _slate400),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  RecentInvoicesSection + InvoiceListItem (Spec §14-16)
// ──────────────────────────────────────────────────────────────
class RecentInvoicesSection extends StatelessWidget {
  final List<InvoiceModel> invoices;
  const RecentInvoicesSection({super.key, required this.invoices});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: invoices.map((inv) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InvoiceListItem(inv: inv),
      )).toList(),
    );
  }
}

class InvoiceListItem extends StatelessWidget {
  final InvoiceModel inv;
  const InvoiceListItem({super.key, required this.inv});

  String _statusLabel(String s, String type) {
    if (type == 'proforma') return 'پیش‌فاکتور';
    switch (s) {
      case 'paid':
        return 'پرداخت شده';
      case 'unpaid':
        return 'پرداخت نشده';
      case 'partial':
        return 'پرداخت ناقص';
      case 'cancelled':
        return 'لغو شده';
      default:
        return 'پرداخت نشده';
    }
  }

  Color _statusColor(String s, String type) {
    if (type == 'proforma') return _warning;
    switch (s) {
      case 'paid':
        return _success;
      case 'partial':
        return _warning;
      default:
        return _error;
    }
  }

  Color _statusBg(String s, String type, bool dark) {
    if (type == 'proforma') return dark ? const Color(0xFF422006) : const Color(0xFFFFFBEB);
    switch (s) {
      case 'paid':
        return dark ? const Color(0xFF052E1F) : const Color(0xFFECFDF5);
      case 'partial':
        return dark ? const Color(0xFF422006) : const Color(0xFFFFFBEB);
      default:
        return dark ? const Color(0xFF450A0A) : const Color(0xFFFFF1F2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final statusText = _statusLabel(inv.status, inv.type);
    final statusColor = _statusColor(inv.status, inv.type);
    final statusBg = _statusBg(inv.status, inv.type, dark);

    // Simple compact card — not huge (Spec §15)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: dark ? _slate800 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? _slate700 : _slate200),
      ),
      child: Row(
        children: [
          // Right: customer + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inv.customerName.isEmpty ? 'مشتری عمومی' : inv.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: dark ? Colors.white : _slate800),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'فاکتور #${PersianNumberFormatter.toPersian(inv.number)}',
                      style: TextStyle(fontSize: 11, color: _slate500),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 3, height: 3, decoration: BoxDecoration(color: _slate300, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        PersianNumberFormatter.toPersian(inv.date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: _slate500),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Left: amount + status badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                PersianNumberFormatter.formatCurrency(inv.totalAmount),
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: dark ? Colors.white : _slate800),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(999)),
                child: Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  EmptyInvoiceState (Spec §17) — uses Ruby fox asset subtly
// ──────────────────────────────────────────────────────────────
class EmptyInvoiceState extends StatelessWidget {
  final VoidCallback onCreate;
  const EmptyInvoiceState({super.key, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: dark ? _slate800 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dark ? _slate700 : _slate200),
      ),
      child: Column(
        children: [
          // Subtle Ruby illustration — small professional (Spec §6)
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: _orangeContainer, borderRadius: BorderRadius.circular(18)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/images/logo.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.receipt_long, size: 36, color: _orange),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text('هنوز فاکتوری ثبت نکرده‌اید', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: dark ? Colors.white : _slate800)),
          const SizedBox(height: 6),
          Text('اولین فاکتور خود را در چند ثانیه بسازید.', style: TextStyle(fontSize: 12, color: _slate500)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: onCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('ساخت اولین فاکتور', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  Skeleton Loading (Spec §18) — no full-screen spinner
// ──────────────────────────────────────────────────────────────
class _SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const _SkeletonBox({this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: dark ? _slate700 : _slate200,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class TodaySummarySkeleton extends StatelessWidget {
  const TodaySummarySkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? _slate800 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: dark ? _slate700 : _slate200),
      ),
      child: Column(
        children: [
          Row(children: [const _SkeletonBox(width: 40, height: 40, radius: 12), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ _SkeletonBox(width: 80, height: 10), SizedBox(height: 8), _SkeletonBox(height: 16)]))]),
          const SizedBox(height: 14),
          Divider(color: dark ? _slate700 : _slate200, height: 1),
          const SizedBox(height: 14),
          Row(children: [Expanded(child: _SkeletonBox(height: 32, radius: 10)), SizedBox(width: 12), Expanded(child: _SkeletonBox(height: 32, radius: 10))]),
        ],
      ),
    );
  }
}

class QuickActionsSkeleton extends StatelessWidget {
  const QuickActionsSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.3),
      itemCount: 4,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? _slate800 : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? _slate700 : _slate200)),
        padding: const EdgeInsets.all(14),
        child: Row(children: [ _SkeletonBox(width: 36, height: 36, radius: 10), SizedBox(width: 10), Expanded(child: _SkeletonBox(height: 12))]),
      ),
    );
  }
}

class RecentInvoicesSkeleton extends StatelessWidget {
  const RecentInvoicesSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (_) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? _slate800 : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? _slate700 : _slate200)),
        child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ _SkeletonBox(width: 110, height: 12), SizedBox(height: 8), _SkeletonBox(width: 160, height: 10)])) , SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [_SkeletonBox(width: 90, height: 12), SizedBox(height: 8), _SkeletonBox(width: 70, height: 18, radius: 999)])]),
      )),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  Error State (Spec §19)
// ──────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: dark ? _slate800 : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: dark ? _slate700 : _slate200)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: _error, size: 32),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(fontSize: 13, color: dark ? Colors.white : _slate800, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ElevatedButton(onPressed: onRetry, style: ElevatedButton.styleFrom(backgroundColor: _orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('تلاش مجدد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
//  Bottom Navigation Item (Spec §20-21)
// ──────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final String label;
  final IconData iconFilled;
  final IconData iconOutlined;
  final bool active;
  final VoidCallback onTap;
  final bool dark;

  const _NavItem({
    required this.label,
    required this.iconFilled,
    required this.iconOutlined,
    required this.active,
    required this.onTap,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? _orange : (dark ? _slate400 : _slate500);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? iconFilled : iconOutlined, size: 22, color: color),
            const SizedBox(height: 4),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w900 : FontWeight.w600, color: color)),
            if (active) Container(margin: const EdgeInsets.only(top: 4), width: 16, height: 3, decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(3))),
          ],
        ),
      ),
    );
  }
}
