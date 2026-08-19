import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../models/product_model.dart';
import '../../providers/product_provider.dart';

const _orange = AppTheme.RubyPrimary;
const _slate400 = Color(0xFF94A3B8);
const _slate500 = Color(0xFF64748B);
const _slate700 = Color(0xFF334155);
const _slate800 = Color(0xFF1E293B);

class ProductListScreen extends ConsumerWidget {
  const ProductListScreen({super.key});

  String _englishDigits(String value) {
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    var result = value;
    for (var i = 0; i < fa.length; i++) {
      result = result.replaceAll(fa[i], '$i');
    }
    return result;
  }

  double _number(String value) {
    return double.tryParse(_englishDigits(value).replaceAll(',', '').trim()) ?? 0;
  }

  String _nextCode(List<ProductModel> products) {
    var max = 100;
    for (final product in products) {
      final code = int.tryParse(_englishDigits(product.code).trim());
      if (code != null && code > max) max = code;
    }
    return (max + 1).toString();
  }

  Future<void> _showProductForm(
    BuildContext context,
    WidgetRef ref, {
    ProductModel? product,
  }) async {
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final codeCtrl = TextEditingController(text: product?.code ?? '');
    final unitCtrl = TextEditingController(text: product?.unit ?? 'عدد');
    final buyCtrl = TextEditingController(text: product?.buyPrice.toString() ?? '');
    final sellCtrl = TextEditingController(text: product?.sellPrice.toString() ?? '');
    final stockCtrl = TextEditingController(text: product?.stock.toString() ?? '0');
    final notesCtrl = TextEditingController(text: product?.notes ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Text(
                    product == null ? 'درج محصول جدید' : 'ویرایش محصول',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'نام محصول یا خدمت *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: unitCtrl,
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(
                            labelText: 'واحد',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: codeCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(
                            labelText: 'کد محصول',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: sellCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(
                            labelText: 'قیمت فروش',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: buyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.right,
                          decoration: const InputDecoration(
                            labelText: 'قیمت خرید',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: stockCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'موجودی',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 2,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'توضیحات',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(content: Text('نام محصول را وارد کنید')),
                          );
                          return;
                        }
                        final code = codeCtrl.text.trim().isEmpty
                            ? _nextCode(ref.read(productListProvider))
                            : _englishDigits(codeCtrl.text.trim());
                        final item = ProductModel(
                          id: product?.id ?? 'p-${DateTime.now().millisecondsSinceEpoch}',
                          code: code,
                          name: name,
                          unit: unitCtrl.text.trim().isEmpty ? 'عدد' : unitCtrl.text.trim(),
                          buyPrice: _number(buyCtrl.text),
                          sellPrice: _number(sellCtrl.text),
                          stock: _number(stockCtrl.text),
                          notes: notesCtrl.text.trim(),
                        );
                        if (product == null) {
                          ref.read(productListProvider.notifier).addProduct(item);
                        } else {
                          ref.read(productListProvider.notifier).updateProduct(item);
                        }
                        Navigator.pop(sheetContext, true);
                      },
                      icon: Icon(product == null ? Icons.add : Icons.check),
                      label: Text(product == null ? 'درج محصول' : 'ذخیره تغییرات'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    nameCtrl.dispose();
    codeCtrl.dispose();
    unitCtrl.dispose();
    buyCtrl.dispose();
    sellCtrl.dispose();
    stockCtrl.dispose();
    notesCtrl.dispose();

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(product == null ? 'محصول درج شد' : 'محصول ویرایش شد')),
      );
    }
  }

  void _copyProduct(BuildContext context, WidgetRef ref, ProductModel product) {
    final copy = ProductModel(
      id: 'p-${DateTime.now().millisecondsSinceEpoch}-copy',
      code: _nextCode(ref.read(productListProvider)),
      name: product.name,
      unit: product.unit,
      buyPrice: product.buyPrice,
      sellPrice: product.sellPrice,
      stock: product.stock,
      notes: product.notes,
    );
    ref.read(productListProvider.notifier).addProduct(copy);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('محصول کپی شد')),
    );
  }

  Future<void> _deleteProduct(BuildContext context, WidgetRef ref, ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف محصول'),
        content: Text('محصول «${product.name}» حذف شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    ref.read(productListProvider.notifier).deleteProduct(product.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('محصول حذف شد')),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productListProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F172A) : const Color(0xFFFFFBEB),
      appBar: AppBar(
        title: const Text('مدیریت کالاها و خدمات'),
      ),
      body: products.isEmpty
          ? Center(
              child: Text(
                'هنوز محصولی ثبت نشده است',
                style: TextStyle(color: dark ? _slate400 : _slate500, fontWeight: FontWeight.w700),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: products.length,
              itemBuilder: (ctx, idx) {
                final product = products[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: dark ? _slate800 : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.lightBlueBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              PersianNumberFormatter.toPersian(product.code),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                            ),
                          ),
                          title: Text(
                            product.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: dark ? Colors.white : _slate800,
                            ),
                          ),
                          subtitle: Text(
                            'موجودی: ${PersianNumberFormatter.toPersian(product.stock)} ${product.unit}\nقیمت فروش: ${PersianNumberFormatter.formatCurrency(product.sellPrice)}',
                            style: const TextStyle(fontSize: 11, color: _slate500),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 5,
                            runSpacing: 5,
                            children: [
                              _actionButton(
                                label: 'کپی',
                                icon: Icons.copy_outlined,
                                color: Colors.blue,
                                onPressed: () => _copyProduct(context, ref, product),
                              ),
                              _actionButton(
                                label: 'ویرایش',
                                icon: Icons.edit_outlined,
                                color: Colors.teal,
                                onPressed: () => _showProductForm(context, ref, product: product),
                              ),
                              _actionButton(
                                label: 'حذف',
                                icon: Icons.delete_outline,
                                color: Colors.redAccent,
                                onPressed: () => _deleteProduct(context, ref, product),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductForm(context, ref),
        backgroundColor: _orange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('درج محصول', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}
