import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/jalali_helper.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../models/supplier_model.dart';
import '../../providers/supplier_provider.dart';
import 'supplier_detail_screen.dart';

const _orange = AppTheme.RubyPrimary;
const _slate400 = Color(0xFF94A3B8);
const _slate500 = Color(0xFF64748B);
const _slate700 = Color(0xFF334155);
const _slate800 = Color(0xFF1E293B);

class SupplierListScreen extends ConsumerStatefulWidget {
  const SupplierListScreen({super.key});

  @override
  ConsumerState<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends ConsumerState<SupplierListScreen> {
  String _search = '';

  Future<void> _showSupplierForm({SupplierModel? supplier}) async {
    final nameCtrl = TextEditingController(text: supplier?.name ?? '');
    final phoneCtrl = TextEditingController(text: supplier?.phone ?? '');
    final mobileCtrl = TextEditingController(text: supplier?.mobile ?? '');
    final addressCtrl = TextEditingController(text: supplier?.address ?? '');
    final notesCtrl = TextEditingController(text: supplier?.notes ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20, 18, 20,
          MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).viewPadding.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  supplier == null ? 'افزودن تامین‌کننده' : 'ویرایش تامین‌کننده',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: nameCtrl,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(labelText: 'نام تامین‌کننده *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: mobileCtrl,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(labelText: 'موبایل', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(labelText: 'تلفن ثابت', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(labelText: 'آدرس', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'یادداشت', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('نام را وارد کنید')));
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: _orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: Text(supplier == null ? 'ذخیره تامین‌کننده' : 'ذخیره تغییرات', style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (saved == true) {
      if (supplier == null) {
        await ref.read(supplierListProvider.notifier).addSupplier(
          SupplierModel(
            id: 'sup-${DateTime.now().millisecondsSinceEpoch}',
            name: nameCtrl.text.trim(),
            phone: phoneCtrl.text.trim(),
            mobile: mobileCtrl.text.trim(),
            address: addressCtrl.text.trim(),
            notes: notesCtrl.text.trim(),
            balance: 0,
            createdAt: JalaliHelper.getTodayJalali(),
          ),
        );
      } else {
        ref.read(supplierListProvider.notifier).updateSupplier(
          supplier.copyWith(
            name: nameCtrl.text.trim(),
            phone: phoneCtrl.text.trim(),
            mobile: mobileCtrl.text.trim(),
            address: addressCtrl.text.trim(),
            notes: notesCtrl.text.trim(),
          ),
        );
      }
    }

    nameCtrl.dispose();
    phoneCtrl.dispose();
    mobileCtrl.dispose();
    addressCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _deleteSupplier(SupplierModel s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('حذف تامین‌کننده'),
        content: Text('«${s.name}» حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(c, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(supplierListProvider.notifier).deleteSupplier(s.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suppliers = ref.watch(supplierListProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _search.trim().isEmpty
        ? suppliers
        : suppliers.where((s) {
            final q = _search.toLowerCase();
            return s.name.toLowerCase().contains(q) || s.phone.contains(q) || s.mobile.contains(q);
          }).toList();

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F172A) : const Color(0xFFFFFBEB),
      appBar: AppBar(
        title: const Text('تامین‌کنندگان'),
        backgroundColor: dark ? _slate800 : Colors.white,
        foregroundColor: dark ? Colors.white : _slate800,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'جستجوی تامین‌کننده...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: dark ? _slate800 : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text('تامین‌کننده‌ای ثبت نشده', style: TextStyle(color: _slate500, fontWeight: FontWeight.w700)))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final s = filtered[i];
                      return Card(
                        color: dark ? _slate800 : Colors.white,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFFFEDD5),
                            foregroundColor: _orange,
                            child: Text(s.name.isEmpty ? 'ت' : s.name[0], style: const TextStyle(fontWeight: FontWeight.w900)),
                          ),
                          title: Text(s.name, style: TextStyle(fontWeight: FontWeight.w800, color: dark ? Colors.white : _slate800)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (s.mobile.isNotEmpty || s.phone.isNotEmpty)
                                Text(s.mobile.isNotEmpty ? s.mobile : s.phone, textDirection: TextDirection.ltr, style: const TextStyle(fontSize: 11, color: _slate500)),
                              Text(
                                s.balance > 0
                                    ? 'بدهی: ${PersianNumberFormatter.formatCurrency(s.balance)}'
                                    : 'تسویه شده',
                                style: TextStyle(
                                  fontSize: s.balance > 0 ? 11 : 10,
                                  color: s.balance > 0 ? Colors.redAccent : const Color(0xFF059669),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton(
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'detail', child: Text('کارت حساب')),
                              const PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                              const PopupMenuItem(value: 'delete', child: Text('حذف')),
                            ],
                            onSelected: (v) {
                              if (v == 'detail') {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => SupplierDetailScreen(supplier: s)));
                              }
                              if (v == 'edit') _showSupplierForm(supplier: s);
                              if (v == 'delete') _deleteSupplier(s);
                            },
                          ),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => SupplierDetailScreen(supplier: s)));
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSupplierForm(),
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('افزودن تامین‌کننده', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}
