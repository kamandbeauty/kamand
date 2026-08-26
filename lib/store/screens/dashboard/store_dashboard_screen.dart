import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../store_core.dart';
import '../../providers/store_providers.dart';
import '../store_ui_helpers.dart';
import '../installment/settlements_screen.dart';

/// داشبورد فروشگاه (§3، §47) — با حالت‌های خالی ایمن
class StoreDashboardScreen extends ConsumerStatefulWidget {
  const StoreDashboardScreen({super.key});

  @override
  ConsumerState<StoreDashboardScreen> createState() => _StoreDashboardScreenState();
}

class _StoreDashboardScreenState extends ConsumerState<StoreDashboardScreen> {
  DashboardData? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
    });
    try {
      final core = await ref.read(storeCoreProvider.future);
      final today = todayIso();
      final d = core.reports.dashboard(today);
      final recentInvoices = core.reports.recentInvoices(limit: 8);
      final recentTx = core.reports.recentTransactions(limit: 12);
      final lowStock = core.inventory.lowStock();
      if (!mounted) return;
      setState(() {
        _data = DashboardData(d, recentInvoices, recentTx, lowStock);
      });
    } catch (e) {
      setState(() {
        _error = 'خطا در خواندن اطلاعات: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreScaffold(
      title: 'داشبورد فروشگاه',
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ],
      body: (core) {
        if (_error != null) {
          return _Empty(text: _error!);
        }
        final d = _data;
        if (d == null) {
          return const Center(child: CircularProgressIndicator());
        }
        final pendingConfirm = core.installments
            .pendingSettlementConfirmations(todayIso())
            .length;
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              // ── یادآور تسویهٔ درگاه‌ها (۱ تا ۵ هر ماه) ──
              if (pendingConfirm > 0)
                Card(
                  color: const Color(0xFFFFFBEB),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                          color: AppTheme.RubyWarning.withOpacity(0.5))),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.RubyWarning.withOpacity(0.15),
                      child: const Icon(Icons.notifications_active,
                          color: AppTheme.RubyWarning, size: 22),
                    ),
                    title: const Text('تسویه‌های درگاه‌ها را ثبت کنید',
                        style: TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w900)),
                    subtitle: Text(
                        '$pendingConfirm قسط تسویهٔ سررسیدگذشته در انتظار پرسش «درگاه تسویه کرد؟»',
                        style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.chevron_left, size: 20),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettlementsScreen())),
                  ),
                ),

              // ── فروش امروز ──
              const SectionHeader('فروش امروز'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.1,
                children: [
                  InfoCard(
                      label: 'فروش امروز',
                      value: formatToman(d.summary.todaySales),
                      icon: Icons.sell_outlined),
                  InfoCard(
                      label: 'تعداد فاکتور امروز',
                      value: '${d.summary.todayInvoiceCount}',
                      icon: Icons.receipt),
                  InfoCard(
                      label: 'فروش نقدی امروز',
                      value: formatToman(d.summary.todayCashSales),
                      icon: Icons.payments,
                      color: AppTheme.RubySuccess),
                  InfoCard(
                      label: 'فروش نسیه امروز',
                      value: formatToman(d.summary.todayCreditSales),
                      icon: Icons.credit_score,
                      color: AppTheme.RubyWarning),
                  InfoCard(
                      label: 'فروش اقساطی امروز',
                      value: formatToman(d.summary.todayInstallmentSales),
                      icon: Icons.schedule,
                      color: Colors.purple),
                  InfoCard(
                      label: 'هزینهٔ امروز',
                      value: formatToman(d.summary.todayExpenses),
                      icon: Icons.receipt_long,
                      color: AppTheme.RubyError),
                ],
              ),

              // ── اقساط ──
              const SectionHeader('اقساط'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.1,
                children: [
                  InfoCard(
                      label: 'اقساط سررسید امروز',
                      value: '${d.summary.dueTodayCount} — ${formatToman(d.summary.dueTodayAmount)}',
                      icon: Icons.event,
                      color: AppTheme.RubyWarning),
                  InfoCard(
                      label: 'اقساط معوق',
                      value: '${d.summary.overdueCount} — ${formatToman(d.summary.overdueAmount)}',
                      icon: Icons.warning_amber,
                      color: AppTheme.RubyError),
                  InfoCard(
                      label: 'تسویه‌های آینده (سیستم‌ها)',
                      value: formatToman(d.summary.expectedReceivables),
                      icon: Icons.account_balance_wallet,
                      color: Colors.indigo),
                  InfoCard(
                      label: 'فروش اقساطی — سود ماه',
                      value: 'سود ماه: ${formatToman(d.summary.monthNetProfit)}',
                      icon: Icons.trending_up,
                      color: AppTheme.RubySuccess),
                ],
              ),

              // ── وضعیت مالی ──
              const SectionHeader('وضعیت مالی');
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.1,
                children: [
                  InfoCard(
                      label: 'دریافتنی از مشتریان',
                      value: formatToman(d.summary.receivables),
                      icon: Icons.group,
                      color: AppTheme.RubyWarning),
                  InfoCard(
                      label: 'پرداختنی به تأمین‌کنندگان',
                      value: formatToman(d.summary.payables),
                      icon: Icons.local_shipping,
                      color: AppTheme.RubyError),
                  InfoCard(
                      label: 'کالای کم‌موجودی',
                      value: '${d.summary.lowStockCount}',
                      icon: Icons.inventory_2,
                      color: AppTheme.RubyWarning),
                  InfoCard(
                      label: 'ارزش موجودی انبار',
                      value: formatToman(core.inventory.valuation()),
                      icon: Icons.warehouse,
                      color: Colors.teal),
                ],
              ),

              // ── هشدار کمبود موجودی ──
              if (d.lowStock.isNotEmpty) ...[
                const SectionHeader('هشدار کمبود موجودی'),
                _LowStockList(items: d.lowStock),
              ],

              // ── فاکتورهای اخیر ──
              const SectionHeader('فاکتورهای اخیر'),
              if (d.recentInvoices.isEmpty)
                const _Empty(text: 'هنوز فاکتوری ثبت نشده است')
              else
                ...d.recentInvoices.map((r) => _RecentInvoiceTile(row: r)),

              // ── تراکنش‌های اخیر ──
              const SectionHeader('تراکنش‌های مالی اخیر'),
              if (d.recentTx.isEmpty)
                const _Empty(text: 'هنوز تراکنش مالی ثبت نشده است')
              else
                ...d.recentTx.map((e) => _RecentTxTile(
                      title: _eventTypeLabel(e.eventType),
                      subtitle:
                          '${faDate(e.eventDate)} — ${e.description.isEmpty ? e.reference : e.description}',
                      amount: e.amount *
                          (e.direction == -1 ? -1 : (e.direction == 1 ? 1 : 0)),
                    )),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  String _eventTypeLabel(String t) {
    const labels = {
      'SALE': 'فروش',
      'PAYMENT_RECEIVED': 'دریافت وجه',
      'REFUND': 'برگشت وجه',
      'EXPENSE': 'هزینه',
      'SHIPPING_EXPENSE': 'هزینهٔ ارسال',
      'PACKAGING_EXPENSE': 'هزینهٔ بسته‌بندی',
      'PACKAGING_CHARGE': 'دریافت بسته‌بندی',
      'SHIPPING_CHARGE': 'دریافت ارسال',
      'PURCHASE': 'خرید',
      'PURCHASE_PAYMENT': 'پرداخت خرید',
      'SUPPLIER_PAYMENT': 'پرداخت به تأمین‌کننده',
      'PURCHASE_RETURN': 'برگشت خرید',
      'SALE_RETURN': 'برگشت فروش',
      'REVENUE_REVERSED': 'اصلاح درآمد',
      'INSTALLMENT_CREATED': 'فروش اقساطی',
      'INSTALLMENT_PAID': 'دریافت قسط',
      'PROVIDER_SETTLEMENT': 'تسویهٔ اقساطی',
      'PROVIDER_COMMISSION': 'کارمزد اقساطی',
      'ACCOUNT_TRANSFER': 'انتقال وجه',
      'DEPOSIT': 'واریز',
      'WITHDRAWAL': 'برداشت',
      'ADJUSTMENT': 'تعدیل',
    };
    return labels[t] ?? t;
  }
}

