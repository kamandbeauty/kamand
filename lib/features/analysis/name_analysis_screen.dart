import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/abjad_result.dart';
import '../../domain/models/numerology_result.dart';
import '../shared/empty_state.dart';
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
        submitted = true;
      });
      return;
    }
    setState(() => isAnalyzing = true);
    await Future<void>.delayed(Duration.zero);
    final abjad = ref.read(abjadEngineProvider).calculate(value);
    setState(() {
      result = abjad;
      numerology = ref.read(numerologyEngineProvider).fromAbjadTotal(abjad.total, inputComplete: abjad.isComplete);
      submitted = true;
      isAnalyzing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تحلیل نام')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text('نامی را وارد کن', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('محاسبه‌ها قابل مشاهده و مرحله‌به‌مرحله هستند.', style: TextStyle(color: Colors.blueGrey)),
          const SizedBox(height: 22),
          TextField(controller: controller, textInputAction: TextInputAction.done, onSubmitted: (_) => analyze(), decoration: const InputDecoration(labelText: 'نام', hintText: 'مثلاً آریا', prefixIcon: Icon(Icons.badge_outlined))),
          if (submitted && controller.text.trim().isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('لطفاً نام را وارد کنید.', style: TextStyle(color: Colors.red))),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: isAnalyzing ? null : analyze, icon: const Icon(Icons.calculate_outlined), label: Text(isAnalyzing ? 'در حال محاسبه…' : 'محاسبه')),
          if (isAnalyzing) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BirthAnalysisScreen())), icon: const Icon(Icons.date_range_outlined), label: const Text('تحلیل نام و تاریخ تولد')),
          if (result == null && submitted && controller.text.trim().isNotEmpty) const Padding(padding: EdgeInsets.only(top: 24), child: EmptyState(title: 'نتیجه‌ای ساخته نشد', message: 'ورودی را بررسی و دوباره تلاش کنید.')),
          if (result != null) ...[
            const SizedBox(height: 24),
            _TotalCard(result: result!, numerology: numerology!),
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

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.result, required this.numerology});

  final AbjadResult result;
  final NumerologyResult numerology;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF253238), borderRadius: BorderRadius.circular(24)),
      child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('مجموع ابجد', style: TextStyle(color: Colors.white70)), const SizedBox(height: 4), Text('${result.total}', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)), const SizedBox(height: 6), Text(result.isComplete ? 'همه حروف نگاشت دارند' : 'حروف ناشناخته: ${result.unknownLetters.join('، ')}', style: const TextStyle(color: Colors.white70, fontSize: 12))])), Container(width: 76, height: 76, alignment: Alignment.center, decoration: const BoxDecoration(color: Color(0xFFF6EDDC), shape: BoxShape.circle), child: Text(numerology.isAvailable ? '${numerology.value}' : '?', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF253238))))]),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.result});

  final AbjadResult result;

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(17), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('محاسبه مرحله‌به‌مرحله', style: TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 12), ...result.steps.map((step) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Expanded(child: Text('${step.letter} =')), Text(step.value?.toString() ?? 'نامشخص', style: const TextStyle(fontWeight: FontWeight.w800))]))), const Divider(), Row(children: [const Expanded(child: Text('Total', style: TextStyle(fontWeight: FontWeight.w900))), Text('${result.total}', style: const TextStyle(fontWeight: FontWeight.w900))])])));
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({required this.result, required this.numerology});

  final AbjadResult result;
  final NumerologyResult numerology;

  @override
  Widget build(BuildContext context) {
    return Card(color: const Color(0xFFF6EDDC), child: Padding(padding: const EdgeInsets.all(17), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('منبع و اعتبار', style: TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 8), Text(result.systemTitle), const SizedBox(height: 6), Text(result.sourceNote, style: const TextStyle(height: 1.6)), const Divider(height: 24), Text(numerology.systemTitle, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text('Rule: ${numerology.ruleKey} · نسخه: ${numerology.ruleVersion} · وضعیت: ${numerology.status} · منبع: ${numerology.sourceTitle}'), if (numerology.calculation.isNotEmpty) ...[const SizedBox(height: 5), Text('محاسبه: ${numerology.calculation}')], const SizedBox(height: 5), Text(numerology.description, style: const TextStyle(height: 1.5)), const SizedBox(height: 8), Text(numerology.disclaimer, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.5))])));
  }
}
