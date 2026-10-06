import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../shared/empty_state.dart';
import '../shared/status_badge.dart';
import 'name_detail_screen.dart';

class NameSearchScreen extends ConsumerStatefulWidget {
  const NameSearchScreen({super.key});

  @override
  ConsumerState<NameSearchScreen> createState() => _NameSearchScreenState();
}

class _NameSearchScreenState extends ConsumerState<NameSearchScreen> {
  late final TextEditingController controller;
  String selectedStyle = 'همه';

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: ref.read(nameQueryProvider));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawNames = ref.watch(namesProvider);
    final names = ref.watch(nameSearchEngineProvider).filter(names: rawNames, style: selectedStyle);
    return Scaffold(
      appBar: AppBar(title: const Text('دانشنامه نام‌ها')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: TextField(
              controller: controller,
              autofocus: false,
              onChanged: (value) => ref.read(nameQueryProvider.notifier).state = value,
              decoration: const InputDecoration(
                hintText: 'نام، معنی، زبان یا سبک',
                prefixIcon: Icon(Icons.search),
                suffixIcon: Icon(Icons.manage_search),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              children: ['همه', 'ایرانی', 'فارسی', 'باستانی', 'مدرن', 'کوتاه']
                  .map((style) => Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          label: Text(style),
                          selected: selectedStyle == style,
                          onSelected: (_) => setState(() => selectedStyle = style),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: names.isEmpty
                ? const EmptyState(title: 'نامی پیدا نشد', message: 'عبارت یا فیلتر دیگری را امتحان کنید.')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                    itemCount: names.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final name = names[index];
                      return ListTile(
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE2F2EF),
                          child: Text(name.displayName.characters.first, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(name.displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${name.language} · ${name.origin}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            StatusBadge(status: name.status),
                            const SizedBox(height: 5),
                            const Icon(Icons.chevron_left, size: 18),
                          ],
                        ),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NameDetailScreen(nameId: name.id))),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
