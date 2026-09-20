import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/jalali_helper.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../core/utils/thousand_separator_formatter.dart';
import '../../models/expense_model.dart';
import '../../providers/expense_provider.dart';

const _orange = AppTheme.RubyPrimary;
const _slate400 = Color(0xFF94A3B8);
const _slate500 = Color(0xFF64748B);
const _slate700 = Color(0xFF334155);
const _slate800 = Color(0xFF1E293B);

const List<String> expenseCategories = [
  'اجاره',
  'حقوق',
  'حمل و نقل',
  'خرید کالا',
  'تبلیغات',
  'قبوض',
  'تعمیرات',
  'سایر',
];

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  String _selectedCategory = 'همه';

  Future<void> _showExpenseForm({ExpenseModel? expense}) async {
    final titleCtrl = TextEditingController(text: expense?.title ?? '');
    final amountCtrl = TextEditingController(text: expense != null ? expense.amount.toInt().toString() : '');
    final notesCtrl = TextEditingController(text: expense?.notes ?? '');
    String category = expense?.category ?? 'سایر';
    String date = expense?.date ?? JalaliHelper.getTodayJalali();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).viewPadding.bottom + 20),
        child: StatefulBuilder(
          builder: (ctx, setModal) => SingleChildScrollView(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 14),
                  Text(expense == null ? 'ثبت هزینه جدید' : 'ویرایش هزینه', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 18),
                  TextField(
                    controller: titleCtrl,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(labelText: 'عنوان هزینه *', hintText: 'مثل اجاره مغازه', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.right,
                    inputFormatters: [ThousandSeparatorInputFormatter(allowDecimal: false), FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹,]'))],
                    decoration: const InputDecoration(labelText: 'مبلغ *', border: OutlineInputBorder(), suffixText: 'تومان'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'دسته‌بندی', border: OutlineInputBorder()),
                    items: expenseCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setModal(() => category = v ?? 'سایر'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'توضیحات', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  Text('تاریخ: ${PersianNumberFormatter.toPersian(date)}', style: const TextStyle(fontSize: 12, color: _slate500)),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        if (titleCtrl.text.trim().isEmpty || amountCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('عنوان و مبلغ را وارد کنید')));
                          return;
                        }
                        Navigator.pop(ctx, true);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: Text(expense == null ? 'ثبت هزینه' : 'ذخیره تغییرات', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (saved == true) {
      final amount = ThousandSeparatorInputFormatter.parseToDouble(amountCtrl.text) ?? 0;
      if (expense == null) {
        await ref.read(expenseListProvider.notifier).addExpense(
          ExpenseModel(
            id: 'exp-${DateTime.now().millisecondsSinceEpoch}',
            title: titleCtrl.text.trim(),
            amount: amount,
            category: category,
            date: date,
            notes: notesCtrl.text.trim(),
            invoiceId: '',
            createdAt: date,
          ),
        );
      } else {
        ref.read(expenseListProvider.notifier).updateExpense(
          expense.copyWith(title: titleCtrl.text.trim(), amount: amount, category: category, notes: notesCtrl.text.trim()),
        );
      }
    }

    titleCtrl.dispose();
    amountCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _deleteExpense(ExpenseModel e) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف هزینه'),
        content: Text('«${e.title}» حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(expenseListProvider.notifier).deleteExpense(e.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expenseListProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _selectedCategory == 'همه' ? expenses : expenses.where((e) => e.category == _selectedCategory).toList();
    final total = filtered.fold<double>(0, (s, e) => s + e.amount);
    final summary = ref.read(expenseListProvider.notifier).categorySummary;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F172A) : const Color(0xFFFFFBEB),
      appBar: AppBar(
        title: const Text('مدیریت هزینه‌ها'),
        backgroundColor: dark ? _slate800 : Colors.white,
        foregroundColor: dark ? Colors.white : _slate800,
        elevation: 0,
      ),
      body: Column(
        children: [
          // خلاصه
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [const Color(0xFFF97316), const Color(0xFFEA580C)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('جمع کل هزینه‌ها', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(PersianNumberFormatter.formatCurrency(total), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                  child: Text('${PersianNumberFormatter.toPersian(filtered.length.toString())} مورد', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ],
            ),
          ),
          // فیلتر دسته
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _categoryChip('همه', _selectedCategory == 'همه'),
                ...expenseCategories.map((c) => _categoryChip(c, _selectedCategory == c)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // دسته‌بندی‌ها
          if (summary.isNotEmpty && _selectedCategory == 'همه')
            Container(
              height: 80,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                children: summary.entries.map((e) {
                  return Container(
                    width: 120,
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: dark ? _slate800 : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.key, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _slate500)),
                        const Spacer(),
                        Text(PersianNumberFormatter.formatCurrency(e.value).replaceAll(' تومان', ''), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: dark ? Colors.white : _slate800)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text('هزینه‌ای ثبت نشده', style: TextStyle(color: _slate500, fontWeight: FontWeight.w700)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final e = filtered.reversed.toList()[i];
                      return Card(
                        color: dark ? _slate800 : Colors.white,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: const Color(0xFFFFEDD5), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.payments_outlined, color: _orange, size: 20),
                          ),
                          title: Text(e.title, style: TextStyle(fontWeight: FontWeight.w800, color: dark ? Colors.white : _slate800)),
                          subtitle: Text('${e.category} • ${PersianNumberFormatter.toPersian(e.date)}', style: const TextStyle(fontSize: 11, color: _slate500)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(PersianNumberFormatter.formatCurrency(e.amount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFFE11D48))),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(onTap: () => _showExpenseForm(expense: e), child: const Icon(Icons.edit_outlined, size: 18, color: _slate400)),
                                  const SizedBox(width: 8),
                                  InkWell(onTap: () => _deleteExpense(e), child: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseForm(),
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('افزودن هزینه', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _categoryChip(String label, bool selected) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: selected ? Colors.white : _slate700)),
        selected: selected,
        selectedColor: _orange,
        backgroundColor: Colors.white,
        onSelected: (_) => setState(() => _selectedCategory = label),
      ),
    );
  }
}
