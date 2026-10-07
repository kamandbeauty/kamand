import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/abjad_system.dart';
import '../shared/empty_state.dart';
import '../shared/status_badge.dart';

class AbjadArchiveScreen extends ConsumerStatefulWidget {
  const AbjadArchiveScreen({super.key});

  @override
  ConsumerState<AbjadArchiveScreen> createState() => _AbjadArchiveScreenState();
}

class _AbjadArchiveScreenState extends ConsumerState<AbjadArchiveScreen> {
  String? selectedKey;

  @override
  Widget build(BuildContext context) {
    final systems = ref.watch(abjadSystemsProvider);
    if (systems.isEmpty) {
      return const Scaffold(body: EmptyState(title: 'سیستم ابجد ثبت نشده', message: 'آرشیو نگاشت‌ها هنوز آماده نیست.', icon: Icons.calculate_outlined));
    }
    final activeKey = selectedKey ?? systems.first.key;
    final system = systems.firstWhere((item) => item.key == activeKey, orElse: () => systems.first);
    final mapping = ref.watch(databaseProvider).getAbjadMapping(system.key);
    return Scaffold(
      appBar: AppBar(title: const Text('آرشیو ابجد')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text('جدول کامل نگاشت‌ها', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('هر سیستم، فرمول و وضعیت جداگانه دارد. حروف فارسیِ اضافه فقط در گونه معادل‌سازی‌شده مقدار می‌گیرند.', style: TextStyle(color: Colors.blueGrey, height: 1.6)),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            value: activeKey,
            decoration: const InputDecoration(labelText: 'سیستم محاسبه', prefixIcon: Icon(Icons.tune_outlined)),
            items: systems.map((item) => DropdownMenuItem(value: item.key, child: Text(item.title))).toList(),
            onChanged: (value) => setState(() => selectedKey = value),
          ),
          const SizedBox(height: 14),
          _SystemSummary(system: system, mappingCount: mapping.length),
          const SizedBox(height: 14),
          _MappingTable(mapping: mapping),
          const SizedBox(height: 14),
          Card(
            color: const Color(0xFFF6EDDC),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'هشدار روش‌شناختی: ابجد یک نظام تاریخیِ ارزش‌گذاری حروف است. خروجی این صفحه محاسبه قابل بازبینی است، نه تفسیر قطعی درباره شخصیت، رابطه، سرنوشت یا آینده. در نسخه استاندارد، حروف پ، چ، ژ و گ عمداً «ناشناخته» هستند.',
                style: const TextStyle(height: 1.7, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemSummary extends StatelessWidget {
  const _SystemSummary({required this.system, required this.mappingCount});

  final AbjadSystem system;
  final int mappingCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(system.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))), StatusBadge(status: system.status)]),
          const SizedBox(height: 10),
          Text(system.description, style: const TextStyle(height: 1.7)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _InfoChip(label: 'فرمول', value: system.formula),
            _InfoChip(label: 'نسخه', value: system.version),
            _InfoChip(label: 'نگاشت', value: '$mappingCount حرف'),
            _InfoChip(label: 'منبع', value: system.sourceTitle),
          ]),
        ]),
      ),
    );
  }
}

class _MappingTable extends StatelessWidget {
  const _MappingTable({required this.mapping});

  final Map<String, int> mapping;

  @override
  Widget build(BuildContext context) {
    final entries = mapping.entries.toList(growable: false);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.fromLTRB(17, 17, 17, 10), child: Text('حرف به حرف', style: TextStyle(fontWeight: FontWeight.w900))),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(Color(0xFFF4F6F3)),
            columns: const [DataColumn(label: Text('حرف')), DataColumn(label: Text('مقدار')), DataColumn(label: Text('وضعیت'))],
            rows: entries.map((entry) => DataRow(cells: [
              DataCell(Text(entry.key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
              DataCell(Text(entry.value.toString(), style: const TextStyle(fontWeight: FontWeight.w800))),
              const DataCell(Text('ثبت‌شده در این سیستم', style: TextStyle(color: Colors.blueGrey, fontSize: 11))),
            ])).toList(),
          ),
        ),
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF4F6F3), borderRadius: BorderRadius.circular(12)),
      child: Text('$label: $value', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
