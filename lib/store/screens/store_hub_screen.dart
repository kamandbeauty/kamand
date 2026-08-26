import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'accounts_screen.dart';
import 'cheques_screen.dart';
import 'closing_audit_screen.dart';
import 'customer_finance_screen.dart';
import 'dashboard/store_dashboard_screen.dart';
import 'expenses_screen.dart';
import 'installment/installment_center_screen.dart';
import 'installment/installment_providers_screen.dart';
import 'installment/installment_sale_screen.dart';
import 'installment/settlements_screen.dart';
import 'purchase_screen.dart';
import 'reports_screen.dart';
import 'suppliers_screen.dart';

/// مرکز ماژول «مدیریت فروشگاه» — نقطهٔ ورود گسترش جدید (§46)
class StoreHubScreen extends StatelessWidget {
  const StoreHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = <_HubItem>[
      _HubItem('داشبورد فروشگاه', 'امروز، اقساط و هشدارها', Icons.dashboard_customize, Colors.orange,
          (c) => const StoreDashboardScreen()),
      _HubItem('مالی مشتریان', 'بدهکاران، دریافت و سقف اعتبار', Icons.group, Colors.amber,
          (c) => const CustomerFinanceScreen()),
      _HubItem('تأمین‌کنندگان', 'فهرست، بدهی و پرداخت', Icons.local_shipping, Colors.blue,
          (c) => const SuppliersScreen()),
      _HubItem('فاکتور خرید', 'ثبت خرید و افزایش موجودی', Icons.shopping_cart, Colors.teal,
          (c) => const PurchaseScreen()),
      _HubItem('هزینه‌ها', 'ثبت و دسته‌بندی هزینه‌ها', Icons.receipt_long, const Color(0xFFF43F5E),
          (c) => const ExpensesScreen()),
      _HubItem('صندوق و بانک', 'حساب‌ها، انتقال وجه و تراکنش‌ها', Icons.account_balance, Colors.indigo,
          (c) => const AccountsScreen()),
      _HubItem('چک‌ها', 'دریافت/پرداخت چک، سررسید و پاس‌شدن', Icons.receipt, Colors.deepPurple,
          (c) => const ChequesScreen()),
      _HubItem('فروش اقساطی', 'اسنپ‌پی، ترب‌پی، دیجی‌پی، باسلام…', Icons.schedule, Colors.purple,
          (c) => const InstallmentSaleScreen()),
      _HubItem('اقساط و سررسیدها', 'امروز، معوق و آینده', Icons.event_available, Colors.deepOrange,
          (c) => const InstallmentCenterScreen()),
      _HubItem('تسویه‌های اقساطی', 'تسویه با سیستم‌های اقساطی', Icons.payment, Colors.green,
          (c) => const SettlementsScreen()),
      _HubItem('سیستم‌های اقساطی', 'پیکربندی کارمزد و قرارداد', Icons.tune, Colors.brown,
          (c) => const InstallmentProvidersScreen()),
      _HubItem('گزارش‌ها', 'سود و زیان، فروش، جریان نقدی…', Icons.assessment, Colors.cyan,
          (c) => const ReportsScreen()),
      _HubItem('بستن روز و حسابرسی', 'تطبیق صندوق و تاریخچه', Icons.fact_check, Colors.blueGrey,
          (c) => const ClosingAuditScreen()),
    ];

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('مدیریت فروشگاه'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.RubyPrimary, AppTheme.RubyPrimaryDark]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مدیریت کامل فروشگاه',
                  style: TextStyle(
                      color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 6),
                Text(
                  'خرید و تأمین‌کنندگان، هزینه‌ها، صندوق و بانک، فروش اقساطی و گزارش‌های مالی — همهٔ آفلاین',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.55,
            children: [
              for (final s in sections)
                _HubCard(item: s),
            ],
          ),
        ],
      ),
    );
  }
}

class _HubItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;
  _HubItem(this.title, this.subtitle, this.icon, this.color, this.builder);
}

class _HubCard extends StatelessWidget {
  final _HubItem item;
  const _HubCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: item.builder)),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: item.color.withValues(alpha: 0.14),
              child: Icon(item.icon, color: item.color, size: 20),
            ),
            const Spacer(),
            Text(
              item.title,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w900, color: AppTheme.RubyTextPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              item.subtitle,
              style: const TextStyle(fontSize: 10.5, color: AppTheme.RubyTextSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
