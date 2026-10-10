import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_number_formatter.dart';
import '../../core/utils/thousand_separator_formatter.dart';
import '../../models/business_profile_model.dart';
import '../../models/invoice_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/invoice_provider.dart';
import '../../providers/bank_card_provider.dart';
import '../dashboard/dashboard_screen.dart';

const _orange = AppTheme.RubyPrimary;
const _slate400 = Color(0xFF94A3B8);
const _slate500 = Color(0xFF64748B);
const _slate700 = Color(0xFF334155);
const _slate800 = Color(0xFF1E293B);
const _cardGray = Color(0xFFF1F5F9);

/// صفحه نمایش فاکتور بعد از ذخیره — با ارسال PDF / عکس و منوی اشتراک
class InvoicePreviewScreen extends ConsumerStatefulWidget {
  final InvoiceModel invoice;
  const InvoicePreviewScreen({super.key, required this.invoice});

  @override
  ConsumerState<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends ConsumerState<InvoicePreviewScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _busy = false;

  InvoiceModel get inv {
    // build() در ابتدای خودش invoiceListProvider را watch می‌کند؛ اینجا که از
    // متدهای غیر-build هم صدا زده می‌شود فقط باید read شود.
    final list = ref.read(invoiceListProvider);
    for (final e in list) {
      if (e.id == widget.invoice.id) return e;
    }
    return widget.invoice;
  }

  String get _typeTitle {
    if (inv.isOfficial) return 'صورتحساب رسمی فروش کالا و خدمات';
    switch (inv.type) {
      case 'proforma':
        return 'پیش فاکتور';
      case 'purchase':
        return 'فاکتور خرید';
      default:
        return 'فاکتور فروش';
    }
  }

  String _shareText() {
    final biz = ref.read(businessProvider);
    return [
      '$_typeTitle #${PersianNumberFormatter.toPersian(inv.number)}',
      'فروشگاه: ${biz.shopName}',
      'مشتری: ${inv.customerName}',
      if (inv.customerPhone.isNotEmpty) 'موبایل: ${inv.customerPhone}',
      'تاریخ: ${PersianNumberFormatter.toPersian(inv.date)}',
      'مبلغ: ${PersianNumberFormatter.formatCurrency(inv.totalAmount)}',
      if (inv.notes.isNotEmpty) 'توضیحات: ${inv.notes}',
      '',
      '— فاکتور ساز روبی',
    ].join('\n');
  }