class DashboardData {
  final dynamic summary;
  final List<Map<String, Object?>> recentInvoices;
  final List<dynamic> recentTx;
  final List<dynamic> lowStock;
  DashboardData(this.summary, this.recentInvoices, this.recentTx, this.lowStock);
}

class _LowStockList extends StatelessWidget {
  final List<dynamic> items;
  const _LowStockList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          for (var i = 0; i < items.length && i < 6; i++)
            ListTile(
              dense: true,
              leading: const Icon(Icons.warning_amber, color: AppTheme.RubyWarning),
              title: Text('کد: ${items[i].productId}'),
              subtitle: Text(
                  'موجودی ${items[i].currentQty} — حداقل ${items[i].minQty}'),
            ),
        ],
      ),
    );
  }
}

class _RecentInvoiceTile extends StatelessWidget {
  final Map<String, Object?> row;
  const _RecentInvoiceTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final remaining = (row['remaining'] as int? ?? 0);
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: remaining > 0
              ? AppTheme.RubyWarning.withOpacity(0.15)
              : AppTheme.RubySuccess.withOpacity(0.15),
          child: Icon(
            remaining > 0 ? Icons.credit_score : Icons.check_circle,
            color: remaining > 0 ? AppTheme.RubyWarning : AppTheme.RubySuccess,
            size: 20,
          ),
        ),
        title: Text('فاکتور ${row['number']} — ${row['customer_name'] ?? ''}'),
        subtitle: Text(
            'مبلغ: ${formatToman(row['total'] as int? ?? 0)} · ${faDate(row['doc_date'] as String?)}'),
        trailing: remaining > 0
            ? Text(
                'مانده: ${formatToman(remaining)}',
                style: const TextStyle(
                    color: AppTheme.RubyWarning,
                    fontSize: 11,
                    fontWeight: FontWeight.w800),
              )
            : const Text('تسویه',
                style: TextStyle(
                    color: AppTheme.RubySuccess,
                    fontSize: 11,
                    fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _RecentTxTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final int amount;
  const _RecentTxTile(
      {required this.title, required this.subtitle, required this.amount});

  @override
  Widget build(BuildContext context) {
    final isIn = amount > 0;
    final isNeutral = amount == 0;
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        dense: true,
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(
          isNeutral ? formatToman(amount) : '${isIn ? '+' : '−'}${formatToman(amount.abs())}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: isNeutral
                ? AppTheme.RubyTextSecondary
                : (isIn ? AppTheme.RubySuccess : AppTheme.RubyError),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(color: AppTheme.RubyTextSecondary, fontSize: 12.5),
        textAlign: TextAlign.center,
      ),
    );
  }
}
