import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../shared/empty_state.dart';
import '../shared/status_badge.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(archiveEntriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('آرشیو پژوهشی')),
      body: entries.isEmpty
          ? const EmptyState(title: 'آرشیو خالی است', message: 'با ورود محتوای بررسی‌شده، این بخش تکمیل می‌شود.', icon: Icons.inventory_2_outlined)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Card(child: ExpansionTile(title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${entry.category} · ${entry.sourceTitle}'), leading: const CircleAvatar(child: Icon(Icons.archive_outlined)), childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18), children: [Align(alignment: Alignment.centerRight, child: StatusBadge(status: entry.status)), const SizedBox(height: 10), Align(alignment: Alignment.centerRight, child: Text(entry.body, style: const TextStyle(height: 1.8))), const SizedBox(height: 8), const Align(alignment: Alignment.centerRight, child: Text('این آرشیو برای ثبت روش، منبع و مسیر بررسی محتوا ساخته شده است.', style: TextStyle(color: Colors.blueGrey, fontSize: 12)))]));
              },
            ),
    );
  }
}
