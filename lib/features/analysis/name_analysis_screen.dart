import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/abjad_result.dart';
import '../../domain/models/numerology_result.dart';
import '../shared/empty_state.dart';
import '../shared/status_badge.dart';
import 'birth_analysis_screen.dart';

class NameAnalysisScreen extends ConsumerStatefulWidget {
  const NameAnalysisScreen({super.key});

  @override
  ConsumerState<NameAnalysisScreen> createState() => _NameAnalysisScreenState();
}

class _NameAnalysisScreenState extends ConsumerState<NameAnalysisScreen> {
  final controller = TextEditingController();
  AbjadResult? result;
  NumerologyResult? numerology;
  List<AbjadResult> reports = const [];
  String selectedSystem = 'kabir';
  bool submitted = false;
  bool isAnalyzing = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> analyze() async {
    if (isAnalyzing) return;
    final value = controller.text.trim();
    if (value.isEmpty) {
      setState(() {
        result = null;
        numerology = null;
        reports = const [];
        submitted = true;
      });
      return;
    }
    setState(() => isAnalyzing = true);
    await Future<void>.delayed(Duration.zero);
    final systems = ref.read(abjadSystemsProvider);
    final calculated = systems
        .map((system) => ref.read(abjadEngineForSystemProvider(system.key)).calculate(value))
        .toList(growable: false);
    final matching = calculated.where((item) => item.systemKey == selectedSystem);
    final selected = matching.isEmpty ? (calculated.isEmpty ? null : calculated.first) : matching.first;
    if (!mounted) return;
    setState(() {
      reports = calculated;
      result = selected;
      numerology = selected == null ? null : ref.read(numerologyEngineProvider).fromAbjadTotal(selected.total, inputComplete: selected.isComplete);
      submitted = true;
      isAnalyzing = false;
    });
  }

  void selectSystem(String? value) {
    if (value == null) return;
    setState(() {
      selectedSystem = value;
      final matching = reports.where((item) => item.systemKey == value);
      result = matching.isEmpty ? result : matching.first;
      if (result != null) {
        numerology = ref.read(numerologyEngineProvider).fromAbjadTotal(result!.total, inputComplete: result!.isComplete);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final systems = ref.watch(abjadSystemsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('گزارش کامل تحلیل نام')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text('نامی را وارد کن', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('گزارش شامل جدول حرف‌به‌حرف، چند نوع ابجد، فرمول، منبع و وضعیت هر نتیجه است.', style: TextStyle(color: Colors.blueGrey, height: 1.6)),
          const SizedBox(height: 20),
          TextField(controller: controller, textInputAction: TextInputAction.done, onSubmitted: (_) => analyze(), decoration: const InputDecoration(labelText: 'نام یا عبارت', hintText: 'مثلاً آریا یا مهرداد', prefixIcon: Icon(Icons.badge_outlined))),
          const SizedBox(height: 12),
          if (systems.isNotEmpty)
            DropdownButtonFormField<String>(
              value: systems.any((item) => item.key == selectedSystem) ? selectedSystem : systems.first.key,
              decoration: const InputDecoration(labelText: 'سیستم اصلی گزارش', prefixIcon: Icon(Icons.calculate_outlined)),
              items: systems.map((system) => DropdownMenuItem(value: system.key, child: Text(system.title))).toList(),
              onChanged: selectSystem,
            ),
          if (submitted && controller.text.trim().isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('لطفاً نام را وارد کنید.', style: TextStyle(color: Colors.red))),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: isAnalyzing ? null : analyze, icon: const Icon(Icons.calculate_outlined), label: Text(isAnalyzing ? 'در حال ساخت گزارش…' : 'ساخت گزارش کامل')),
          if (isAnalyzing) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BirthAnalysisScreen())), icon: const Icon(Icons.date_range_outlined), label: const Text('گزارش نام و تاریخ تولد')),
          if (result == null && submitted && controller.text.trim().isNotEmpty) const Padding(padding: EdgeInsets.only(top: 24), child: EmptyState(title: 'گزارشی ساخته نشد', message: 'ورودی یا سیستم محاسبه را بررسی و دوباره تلاش کنید.')),
          if (result != null && numerology != null) ...[
            const SizedBox(height: 24),
            _ReportHeader(input: controller.text.trim(), result: result!),
            const SizedBox(height: 14),
            _TotalCard(result: result!, numerology: numerology!),
            const SizedBox(height: 14),
            _SystemsReportCard(results: reports),
            const SizedBox(height: 14),
            _StepsCard(result: result!),
            const SizedBox(height: 14),
            _MethodCard(result: result!, numerology: numerology!),
          ],
        ],
      ),
    );
  }
}

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({required this.input, required this.result});

  final String input;
  final AbjadResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFE2F2EF),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.description_outlined, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), const Text('گزارش قابل بازبینی', style: TextStyle(fontWeight: FontWeight.w900))]),
          const SizedBox(height: 10),
          Text('ورودی: $input', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('سیستم اصلی: ${result.systemTitle} · ${result.steps.length} نویسه بررسی شد', style: const TextStyle(color: Colors.blueGrey)),
        ]),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.result, required this.numerology});

  final AbjadResult result;
  final NumerologyResult numerology;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF253238), borderRadius: BorderRadius.circular(24)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(result.systemTitle, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text('${result.total}', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(result.isComplete ? 'همه حروف در این سیستم نگاشت دارند' : 'حروف ناشناخته: ${result.unknownLetters.join('، ')}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ])),
        Container(width: 76, height: 76, alignment: Alignment.center, decoration: const BoxDecoration(color: Color(0xFFF6EDDC), shape: BoxShape.circle), child: Text(numerology.isAvailable ? '${numerology.value}' : '?', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF253238))),
      ]),
    );
  }
}

