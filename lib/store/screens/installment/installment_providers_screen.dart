import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../installments/installment_repository.dart';
import '../../providers/store_providers.dart';
import '../../store_core.dart';
import '../store_ui_helpers.dart';

/// پیکربندی سیستم‌های اقساطی (§21–§25) — هیچ نرخی hard-code نیست؛
/// همهٔ اعداد طبق قرارداد واقعی فروشنده تنظیم می‌شوند.
class InstallmentProvidersScreen extends ConsumerStatefulWidget {
  const InstallmentProvidersScreen({super.key});

  @override
  ConsumerState<InstallmentProvidersScreen> createState() =>
      _InstallmentProvidersScreenState();
}

class _InstallmentProvidersScreenState
    extends ConsumerState<InstallmentProvidersScreen> {
  bool _loading = true;
  List<InstallmentProviderEntity> _providers = [];

  Future<void> _reload(StoreCore core) async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    try {
      setState(() {
        _providers = core.installments.providers();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      showStoreSnack(context, 'خطا: $e', error: true);
    }
  }

  String _typeLabel(String t) {
    switch (t) {
      case 'snapp_pay':
        return 'اسنپ‌پی';
      case 'torob_pay':
        return 'ترب‌پی';
      case 'digipay':
        return 'دیجی‌پی';
      case 'tara':
        return 'تارا';
      case 'basalam':
        return 'باسلام';
      case 'store':
        return 'مستقیم فروشگاه';
      default:
        return 'سفارشی';
    }
  }

  String _scheduleLabel(dynamic p) {
    if (p.isStore) return 'اقساط مستقیم فروشگاه';
    switch (p.scheduleType) {
      case ScheduleType.fixedInterval:
        return 'تسویه در ${p.defaultInstallmentCount} قسط با فاصلهٔ ${p.intervalDays} روزه';
      case ScheduleType.basalam:
        return 'قسط اول ${p.firstPercentBps / 100}٪ + ${p.subsequentCount} قسط بعدی (روز ${p.settlementDay} ماه‌های بعد)';
      default:
        return 'تسویه در ${p.defaultInstallmentCount} قسط مساوی، روز ${p.settlementDay} ماه‌های بعد';
    }
  }

  Future<void> _openForm(StoreCore core, {InstallmentProviderEntity? edit}) async {
    final name = TextEditingController(text: edit?.name ?? '');
    final contract = TextEditingController(text: edit?.contractRef ?? '');
    final notes = TextEditingController(text: edit?.notes ?? '');
    final percent = TextEditingController(
        text: edit == null ? '' : ((edit.commissionBps) / 100).toString());
    final fixed = TextEditingController(
        text: edit == null || edit.commissionFixed == 0
            ? ''
            : edit.commissionFixed.toString());
    final vatPercent = TextEditingController(
        text: edit == null || edit.commissionVatBps == 0
            ? ''
            : (edit.commissionVatBps / 100).toString());
    final count = TextEditingController(
        text: (edit?.defaultInstallmentCount ?? 4).toString());
    final deductions = TextEditingController(
        text: edit == null || edit.otherDeductions == 0
            ? ''
            : edit.otherDeductions.toString());
    final settlementDay = TextEditingController(
        text: (edit?.settlementDay ?? 3).toString());
    final intervalDays = TextEditingController(
        text: (edit?.intervalDays ?? 30).toString());
    final firstPercent = TextEditingController(
        text: edit == null ? '25' : (edit.firstPercentBps / 100).toString());
    final subsequentCount = TextEditingController(
        text: (edit?.subsequentCount ?? 2).toString());
    final deliveryDelay = TextEditingController(
        text: (edit?.settlementDelayDays ?? 10).toString());
    final isStore = edit?.isStore ?? false;
    var type = edit?.providerType ?? 'custom';
    var scheduleType = edit?.scheduleType ?? ScheduleType.monthlyWindow;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 18, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(edit == null ? 'درگاه اقساطی جدید' : 'تنظیمات ${edit.name}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text(
                    'نرخ کارمزد و الگوی زمان‌بندی تسویه را دقیقاً طبق قرارداد خودتان وارد کنید',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10.5, color: AppTheme.RubyTextSecondary)),
                const SizedBox(height: 14),
                TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'نام *')),
                const SizedBox(height: 10),
                if (edit == null)
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    items: const [
                      DropdownMenuItem(value: 'custom', child: Text('سفارشی')),
                      DropdownMenuItem(value: 'store', child: Text('مستقیم فروشگاه (بدون کارمزد)')),
                    ],
                    onChanged: (v) => setSheet(() => type = v ?? type),
                    decoration: const InputDecoration(labelText: 'نوع'),
                  ),
                if (!isStore && type != 'store') ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: percent,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'کارمزد درصدی (مثال: 6 برای ۶٪)',
                        suffixText: '٪'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                      controller: fixed,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'کارمزد ثابت (تومان)', suffixText: 'تومان')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: vatPercent,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'مالیات بر کارمزد (مثال: 10 برای ۱۰٪؛ خالی = بدون مالیات)',
                        suffixText: '٪'),
                  ),
                  const SizedBox(height: 10),
                  TomanField(
                      controller: deductions,
                      label: 'سایر کسورات قراردادی (تومان)'),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: scheduleType,
                    items: const [
                      DropdownMenuItem(
                          value: ScheduleType.monthlyWindow,
                          child: Text('روز مشخصی از ماه‌های بعد (مثل ترب‌پی)')),
                      DropdownMenuItem(
                          value: ScheduleType.fixedInterval,
                          child: Text('فاصلهٔ ثابت روزه (مثل تارا: ۳۰/۶۰ روز)')),
                      DropdownMenuItem(
                          value: ScheduleType.basalam,
                          child: Text('قسط اول درصدی + اقساط بعدی (باسلام)')),
                    ],
                    onChanged: (v) =>
                        setSheet(() => scheduleType = v ?? scheduleType),
                    decoration: const InputDecoration(labelText: 'الگوی زمان‌بندی تسویه'),
                  ),
                  if (scheduleType == ScheduleType.monthlyWindow) ...[
                    const SizedBox(height: 10),
                    TextField(
                        controller: count,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'تعداد اقساط تسویه')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: settlementDay,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'روز تسویه در هر ماه (۱ تا ۵)',
                            suffixText: 'روز ماه')),
                  ],
                  if (scheduleType == ScheduleType.fixedInterval) ...[
                    const SizedBox(height: 10),
                    TextField(
                        controller: count,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'تعداد اقساط تسویه')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: intervalDays,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'فاصلهٔ هر قسط (۳۰ → قسط‌های ۳۰ و ۶۰ روز)',
                            suffixText: 'روز')),
                  ],
                  if (scheduleType == ScheduleType.basalam) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: firstPercent,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'درصد قسط اول (پیش‌فرض؛ هنگام فروش قابل تغییر)',
                          suffixText: '٪'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                        controller: subsequentCount,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'تعداد اقساط بعد از قسط اول')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: deliveryDelay,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'تأخیر قسط اول بعد از تحویل سفارش',
                            suffixText: 'روز')),
                    const SizedBox(height: 10),
                    TextField(
                        controller: settlementDay,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'روز تسویهٔ اقساط بعدی در هر ماه (۱ تا ۵)',
                            suffixText: 'روز ماه')),
                  ],
                ],
                if (isStore || type == 'store') ...[
                  const SizedBox(height: 10),
                  TextField(
                      controller: count,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'تعداد اقساط پیش‌فرض')),
                ],
                const SizedBox(height: 10),
                TextField(
                    controller: contract,
                    decoration: const InputDecoration(labelText: 'شماره قرارداد/مرجع')),
                const SizedBox(height: 10),
                TextField(
                    controller: notes,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'یادداشت')),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    if (name.text.trim().isEmpty) {
                      showStoreSnack(ctx, 'نام الزامی است', error: true);
                      return;
                    }
                    final bps =
                        (((double.tryParse(percent.text.replaceAll(',', '.')) ?? 0)) * 100)
                            .round();
                    final vatBps =
                        (((double.tryParse(vatPercent.text.replaceAll(',', '.')) ?? 0)) * 100)
                            .round();
                    final fPct =
                        (((double.tryParse(firstPercent.text.replaceAll(',', '.')) ?? 0)) * 100)
                            .round();
                    core.installments.saveProvider(
                      id: edit?.id,
                      key: edit?.key,
                      name: name.text.trim(),
                      providerType: edit?.providerType ?? type,
                      commissionBps: bps,
                      commissionFixed: parseToman(fixed.text) ?? 0,
                      commissionVatBps: vatBps,
                      otherDeductions: parseToman(deductions.text) ?? 0,
                      settlementDelayDays: scheduleType == ScheduleType.basalam
                          ? (int.tryParse(deliveryDelay.text) ?? 10)
                          : (edit?.settlementDelayDays ?? 0),
                      defaultInstallmentCount: int.tryParse(count.text) ?? 4,
                      contractRef: contract.text.trim(),
                      notes: notes.text.trim(),
                      isEnabled: edit?.isEnabled ?? true,
                      scheduleType: scheduleType,
                      settlementDay: int.tryParse(settlementDay.text) ?? 3,
                      intervalDays: int.tryParse(intervalDays.text) ?? 30,
                      firstPercentBps: scheduleType == ScheduleType.basalam ? fPct : 0,
                      subsequentCount: scheduleType == ScheduleType.basalam
                          ? (int.tryParse(subsequentCount.text) ?? 2)
                          : 0,
                    );
                    Navigator.pop(ctx);
                  },
                  child: const Text('ذخیره تنظیمات'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await _reload(core);
  }

  @override
  Widget build(BuildContext context) {
    return StoreScaffold(
      title: 'سیستم‌های اقساطی',
      actions: [
        IconButton(
          onPressed: () async {
            final core = await ref.read(storeCoreProvider.future);
            _openForm(core);
          },
          icon: const Icon(Icons.add),
        ),
      ],
      body: (context, core) {
        if (_loading) {
          _reload(core);
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final p in _providers)
              Card(
                color: Colors.white,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  onLongPress: () => _openForm(core, edit: p),
                  leading: CircleAvatar(
                    backgroundColor: (p.isEnabled
                            ? AppTheme.RubyPrimary
                            : Colors.grey)
                        .withValues(alpha: 0.14),
                    child: Icon(Icons.schedule,
                        color: p.isEnabled ? AppTheme.RubyPrimary : Colors.grey),
                  ),
                  title: Text('${p.name} (${_typeLabel(p.providerType)})',
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w900)),
                  subtitle: Text(
                    p.isStore
                        ? 'اقساط مستقیم فروشگاه — بدون کارمزد · پیش‌فرض ${p.defaultInstallmentCount} قسط · سقف اعتبار از پروفایل مشتری'
                        : '${_scheduleLabel(p)}\nکارمزد: ${p.commissionBps / 100}٪${p.commissionFixed > 0 ? ' + ${formatToman(p.commissionFixed)}' : ''}${p.commissionVatBps > 0 ? ' + مالیات ${p.commissionVatBps / 100}٪' : ''}',
                    style: const TextStyle(fontSize: 10.5),
                  ),
                  trailing: Switch(
                    value: p.isEnabled,
                    onChanged: (v) {
                      core.installments.saveProvider(
                        id: p.id,
                        key: p.key,
                        name: p.name,
                        providerType: p.providerType,
                        commissionBps: p.commissionBps,
                        commissionFixed: p.commissionFixed,
                        commissionVatBps: p.commissionVatBps,
                        otherDeductions: p.otherDeductions,
                        settlementDelayDays: p.settlementDelayDays,
                        defaultInstallmentCount: p.defaultInstallmentCount,
                        contractRef: p.contractRef,
                        notes: p.notes,
                        isEnabled: v,
                        scheduleType: p.scheduleType,
                        settlementDay: p.settlementDay,
                        intervalDays: p.intervalDays,
                        firstPercentBps: p.firstPercentBps,
                        subsequentCount: p.subsequentCount,
                      );
                      _reload(core);
                    },
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                'برای ویرایش، هر کارت را نگه دارید. تسویهٔ «مستقیم فروشگاه» ریسک اعتباری با خود فروشگاه است و مشمول سقف اعتبار مشتری می‌شود.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: AppTheme.RubyTextSecondary),
              ),
            ),
          ],
        );
      },
    );
  }
}
