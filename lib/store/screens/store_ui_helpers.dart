import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../core/money.dart';
import '../providers/store_providers.dart';
import '../store_core.dart';

/// ابزارهای مشترک UI ماژول فروشگاه

int? parseToman(String s) {
  final clean = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (clean.isEmpty) return null;
  return int.tryParse(clean);
}

String formatToman(int amount) => PersianNumberFormatter.formatCurrency(amount.toDouble());

String formatTomanPlain(int amount) =>
    PersianNumberFormatter.toPersian(Money.format(amount));

/// تبدیل تاریخ میلادی ISO به نمایش جلالی فارسی
String faDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final parts = iso.split('-');
    final g = Gregorian(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    final j = g.toJalali();
    return PersianNumberFormatter.toPersian(
        '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}');
  } catch (_) {
    return iso;
  }
}

/// قاب صفحهٔ فروشگاه: در حال آماده‌سازی / خطا / محتوا
class StoreScaffold extends ConsumerWidget {
  final String title;
  final Widget Function(BuildContext, StoreCore) body;
  final List<Widget>? actions;
  final Widget? fab;

  const StoreScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.fab,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coreAsync = ref.watch(storeCoreProvider);
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      floatingActionButton: fab,
      body: coreAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'خطا در آماده‌سازی هستهٔ مالی فروشگاه:\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.RubyError),
            ),
          ),
        ),
        data: (core) => body(context, core),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const InfoCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.RubyPrimary;
    return InkWell(
      onTap: onTap,
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: c),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.RubyTextSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: c,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w900,
          color: AppTheme.RubyTextPrimary,
        ),
      ),
    );
  }
}

/// ورودی مبلغ تومانی با جداکنندهٔ هزارگان
class TomanField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const TomanField({
    super.key,
    required this.controller,
    required this.label,
    this.icon = Icons.payments_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixText: 'تومان',
      ),
    );
  }
}

void showStoreSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? AppTheme.RubyError : AppTheme.RubySuccess,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'تأیید',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.RubyError),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}