class _SystemsReportCard extends StatelessWidget {
  const _SystemsReportCard({required this.results});

  final List<AbjadResult> results;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('مقایسه سیستم‌های ابجد', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('مقدارها را کنار هم ببین؛ تفاوت فرمول یا معادل‌سازی به معنی تفاوت در حقیقت نام نیست.', style: TextStyle(color: Colors.blueGrey, fontSize: 12, height: 1.6)),
          const SizedBox(height: 12),
          ...results.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF4F6F3), borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.systemTitle, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(item.isComplete ? item.formula : 'تکمیل نیست: ${item.unknownLetters.join('، ')}', style: const TextStyle(color: Colors.blueGrey, fontSize: 11))])),
                    Text(item.isComplete ? '${item.total}' : '—', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(width: 8),
                    StatusBadge(status: item.status),
                  ]),
                ),
              )),
        ]),
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.result});

  final AbjadResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('محاسبه حرف‌به‌حرف', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          ...result.steps.map((step) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Expanded(child: Text('${step.letter} =')), Text(step.value?.toString() ?? 'نامشخص', style: const TextStyle(fontWeight: FontWeight.w800))]))),
          const Divider(),
          Row(children: [const Expanded(child: Text('مجموع', style: TextStyle(fontWeight: FontWeight.w900))), Text('${result.total}', style: const TextStyle(fontWeight: FontWeight.w900))]),
        ]),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({required this.result, required this.numerology});

  final AbjadResult result;
  final NumerologyResult numerology;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF6EDDC),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('فرمول، منبع و محدودیت گزارش', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('فرمول: ${result.formula}'),
          const SizedBox(height: 4),
          Text('وضعیت: ${result.status} · نسخه منبع: ${result.sourceTitle}'),
          const SizedBox(height: 8),
          Text(result.sourceNote, style: const TextStyle(height: 1.6)),
          const Divider(height: 24),
          Text(numerology.systemTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Rule: ${numerology.ruleKey} · نسخه: ${numerology.ruleVersion} · وضعیت: ${numerology.status} · منبع: ${numerology.sourceTitle}'),
          if (numerology.calculation.isNotEmpty) ...[const SizedBox(height: 5), Text('کاهش رقمی: ${numerology.calculation}')],
          const SizedBox(height: 5),
          Text(numerology.description, style: const TextStyle(height: 1.5)),
          const SizedBox(height: 8),
          Text(numerology.disclaimer, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.5)),
        ]),
      ),
    );
  }
}
