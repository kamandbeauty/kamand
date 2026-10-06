import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/source.dart';
import '../shared/empty_state.dart';
import '../shared/status_badge.dart';

class SourceCatalogScreen extends ConsumerWidget {
  const SourceCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourcesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('فهرست منابع')),
      body: sources.isEmpty
          ? const EmptyState(title: 'منبع ثبت نشده', message: 'منابع پس از بررسی پژوهشی در اینجا نمایش داده می‌شوند.', icon: Icons.menu_book_outlined)
          : ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
              itemCount: sources.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _SourceCard(source: sources[index]),
            ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source});

  final Source source;

  @override
  Widget build(BuildContext context) {
    final isTierOne = source.reliability == 'tier_1';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: isTierOne ? const Color(0xFFE2F2EF) : const Color(0xFFF6EDDC),
                  child: Icon(isTierOne ? Icons.workspace_premium_outlined : Icons.menu_book_outlined, color: isTierOne ? const Color(0xFF176B67) : const Color(0xFF8A672B)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(source.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, height: 1.4))),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [StatusBadge(status: isTierOne ? 'verified' : 'unverified'), _Tag(text: source.type), if (source.year != null) _Tag(text: '${source.year}')]),
            const SizedBox(height: 12),
            Text('نویسنده: ${source.author}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('ناشر: ${source.publisher}', style: const TextStyle(color: Colors.blueGrey)),
            if (source.notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(source.notes, style: const TextStyle(color: Colors.blueGrey, height: 1.6, fontSize: 12)),
            ],
            if (source.url.isNotEmpty) ...[
              const SizedBox(height: 10),
              SelectableText(source.url, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: const Color(0xFFF3F5F3), borderRadius: BorderRadius.circular(9)), child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)));
  }
}
