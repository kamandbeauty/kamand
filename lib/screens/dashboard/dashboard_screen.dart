import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../providers/app_providers.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/customer_provider.dart';
import '../invoice/invoice_create_screen.dart';
import '../customer/customer_list_screen.dart';
import '../product/product_list_screen.dart';
import '../financial/financial_dashboard_screen.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final business = ref.watch(businessProvider);
    final invoices = ref.watch(invoiceListProvider);
    final customers = ref.watch(customerListProvider);

    // Stats calculations
    final todaySales = invoices.fold<double>(0, (sum, item) => sum + item.totalAmount);
    final todayReceived = invoices.fold<double>(0, (sum, item) => sum + item.paidAmount);
    final customerDebt = customers.fold<double>(0, (sum, item) => sum + item.balance);

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
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.black, fontSize: 16),
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
      drawer: Drawer(
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
                  style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.black, fontSize: 24),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats 2x2 Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                _buildStatCard('فروش امروز', PersianNumberFormatter.formatCurrency(todaySales), Icons.trending_up, Colors.blue),
                _buildStatCard('دریافت امروز', PersianNumberFormatter.formatCurrency(todayReceived), Icons.payments, Colors.emerald),
                _buildStatCard('بدهی مشتریان', PersianNumberFormatter.formatCurrency(customerDebt), Icons.warning_amber, Colors.rose),
                _buildStatCard('تعداد فاکتورها', PersianNumberFormatter.toPersian(invoices.length), Icons.description, Colors.purple),
              ],
            ),

            const SizedBox(height: 20),

            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceCreateScreen()));
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('فاکتور جدید'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen()));
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('مشتری جدید'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Recent Invoices Header
            const Text(
              'آخرین فاکتورها',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Invoices List
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: invoices.length,
              itemBuilder: (ctx, idx) {
                final inv = invoices[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.lightBlueBg,
                      child: Text('#${PersianNumberFormatter.toPersian(inv.number)}'),
                    ),
                    title: Text(inv.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('تاریخ: ${PersianNumberFormatter.toPersian(inv.date)}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          PersianNumberFormatter.formatCurrency(inv.totalAmount),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                        ),
                        Text(
                          inv.status == 'paid' ? 'پرداخت شده' : 'بدهکار',
                          style: TextStyle(
                            fontSize: 10,
                            color: inv.status == 'paid' ? Colors.emerald : Colors.rose,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                Icon(icon, color: color, size: 20),
              ],
            ),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.black, color: color)),
          ],
        ),
      ),
    );
  }
}
