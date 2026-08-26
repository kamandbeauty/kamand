import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/jalali_helper.dart';
import '../providers/store_providers.dart';
import '../shipments/shipment_repository.dart';
import '../store_core.dart';
import 'store_ui_helpers.dart';

/// کدهای رهگیری ارسال — ورود گروهی برای ده‌ها سفارش از یک صفحه
/// بدون هیچ فیلد آدرس؛ ثبت رهگیری فقط عملیاتی است (نه مالی/موجودی)
class ShipmentTrackingScreen extends ConsumerStatefulWidget {
  const ShipmentTrackingScreen({super.key});

  @override
  ConsumerState<ShipmentTrackingScreen> createState() =>
      _ShipmentTrackingScreenState();
}

class _ShipmentTrackingScreenState
    extends ConsumerState<ShipmentTrackingScreen> {
  String _search = '';
  String _filter = ShipmentFilter.all;
  List<ShipmentRow> _rows = [];
  final Map<String, TextEditingController> _codeCtrls = {};
  final Map<String, TextEditingController> _dateCtrls = {};
  final Map<String, String> _providers = {};
  final Set<String> _dirty = {}; // ردیف‌های تغییریافته
  final Map<String, String> _errors = {}; // خطای هر ردیف (فارسی)
  final Set<String> _selected = {}; // انتخاب برای اشتراک‌گذاری گروهی
  bool _loading = true;

  @override
  void dispose() {
    for (final c in _codeCtrls.values) {
      c.dispose();
    }
    for (final c in _dateCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncControllers() {
    final today = JalaliHelper.getTodayJalali();
    for (final r in _rows) {
      _codeCtrls.putIfAbsent(
          r.orderId, () => TextEditingController(text: r.trackingCode));
      _dateCtrls.putIfAbsent(r.orderId,
          () => TextEditingController(text: r.shippedAt.isEmpty ? today : r.shippedAt));
      _providers.putIfAbsent(r.orderId,
          () => r.provider.isEmpty ? ShipmentProviders.list.first : r.provider);
    }
  }

  Future<void> _reload(StoreCore core) async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    try {
      final rows =
          core.shipments.rows(search: _search.isEmpty ? null : _search, filter: _filter);
      setState(() {
        _rows = rows;
        _syncControllers();
        _loading = false;
        _dirty.clear();
        _errors.clear();
      });
    } catch (e) {
      setState(() => _loading = false);
      showStoreSnack(context, 'خطا در بارگذاری سفارش‌ها: $e', error: true);
    }
  }

  void _markDirty(String orderId) {
    _dirty.add(orderId);
    _errors.remove(orderId);
  }

  /// ثبت اطلاعات ارسال — اعتبارسنجی همهٔ ردیف‌های تغییریافته، سپس ذخیرهٔ تراکنشی
  Future<void> _saveAll(StoreCore core) async {
    if (_dirty.isEmpty) {
      showStoreSnack(context, 'تغییری برای ثبت وجود ندارد');
      return;
    }
    final items = <TrackingInput>[];
    for (final id in _dirty) {
      items.add(TrackingInput(
        orderId: id,
        trackingCode: _codeCtrls[id]?.text ?? '',
        provider: _providers[id] ?? '',
        shippedAt: _dateCtrls[id]?.text ?? '',
      ));
    }
    // اعتبارسنجی کامل قبل از هر نوشتن — نامعتبر = هیچ ذخیره‌ای
    final errors = core.shipments.validate(items);
    if (errors.isNotEmpty) {
      setState(() {
        _errors
          ..clear()
          ..addAll(errors);
      });
      showStoreSnack(
          context,
          '${errors.length} ردیف نامعتبر است — ردیف‌های مشخص‌شده را اصلاح کنید '
          '(ردیف‌های معتبر هم ذخیره نمی‌شوند تا یکجا و تراکنشی ذخیره شود)',
          error: true);
      return;
    }
    try {
      final saved = core.shipments.bulkSave(items);
      showStoreSnack(context, 'اطلاعات ارسال $saved سفارش ثبت شد');
      await _reload(core);
    } on ArgumentError catch (e) {
      showStoreSnack(context, '${e.message ?? e}', error: true);
    } catch (e) {
      showStoreSnack(context, 'خطای دیتابیس — چیزی ذخیره نشد: $e', error: true);
    }
  }

  Future<void> _shareOne(ShipmentRow r, StoreCore core) async {
    final msg = core.shipments.generateMessage(r);
    await Share.share(msg, subject: 'کد رهگیری سفارش');
  }

  Future<void> _smsOne(ShipmentRow r, StoreCore core) async {
    if (!r.hasPhone) {
      showStoreSnack(context, 'شماره موبایل مشتری ثبت نشده است.', error: true);
      return;
    }
    final msg = core.shipments.generateMessage(r);
    final uri = Uri(scheme: 'sms', path: r.customerPhone, query: 'body=$msg');
    try {
      await launchUrl(uri);
    } catch (_) {
      showStoreSnack(context, 'امکان باز کردن پیامک‌رسان وجود ندارد',
          error: true);
    }
  }

  Future<void> _bulkShare(StoreCore core) async {
    if (_selected.isEmpty) {
      showStoreSnack(context, 'حداقل یک سفارش را انتخاب کنید');
      return;
    }
    // پیام هر مشتری/سفارش جدا — بدون ادغام
    final messages = <String>[];
    var noPhone = 0;
    for (final r in _rows) {
      if (_selected.contains(r.orderId)) {
        if (r.trackingCode.isEmpty) {
          noPhone++; // کد رهگیری ندارد → پیامک نیست
          continue;
        }
        messages.add(core.shipments.generateMessage(r));
      }
    }
    if (messages.isEmpty) {
      showStoreSnack(context, 'سفارش‌های انتخاب‌شده کد رهگیری ثبت‌شده ندارند',
          error: true);
      return;
    }
    await Share.share(messages.join('\n\n———\n\n'),
        subject: 'کدهای رهگیری سفارش‌ها');
    if (noPhone > 0) {
      showStoreSnack(context, '$noPhone سفارش بدون کد رهگیری نادیده گرفته شد');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreScaffold(
      title: 'کدهای رهگیری ارسال',
      fab: FloatingActionButton.extended(
        onPressed: () async {
          final core = await ref.read(storeCoreProvider.future);
          _saveAll(core);
        },
        icon: const Icon(Icons.save),
        label: const Text('ثبت اطلاعات ارسال'),
      ),
      body: (core) {
        if (_loading) {
          _reload(core);
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: TextField(
                onChanged: (v) {
                  _search = v;
                  _reload(core);
                },
                decoration: const InputDecoration(
                  labelText: 'جستجوی نام مشتری...',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                children: [
                  for (final e in ShipmentFilter.labels.entries)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(e.value, style: const TextStyle(fontSize: 11)),
                        selected: _filter == e.key,
                        onSelected: (_) {
                          setState(() => _filter = e.key);
                          _reload(core);
                        },
                      ),
                    ),
                ],
              ),
            ),
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                          '${_selected.length} سفارش انتخاب شده',
                          style: const TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w800)),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.select_all, size: 18),
                      label: const Text('پاک‌سازی انتخاب', style: TextStyle(fontSize: 11)),
                      onPressed: () => setState(() => _selected.clear()),
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          visualDensity: VisualDensity.compact),
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('اشتراک‌گذاری کدهای رهگیری',
                          style: TextStyle(fontSize: 11)),
                      onPressed: () => _bulkShare(core),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _rows.isEmpty
                  ? const Center(
                      child: Text('سفارشی با این شرایط نیست',
                          style: TextStyle(color: AppTheme.RubyTextSecondary)),
                    )
                  : ListView.builder(
                      itemCount: _rows.length,
                      itemBuilder: (_, i) => _rowCard(core, _rows[i]),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _rowCard(StoreCore core, ShipmentRow r) {
    final err = _errors[r.orderId];
    final sel = _selected.contains(r.orderId);
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: sel,
                    onChanged: (v) => setState(() {
                      v == true ? _selected.add(r.orderId) : _selected.remove(r.orderId);
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${r.customerName} — فاکتور #${r.orderNumber.isEmpty ? r.orderId.substring(0, 8) : r.orderNumber}',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
                  ),
                ),
                _statusChip(r),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _codeCtrls[r.orderId],
                    onChanged: (_) => _markDirty(r.orderId),
                    decoration: const InputDecoration(
                        labelText: 'کد رهگیری', isDense: true),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _dateCtrls[r.orderId],
                    onChanged: (_) => _markDirty(r.orderId),
                    decoration: const InputDecoration(
                        labelText: 'تاریخ ارسال', isDense: true),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _providers[r.orderId],
                    items: [
                      for (final p in ShipmentProviders.list)
                        DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 11.5))),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _providers[r.orderId] = v ?? _providers[r.orderId]!;
                        _markDirty(r.orderId);
                      });
                    },
                    decoration:
                        const InputDecoration(labelText: 'روش ارسال', isDense: true),
                  ),
                ),
              ],
            ),
            if (err != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '⚠ $err',
                  style: const TextStyle(
                      color: AppTheme.RubyError,
                      fontSize: 11,
                      fontWeight: FontWeight.w800),
                ),
              ),
            if (r.trackingCode.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _smsOne(r, core),
                      icon: const Icon(Icons.sms_outlined,
                          size: 16, color: AppTheme.RubyPrimary),
                      label: const Text('ارسال پیامک',
                          style: TextStyle(fontSize: 11)),
                    ),
                    TextButton.icon(
                      onPressed: () => _shareOne(r, core),
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('ارسال کد رهگیری',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(ShipmentRow r) {
    late final Color c;
    switch (r.derivedStatus) {
      case 'shipped':
        c = AppTheme.RubySuccess;
        break;
      case 'no_code':
        c = AppTheme.RubyWarning;
        break;
      default:
        c = Colors.blueGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(r.derivedStatusLabel,
          style: TextStyle(
              fontSize: 9.5, fontWeight: FontWeight.w900, color: c)),
    );
  }
}