  Future<Uint8List?> _capturePng() async {
    try {
      final boundary =
          _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null || boundary.size.isEmpty) return null;
      // Keep the longest output edge around 4096 px to avoid GPU/OOM errors
      // for invoices containing many rows while retaining print quality.
      final longestEdge = math.max(boundary.size.width, boundary.size.height);
      final pixelRatio = (4096 / longestEdge).clamp(0.25, 3.0).toDouble();
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        return byteData?.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } catch (e) {
      debugPrint('capture error: $e');
      return null;
    }
  }

  Future<void> _shareImage() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ساخت تصویر فاکتور ناموفق بود')),
          );
        }
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/factor_${inv.number}_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png', name: 'factor-${inv.number}.png')],
        text: _shareText(),
        subject: '$_typeTitle ${inv.number}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در اشتراک تصویر: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  /// فقط تصویر ناحیه فاکتور (نه کل صفحه/دکمه‌ها) را در گالری ذخیره می‌کند
  Future<void> _saveInvoiceToGallery() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ساخت تصویر فاکتور ناموفق بود')),
          );
        }
        return;
      }
      // درخواست دسترسی و ذخیره فقط بایت‌های فاکتور
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('دسترسی گالری داده نشد')),
            );
          }
          return;
        }
      }
      await Gal.putImageBytes(
        bytes,
        name: 'factor_${inv.number}_${DateTime.now().microsecondsSinceEpoch}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('فاکتور در گالری ذخیره شد')),
        );
      }
    } catch (e) {
      // fallback: share file if gal fails
      try {
        final bytes = await _capturePng();
        if (bytes != null) {
          final dir = await getTemporaryDirectory();
          final file = File('${dir.path}/factor_${inv.number}.png');
          await file.writeAsBytes(bytes);
          await Share.shareXFiles(
            [XFile(file.path, mimeType: 'image/png', name: 'factor-${inv.number}.png')],
            text: 'فاکتور ذخیره شود',
          );
        }
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطا در ذخیره گالری: $e')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sharePdfLike() async {

    // بدون پکیج pdf: تصویر با کیفیت بالا به‌عنوان فایل قابل اشتراک (کاربر می‌تواند PDF کند)
    // + منوی سیستم
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capturePng();
      if (bytes == null) {
        await Share.share(_shareText(), subject: '$_typeTitle ${inv.number}');
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/factor_${inv.number}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png', name: 'factor-${inv.number}-pdf.png')],
        text: '${_shareText()}\n\n(نسخه تصویری فاکتور برای چاپ/PDF)',
        subject: '$_typeTitle ${inv.number} PDF',
      );
    } catch (e) {
      await Share.share(_shareText(), subject: '$_typeTitle ${inv.number}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareTextOnly() async {
    await Share.share(_shareText(), subject: '$_typeTitle ${inv.number}');
  }

  void _openShareMenu() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = Color(ref.read(settingsProvider).accentColor);
    showModalBottomSheet(
      context: context,
      backgroundColor: dark ? _slate800 : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: dark ? _slate700 : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'اشتراک‌گذاری فاکتور',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: dark ? Colors.white : _slate800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'فاکتور #${PersianNumberFormatter.toPersian(inv.number)} · ${PersianNumberFormatter.formatCurrency(inv.totalAmount)}',
                  style: const TextStyle(fontSize: 11, color: _slate500),
                ),
                const SizedBox(height: 16),
                _shareTile(
                  icon: Icons.image_outlined,
                  color: accent,
                  title: 'ارسال عکس فاکتور',
                  subtitle: 'اشتراک تصویر PNG',
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareImage();
                  },
                ),
                _shareTile(
                  icon: Icons.picture_as_pdf_outlined,
                  color: const Color(0xFF0EA5E9),
                  title: 'ارسال PDF',
                  subtitle: 'اشتراک فایل فاکتور برای چاپ',
                  onTap: () {
                    Navigator.pop(ctx);
                    _sharePdfLike();
                  },
                ),
                _shareTile(
                  icon: Icons.chat_bubble_outline,
                  color: _slate700,
                  title: 'اشتراک متن فاکتور',
                  subtitle: 'ارسال خلاصه متنی',
                  onTap: () {
                    Navigator.pop(ctx);
                    _shareTextOnly();
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('انصراف'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _shareTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: dark ? const Color(0xFF0F172A) : _cardGray,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: dark ? Colors.white : _slate800,
                        ),
                      ),
                      Text(subtitle, style: const TextStyle(fontSize: 11, color: _slate500)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left, color: _slate400),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _officialInfoBlock(BusinessProfileModel biz) {
    Widget infoCell(String label, String value) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          child: Text(
            '$label: ${value.trim().isEmpty ? '—' : value}',
            style: const TextStyle(fontSize: 8.5, height: 1.5),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF334155), width: 0.8),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFE2E8F0),
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: const Text(
              'مشخصات فروشنده',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
            ),
          ),
          Row(
            children: [
              infoCell(
                'نام / عنوان',
                inv.sellerName.isNotEmpty ? inv.sellerName : biz.shopName,
              ),
              infoCell('شناسه ملی', inv.sellerNationalId),
              infoCell('کد اقتصادی', inv.sellerEconomicCode),
            ],
          ),
          Row(
            children: [
              infoCell('شماره ثبت', inv.sellerRegistrationNumber),
              infoCell('کد پستی', inv.sellerPostalCode),
              infoCell(
                'تلفن',
                inv.sellerPhone.isNotEmpty ? inv.sellerPhone : biz.phone,
              ),
            ],
          ),
          Row(
            children: [
              infoCell('نشانی کامل', inv.sellerAddress),
            ],
          ),
          Container(
            width: double.infinity,
            color: const Color(0xFFE2E8F0),
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: const Text(
              'مشخصات خریدار',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
            ),
          ),
          Row(
            children: [
              infoCell('نام / عنوان', inv.customerName),
              infoCell('شناسه ملی', inv.buyerNationalId),
              infoCell('کد اقتصادی', inv.buyerEconomicCode),
            ],
          ),
          Row(
            children: [
              infoCell('کد پستی', inv.buyerPostalCode),
              infoCell('شماره تماس', inv.customerPhone),
            ],
          ),
          Row(
            children: [
              infoCell('نشانی کامل', inv.buyerAddress),
            ],
          ),
          Container(
            width: double.infinity,
            color: const Color(0xFFF8FAFC),
            child: Row(
              children: [
                infoCell(
                  'نحوه پرداخت',
                  inv.paymentType == 'cash' ? 'نقدی' : 'غیرنقدی',
                ),
                infoCell(
                  'شماره سریال',
                  PersianNumberFormatter.toPersian(inv.number),
                ),
                infoCell(
                  'تاریخ',
                  PersianNumberFormatter.toPersian(inv.date),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _officialItemsTable() {
    Widget cell(
      String text, {
      int flex = 1,
      bool header = false,
      TextAlign align = TextAlign.center,
    }) {
      return Expanded(
        flex: flex,
        child: Container(
          constraints: const BoxConstraints(minHeight: 31),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: Color(0xFF64748B), width: .5)),
          ),
          child: Text(
            text,
            textAlign: align,
            style: TextStyle(
              fontSize: header ? 7.5 : 7.2,
              fontWeight: header ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final taxableSubtotal = (inv.subtotal - inv.discountAmount)
        .clamp(0, double.infinity)
        .toDouble();
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF334155), width: .8),
      ),
      child: Column(
        children: [
          Container(
            color: const Color(0xFFE2E8F0),
            child: Row(
              children: [
                cell('ردیف', header: true),
                cell('شرح کالا / خدمت', flex: 4, header: true),
                cell('تعداد', header: true),
                cell('واحد', header: true),
                cell('فی', flex: 2, header: true),
                cell('مبلغ', flex: 2, header: true),
                cell('تخفیف', flex: 2, header: true),
                cell('مالیات', flex: 2, header: true),
                cell('جمع نهایی', flex: 2, header: true),
              ],
            ),
          ),
          ...List.generate(inv.items.length, (index) {
            final item = inv.items[index];
            final ratio = inv.subtotal > 0 ? item.totalPrice / inv.subtotal : 0.0;
            final discount = inv.discountAmount * ratio;
            final afterDiscount = (item.totalPrice - discount)
                .clamp(0, double.infinity)
                .toDouble();
            final tax = taxableSubtotal > 0
                ? inv.taxAmount * (afterDiscount / taxableSubtotal)
                : 0.0;
            final total = afterDiscount + tax;
            String money(double value) => PersianNumberFormatter
                .formatCurrency(value)
                .replaceAll(' تومان', '');
            return Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF94A3B8), width: .5)),
              ),
              child: Row(
                children: [
                  cell(PersianNumberFormatter.toPersian(index + 1)),
                  cell(item.title, flex: 4, align: TextAlign.right),
                  cell(PersianNumberFormatter.toPersian(item.quantity)),
                  cell(item.unit),
                  cell(money(item.unitPrice), flex: 2),
                  cell(money(item.totalPrice), flex: 2),
                  cell(money(discount), flex: 2),
                  cell(money(tax), flex: 2),
                  cell(money(total), flex: 2),
                ],
              ),
            );
          }),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF94A3B8), width: .5)),
            ),
            child: const Text(
              'اپلیکیشن فاکتور ساز روبی',
              textAlign: TextAlign.left,
              style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(invoiceListProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final biz = ref.watch(businessProvider);
    final settingsWatch = ref.watch(settingsProvider);
    final markPath = biz.stampPath.isNotEmpty
        ? biz.stampPath
        : biz.signaturePath;
    final showMark = settingsWatch.showStamp &&
        markPath.isNotEmpty &&
        File(markPath).existsSync();
    final accent = Color(settingsWatch.accentColor);

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: dark ? _slate800 : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: dark ? Colors.white : _slate800),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Column(
          children: [
            Text(
              '$_typeTitle #${PersianNumberFormatter.toPersian(inv.number)}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: dark ? Colors.white : _slate800,
              ),
            ),
            const Text(
              'ذخیره شد ✓',
              style: TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openShareMenu,
            icon: Icon(Icons.share, color: accent),
            tooltip: 'اشتراک‌گذاری',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: RepaintBoundary(
                key: _repaintKey,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              // اطراف لوگوی انتخاب‌شده نباید با رنگ تم پر شود؛
                              // خود تصویر (ازجمله پس‌زمینهٔ سفیدش) دست‌نخورده می‌ماند.
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              clipBehavior: Clip.antiAlias,
                              child: settingsWatch.showLogo &&
                                      biz.logoPath.isNotEmpty &&
                                      File(biz.logoPath).existsSync()
                                  ? Image.file(
                                      File(biz.logoPath),
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Text(
                                        'ف',
                                        style: TextStyle(
                                          color: accent,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 22,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      'ف',
                                      style: TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 22,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    biz.shopName.isEmpty ? 'فروشگاه روبی' : biz.shopName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (biz.phone.isNotEmpty)
                                    Text(
                                      biz.phone,
                                      style: const TextStyle(fontSize: 11, color: _slate500),
                                      textDirection: TextDirection.ltr,
                                      textAlign: TextAlign.right,
                                    ),
                                  if (biz.address.isNotEmpty)
                                    Text(
                                      biz.address,
                                      style: const TextStyle(fontSize: 11, color: _slate500, height: 1.4),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: _cardGray,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    _typeTitle,
                                    style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'شماره: ${PersianNumberFormatter.toPersian(inv.number)}',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    'تاریخ: ${PersianNumberFormatter.toPersian(inv.date)}',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (inv.isOfficial)
                          _officialInfoBlock(biz)
                        else
                          Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _cardGray,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'خریدار: ${inv.customerName.isEmpty ? 'مشتری عمومی' : inv.customerName}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                ),
                              ),
                              if (inv.customerPhone.isNotEmpty)
                                Text(
                                  inv.customerPhone,
                                  style: const TextStyle(fontSize: 11, color: _slate500),
                                  textDirection: TextDirection.ltr,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        // جدول رسمی ستون‌های مالیاتی کامل‌تری دارد.
                        if (inv.isOfficial)
                          _officialItemsTable()
                        else
                          Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                ),
                                child: const Row(
                                  children: [
                                    Expanded(flex: 3, child: Text('عنوان', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
                                    Expanded(child: Text('مقدار', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
                                    Expanded(child: Text('واحد', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
                                    Expanded(flex: 2, child: Text('فی', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
                                    Expanded(flex: 2, child: Text('جمع', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800))),
                                  ],
                                ),
                              ),
                              ...List.generate(inv.items.length, (i) {
                                final it = inv.items[i];
                                return Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(color: Colors.grey.shade200),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          '${PersianNumberFormatter.toPersian((i + 1).toString())}. ${it.title.isEmpty ? '—' : it.title}',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          PersianNumberFormatter.toPersian(
                                            it.quantity == it.quantity.roundToDouble()
                                                ? it.quantity.toInt().toString()
                                                : it.quantity.toString(),
                                          ),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          it.unit,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 10, color: _slate500),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          PersianNumberFormatter.formatCurrency(it.unitPrice)
                                              .replaceAll(' تومان', ''),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          PersianNumberFormatter.formatCurrency(it.totalPrice)
                                              .replaceAll(' تومان', ''),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              // برند روبی داخل بدنه فاکتور و زیر آخرین ردیف
                              // کالا قرار می‌گیرد و وابسته به نمایش کارت نیست.
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.fromLTRB(6, 6, 6, 7),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: Colors.grey.shade200),
                                  ),
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'اپلیکیشن فاکتور ساز روبی',
                                      textAlign: TextAlign.left,
                                      textDirection: TextDirection.rtl,
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _totalRow('جمع اقلام', inv.subtotal),
                        if (inv.discountAmount > 0)
                          _totalRow(
                            inv.discountPercent > 0
                                ? 'تخفیف (${PersianNumberFormatter.toPersian(inv.discountPercent.toStringAsFixed(0))}٪)'
                                : 'تخفیف',
                            -inv.discountAmount,
                            color: const Color(0xFF059669),
                          ),
                        if (inv.shippingFee > 0) _totalRow('هزینه ارسال', inv.shippingFee),
                        if (inv.isOfficial && inv.taxAmount > 0)
                          _totalRow(
                            'مالیات و عوارض (${PersianNumberFormatter.toPersian(inv.taxRate)}٪)',
                            inv.taxAmount,
                            color: const Color(0xFFD97706),
                          ),
                        if (inv.previousDebt > 0)
                          _totalRow('بدهی قبلی', inv.previousDebt, color: const Color(0xFFE11D48)),
                        if (inv.deposit > 0)
                          _totalRow('بیعانه', -inv.deposit, color: const Color(0xFF0284C7)),
                        const Divider(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'مبلغ قابل پرداخت',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                            ),
                            Text(
                              PersianNumberFormatter.formatCurrency(inv.totalAmount),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: accent,
                              ),
                            ),
                          ],
                        ),
                        if (inv.paidAmount > 0 && inv.paymentType != 'cash')
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _totalRow('پرداخت‌شده / بیعانه', inv.paidAmount, color: const Color(0xFF059669)),
                          ),
                        if (inv.remainingAmount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: _totalRow('باقی‌مانده', inv.remainingAmount, color: const Color(0xFFE11D48)),
                          ),
                        if (inv.notes.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            'توضیحات: ${inv.notes}',
                            style: const TextStyle(fontSize: 11, color: _slate500, height: 1.4),
                          ),
                        ],
                        if (inv.cardNumber.isNotEmpty &&
                            settingsWatch.showCardNum) ...[
                          const SizedBox(height: 12),
                          Builder(builder: (_) {
                            final cards = ref.watch(bankCardListProvider);
                            final selected = ref.watch(selectedBankCardProvider);
                            dynamic match = selected;
                            final digits = inv.cardNumber.replaceAll(RegExp(r'\D'), '');
                            if (match == null || match.cardNumber.replaceAll(RegExp(r'\D'), '') != digits) {
                              for (final c in cards) {
                                if (c.cardNumber.replaceAll(RegExp(r'\D'), '') == digits) {
                                  match = c;
                                  break;
                                }
                              }
                            }
                            final bankName = (inv.cardBank.isNotEmpty
                                    ? inv.cardBank
                                    : (match?.bankName?.toString() ?? detectBankName(inv.cardNumber)));
                            final ownerName = inv.cardOwner.isNotEmpty
                                ? inv.cardOwner
                                : (match?.persianName?.toString() ?? '');
                            final sheba = match?.spacedSheba?.toString() ?? '';
                            final grouped = formatCardGrouped(inv.cardNumber);
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F9FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFBAE6FD)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Row(
                                    textDirection: TextDirection.rtl,
                                    children: [
                                      Icon(
                                        Icons.credit_card,
                                        color: Color(0xFF0284C7),
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'شماره کارت جهت واریز',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF0284C7),
                                          fontWeight: FontWeight.w700,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ],
                                  ),
                                  if (bankName.isNotEmpty || ownerName.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      textDirection: TextDirection.rtl,
                                      children: [
                                        if (bankName.isNotEmpty)
                                          Text(
                                            bankName,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        if (bankName.isNotEmpty && ownerName.isNotEmpty)
                                          const Text('  ·  ', style: TextStyle(color: Color(0xFF94A3B8))),
                                        if (ownerName.isNotEmpty)
                                          Text(
                                            ownerName,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF334155),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  // شماره کارت گروه‌بندی ۴تایی — LTR برای جلوگیری از برعکس شدن
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: Text(
                                        grouped,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                          letterSpacing: 1.1,
                                          color: Color(0xFF0F172A),
                                          fontFeatures: [ui.FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (sheba.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      textDirection: TextDirection.rtl,
                                      children: [
                                        const Text(
                                          'شماره شبا:',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0284C7),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Directionality(
                                            textDirection: TextDirection.ltr,
                                            child: Text(
                                              sheba,
                                              textAlign: TextAlign.right,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF334155),
                                                fontFeatures: [ui.FontFeature.tabularFigures()],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }),
                        ],
                        if (inv.isOfficial) ...[
                          const SizedBox(height: 22),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    const SizedBox(height: 68),
                                    Container(height: 1, color: const Color(0xFFCBD5E1)),
                                    const SizedBox(height: 5),
                                    const Text(
                                      'نام، مهر و امضای خریدار',
                                      style: TextStyle(fontSize: 8, color: _slate500),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 32),
                              Expanded(
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 68,
                                      child: showMark
                                          ? Image.file(
                                              File(markPath),
                                              height: 64,
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, __, ___) =>
                                                  const SizedBox.shrink(),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                    Container(height: 1, color: const Color(0xFFCBD5E1)),
                                    const SizedBox(height: 5),
                                    const Text(
                                      'نام، مهر و امضای فروشنده',
                                      style: TextStyle(fontSize: 8, color: _slate500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ] else if (showMark) ...[
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 160,
                              child: Column(
                                children: [
                                  Image.file(
                                    File(markPath),
                                    height: 64,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'مهر و امضا',
                                    style: TextStyle(fontSize: 9, color: _slate400),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Bottom actions
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: dark ? _slate800 : Colors.white,
                border: Border(top: BorderSide(color: dark ? _slate700 : const Color(0xFFE2E8F0))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _busy ? null : _shareImage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            icon: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.image_outlined, size: 20),
                            label: const Text(
                              'ارسال عکس فاکتور',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _busy ? null : _sharePdfLike,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0EA5E9),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                            label: const Text(
                              'ارسال PDF',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _saveInvoiceToGallery,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: dark ? Colors.white : _slate800,
                        side: BorderSide(color: dark ? _slate700 : const Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.save_alt, size: 18),
                      label: const Text(
                        'ذخیره فاکتور در گالری',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _openShareMenu,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: dark ? Colors.white : _slate800,
                        side: BorderSide(color: dark ? _slate700 : const Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text(
                        'منوی اشتراک‌گذاری فاکتور',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          // ویرایش در همان فرم هوم/داشبورد
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => DashboardScreen(editInvoice: inv),
                            ),
                            (route) => false,
                          );
                        },
                        child: const Text('ویرایش', style: TextStyle(fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _shareText()));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('متن فاکتور کپی شد')),
                          );
                        },
                        child: const Text('کپی متن', style: TextStyle(fontSize: 12)),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('بستن', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double amount, {Color? color}) {
    final isNeg = amount < 0;
    final c = color ?? _slate700;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
          Text(
            '${isNeg ? '− ' : ''}${PersianNumberFormatter.formatCurrency(amount.abs())}',
            style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
