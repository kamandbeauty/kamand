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

  @override
  void dispose() {
    first.dispose();
    second.dispose();
    super.dispose();
  }

  void compare() {
    setState(() => result = ref.read(compatibilityEngineProvider).compareWrittenForm(first.text, second.text));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سازگاری دو نام')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        const Text('مقایسه شفاف دو نام', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text('در Phase 1 فقط شاخص شباهت نوشتاری محاسبه می‌شود؛ تحلیل رابطه‌ای بدون Rule و منبع نمایش داده نمی‌شود.', style: TextStyle(color: Colors.blueGrey, height: 1.6)),
        const SizedBox(height: 22),
        TextField(controller: first, decoration: const InputDecoration(labelText: 'نام اول', prefixIcon: Icon(Icons.person_outline))),
        const SizedBox(height: 12),
        TextField(controller: second, decoration: const InputDecoration(labelText: 'نام دوم', prefixIcon: Icon(Icons.person_outline))),
        const SizedBox(height: 14),
        FilledButton.icon(onPressed: compare, icon: const Icon(Icons.compare_arrows), label: const Text('مقایسه')),
        if (result != null) ...[
          const SizedBox(height: 22),
          _ResultCard(result: result!),
        ],
      ]),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final CompatibilityResult result;

  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Expanded(child: Text(result.label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))), if (result.score != null) Text('${result.score}%', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 28, fontWeight: FontWeight.w900))]), const SizedBox(height: 16), Text(result.method, style: const TextStyle(height: 1.7)), const SizedBox(height: 12), Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF6EDDC), borderRadius: BorderRadius.circular(14)), child: Text(result.disclaimer, style: const TextStyle(height: 1.6, fontSize: 12)))])));
  }
}
