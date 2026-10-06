import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../shared/empty_state.dart';
import '../shared/status_badge.dart';
import 'source_catalog_screen.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(archiveEntriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('آرشیو پژوهشی'), actions: [IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SourceCatalogScreen())), icon: const Icon(Icons.menu_book_outlined), tooltip: 'فهرست منابع')]),
      body: entries.isEmpty
          ? const EmptyState(title: 'آرشیو خالی است', message: 'با ورود محتوای بررسی‌شده، این بخش تکمیل می‌شود.', icon: Icons.inventory_2_outlined)
          : ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
              itemCount: entries.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) return const _ArchiveIntro();
                final entry = entries[index - 1];
                return Card(
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${entry.category} · ${entry.sourceTitle}'),
                    leading: const CircleAvatar(child: Icon(Icons.archive_outlined)),
                    childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    children: [
                      Align(alignment: Alignment.centerRight, child: StatusBadge(status: entry.status)),
                      const SizedBox(height: 10),
                      Align(alignment: Alignment.centerRight, child: Text(entry.body, style: const TextStyle(height: 1.8))),
                      const SizedBox(height: 8),
                      const Align(alignment: Alignment.centerRight, child: Text('این آرشیو برای ثبت روش، منبع و مسیر بررسی محتوا ساخته شده است.', style: TextStyle(color: Colors.blueGrey, fontSize: 12))),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _ArchiveIntro extends StatelessWidget {
  const _ArchiveIntro();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 188,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(26)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/archive_illustration.png', fit: BoxFit.cover),
          DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color.fromRGBO(18, 63, 66, .92), const Color.fromRGBO(18, 63, 66, .25)], begin: Alignment.centerRight, end: Alignment.centerLeft))),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [Text('از ادعا تا منبع', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)), SizedBox(height: 6), Text('محتوا، روش‌شناسی و مسیر بررسی نام‌ها', style: TextStyle(color: Colors.white70, fontSize: 12))]),
          ),
        ],
      ),
    );
  }
}
