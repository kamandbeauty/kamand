import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/compatibility_result.dart';

class CompatibilityScreen extends ConsumerStatefulWidget {
  const CompatibilityScreen({super.key});

  @override
  ConsumerState<CompatibilityScreen> createState() => _CompatibilityScreenState();
}

class _CompatibilityScreenState extends ConsumerState<CompatibilityScreen> {
  final first = TextEditingController();
  final second = TextEditingController();
  CompatibilityResult? result;
  String? error;
  bool isComparing = false;

  @override
  void dispose() {
    first.dispose();
    second.dispose();
    super.dispose();
  }

  Future<void> compare() async {
    if (isComparing) return;
    final firstValue = first.text.trim();
    final secondValue = second.text.trim();
    if (firstValue.isEmpty || secondValue.isEmpty) {
      setState(() {
        result = null;
        error = 'برای مقایسه، هر دو نام را وارد کنید.';
      });
      return;
    }
    setState(() {
      isComparing = true;
      result = null;
      error = null;
    });
    await Future<void>.delayed(Duration.zero);
    final nextResult = ref.read(compatibilityEngineProvider).compareWrittenForm(firstValue, secondValue);
    if (!mounted) return;
    setState(() {
      isComparing = false;
      result = nextResult;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مقایسه دو نام')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text('مقایسه شفاف دو نام', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('این بخش فقط شباهت نوشتاری را با یک Rule قابل مشاهده مقایسه می‌کند؛ درباره عشق، ازدواج، شخصیت یا آینده نتیجه‌گیری نمی‌کند.', style: TextStyle(color: Colors.blueGrey, height: 1.6)),
          const SizedBox(height: 22),
          TextField(controller: first, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'نام اول', prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 12),
          TextField(controller: second, textInputAction: TextInputAction.done, onSubmitted: (_) => compare(), decoration: const InputDecoration(labelText: 'نام دوم', prefixIcon: Icon(Icons.person_outline))),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 9), child: Text(error!, style: const TextStyle(color: Colors.redAccent))),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: isComparing ? null : compare, icon: const Icon(Icons.compare_arrows), label: Text(isComparing ? 'در حال مقایسه…' : 'مقایسه')),
          if (isComparing) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          if (!isComparing && result == null && error == null) const Padding(padding: EdgeInsets.only(top: 24), child: Card(child: Padding(padding: EdgeInsets.all(17), child: Text('دو نام را وارد کنید تا شاخص نوشتاری محاسبه شود.', style: TextStyle(color: Colors.blueGrey, height: 1.6))))),
          if (result != null) ...[
            const SizedBox(height: 22),
            _ResultCard(result: result!),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final CompatibilityResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(result.label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
              if (result.score != null) Semantics(label: 'امتیاز شباهت نوشتاری ${result.score} درصد', child: Text('${result.score}%', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 28, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 16),
            Text('Rule: ${result.ruleKey} · نسخه: ${result.ruleVersion}'),
            Text('وضعیت: ${result.status} · منبع: ${result.sourceTitle}'),
            if (result.calculation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('محاسبه: ${result.calculation}', style: const TextStyle(height: 1.6)),
            ],
            const SizedBox(height: 8),
            Text(result.method, style: const TextStyle(height: 1.7)),
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF6EDDC), borderRadius: BorderRadius.circular(14)), child: Text(result.disclaimer, style: const TextStyle(height: 1.6, fontSize: 12))),
          ],
        ),
      ),
    );
  }
}
