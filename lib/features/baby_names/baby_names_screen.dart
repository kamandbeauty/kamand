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
  String style = 'همه';

  @override
  Widget build(BuildContext context) {
    final names = ref.watch(namesProvider).where((name) => style == 'همه' || name.styles.contains(style)).toList(growable: false);
    final styles = ['همه', 'ایرانی', 'فارسی', 'باستانی', 'مدرن', 'کوتاه'];
    return Scaffold(
      appBar: AppBar(title: const Text('انتخاب نام نوزاد')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          const Text('پیشنهاد توضیح‌پذیر', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('نام‌ها بر اساس سبک ثبت‌شده و داده محلی فهرست می‌شوند. این بخش Ranking قطعی درباره کیفیت، آینده یا شخصیت کودک ارائه نمی‌کند.', style: TextStyle(color: Colors.blueGrey, height: 1.6)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in styles)
                ChoiceChip(
                  label: Text(item),
                  selected: style == item,
                  onSelected: (_) => setState(() => style = item),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (names.isEmpty)
            const EmptyState(title: 'نامی برای این سبک نیست', message: 'سبک دیگری انتخاب کنید.')
          else
            ...names.map(
              (name) => Card(
                child: ListTile(
                  title: Text(name.displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('سبک: ${name.styles.join('، ')} · وضعیت: ${name.status}'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NameDetailScreen(nameId: name.id))),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
