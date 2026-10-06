import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../names/name_detail_screen.dart';
import '../shared/empty_state.dart';

class BabyNamesScreen extends ConsumerStatefulWidget {
  const BabyNamesScreen({super.key});

  @override
  ConsumerState<BabyNamesScreen> createState() => _BabyNamesScreenState();
}

class _BabyNamesScreenState extends ConsumerState<BabyNamesScreen> {
  final familyName = TextEditingController();
  String style = 'همه';

  @override
  void dispose() {
    familyName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = ref.watch(namesProvider).where((name) => style == 'همه' || name.styles.contains(style)).toList();
    return Scaffold(appBar: AppBar(title: const Text('انتخاب نام نوزاد')), body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 30), children: [const Text('پیشنهاد توضیح‌پذیر', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height: 8), const Text('در این نسخه، نتیجه بر اساس سبک‌های ثبت‌شده و داده محلی رتبه‌بندی می‌شود؛ بخش‌های سنتی جدا و اختیاری هستند.', style: TextStyle(color: Colors.blueGrey, height: 1.6)), const SizedBox(height: 20), TextField(controller: familyName, decoration: const InputDecoration(labelText: 'نام خانوادگی (اختیاری)', prefixIcon: Icon(Icons.family_restroom_outlined))), const SizedBox(height: 14), Wrap(spacing: 8, children: ['همه', 'ایرانی', 'فارسی', 'باستانی', 'مدرن', 'کوتاه'].map((item) => ChoiceChip(label: Text(item), selected: style == item, onSelected: (_) => setState(() => style = item))).toList()), const SizedBox(height: 18), if (names.isEmpty) const EmptyState(title: 'نامی برای این سبک نیست', message: 'سبک دیگری انتخاب کنید.') else ...names.map((name) => Card(child: ListTile(title: Text(name.displayName, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('سبک: ${name.styles.join('، ')} · وضعیت: نیازمند بررسی'), trailing: const Icon(Icons.chevron_left), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NameDetailScreen(nameId: name.id))))),]));
  }
}
