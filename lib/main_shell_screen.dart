import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/customer/customer_list_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/invoice/invoice_list_screen.dart';
import 'screens/product/product_list_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'store/screens/dashboard/store_dashboard_screen.dart';
import 'store/screens/cheques_screen.dart';
import 'store/screens/installment/settlements_screen.dart';
import 'store/screens/orders_screen.dart';
import 'store/screens/shipment_tracking_screen.dart';
import 'store/screens/store_hub_screen.dart';

/// پوستهٔ اصلی — ناوبری پایینی با ۵ بخش (فقط لایهٔ نمایشی؛
/// همهٔ صفحه‌ها همان صفحه‌های موجود بدون هیچ تغییری هستند)
class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          DashboardScreen(), // خانه — فاکتور سریع (دست‌نخورده)
          OrdersScreen(), // سفارش‌ها
          InvoiceListScreen(), // فاکتورها
          StoreHubScreen(), // مالی
          _MoreScreen(), // بیشتر
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: AppTheme.RubyPrimaryContainer,
        surfaceTintColor: Colors.white,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppTheme.RubyPrimary),
            label: 'خانه',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon:
                Icon(Icons.local_shipping_rounded, color: AppTheme.RubyPrimary),
            label: 'سفارش‌ها',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon:
                Icon(Icons.receipt_long_rounded, color: AppTheme.RubyPrimary),
            label: 'فاکتورها',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded,
                color: AppTheme.RubyPrimary),
            label: 'مالی',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon:
                Icon(Icons.grid_view_rounded, color: AppTheme.RubyPrimary),
            label: 'بیشتر',
          ),
        ],
      ),
    );
  }
}

/// بخش «بیشتر» — دسترسی بصری تمیز به بقیهٔ بخش‌های موجود
class _MoreScreen extends StatelessWidget {
  const _MoreScreen();

  @override
  Widget build(BuildContext context) {
    final items = <_MoreItemData>[
      _MoreItemData('مشتریان', 'بانک مشتریان و مانده‌حساب', Icons.people_outline,
          const CustomerListScreen()),
      _MoreItemData('محصولات', 'کاتالوگ کالا و موجودی', Icons.inventory_2_outlined,
          const ProductListScreen()),
      _MoreItemData('کدهای رهگیری ارسال', 'ورود گروهی کد رهگیری و اطلاع‌رسانی',
          Icons.qr_code, const ShipmentTrackingScreen()),
      _MoreItemData('داشبورد فروشگاه', 'خلاصهٔ امروز و هشدارها',
          Icons.dashboard_customize_outlined, const StoreDashboardScreen()),
      _MoreItemData('چک‌ها', 'سررسید، وصول و برگشت', Icons.receipt_outlined,
          const ChequesScreen()),
      _MoreItemData('تسویه با درگاه‌ها', 'اقساط اقساطی و یادآور ماهانه',
          Icons.payments_outlined, const SettlementsScreen()),
      _MoreItemData('تنظیمات', 'پروفایل، درگاه‌های اقساطی و پشتیبان',
          Icons.settings_outlined, const SettingsScreen()),
    ];
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('بیشتر')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          for (final it in items)
            Card(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.RubyPrimaryContainer,
                  child: Icon(it.icon, color: AppTheme.RubyPrimaryDark, size: 22),
                ),
                title: Text(it.title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900)),
                subtitle: Text(it.subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.RubyTextSecondary)),
                trailing: const Icon(Icons.chevron_left,
                    color: AppTheme.RubyTextSecondary),
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => it.screen)),
              ),
            ),
        ],
      ),
    );
  }
}

class _MoreItemData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget screen;
  const _MoreItemData(this.title, this.subtitle, this.icon, this.screen);
}
