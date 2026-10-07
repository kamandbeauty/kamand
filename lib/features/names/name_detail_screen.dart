import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/name.dart';
import '../../domain/models/source_claim.dart';
import '../shared/empty_state.dart';
import '../shared/status_badge.dart';

class NameDetailScreen extends ConsumerWidget {
  const NameDetailScreen({super.key, required this.nameId});

  final String nameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(nameRepositoryProvider).byId(nameId);
    final claims = ref.watch(nameRepositoryProvider).claimsForName(nameId);
    if (name == null) {
      return const Scaffold(body: EmptyState(title: 'نام پیدا نشد', message: 'این رکورد در دیتابیس محلی موجود نیست.'));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(name.displayName),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined), tooltip: 'اشتراک‌گذاری')],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _Hero(name: name),
          const SizedBox(height: 18),
          _InfoSection(title: 'معنی', icon: Icons.lightbulb_outline, child: Text(name.meaning, style: const TextStyle(height: 1.7))),
          _InfoSection(title: 'ریشه‌شناسی و مسیر تحول', icon: Icons.account_tree_outlined, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name.etymology, style: const TextStyle(height: 1.7)), const SizedBox(height: 10), const Text('ریشه‌شناسی با معنی امروزی یا ویژگی شخصیتی یکی نیست؛ اختلاف منابع در وضعیت رکورد حفظ می‌شود.', style: TextStyle(color: Colors.blueGrey, fontSize: 12, height: 1.6))])),
          _InfoSection(title: 'ریشه و زبان', icon: Icons.translate_outlined, child: _InfoGrid(items: {'زبان': name.language, 'خاستگاه': name.origin, 'تلفظ': name.pronunciation, 'لاتین': name.transliteration})),

          _InfoSection(title: 'سبک‌های ثبت‌شده', icon: Icons.style_outlined, child: Wrap(spacing: 8, runSpacing: 8, children: name.styles.map((style) => Chip(label: Text(style))).toList())),
          _InfoSection(title: 'وضعیت داده', icon: Icons.fact_check_outlined, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [StatusBadge(status: name.status), const SizedBox(height: 10), Text('سطح اطمینان: ${name.confidence}'), const SizedBox(height: 6), Text(name.sourceNote, style: const TextStyle(color: Colors.blueGrey, height: 1.6))])),
          _InfoSection(title: 'منبع و روش', icon: Icons.menu_book_outlined, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name.sourceTitle, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 6), const Text('این بخش برای اتصال هر ادعا به منبع طراحی شده است. تا زمان بررسی نهایی، وضعیت رکورد باید در UI حفظ شود.', style: TextStyle(color: Colors.blueGrey, height: 1.6))])),
          _InfoSection(title: 'ادعاهای منبع‌دار', icon: Icons.fact_check_outlined, child: claims.isEmpty ? const Text('برای این نام هنوز Claim مستقلی ثبت نشده است.', style: TextStyle(color: Colors.blueGrey)) : Column(children: claims.map((claim) => _ClaimTile(claim: claim)).toList())),

        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.name});

  final Name name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF176B67), Color(0xFF253238)], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 34, backgroundColor: Colors.white24, child: Text(name.displayName.characters.first, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name.displayName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 5), Text('${name.letterCount} حرف · ${name.gender}', style: const TextStyle(color: Colors.white70))])),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w900))]), const SizedBox(height: 12), child]),
      ),
    );
  }
}

class _ClaimTile extends StatelessWidget {
  const _ClaimTile({required this.claim});

  final SourceClaim claim;

  @override
  Widget build(BuildContext context) {
    final badgeStatus = claim.status == 'supported' ? 'verified' : claim.status;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF4F6F3), borderRadius: BorderRadius.circular(15)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(claim.claimType, style: const TextStyle(fontWeight: FontWeight.w800))), StatusBadge(status: badgeStatus)]),
        const SizedBox(height: 8),
        Text(claim.claimText, style: const TextStyle(height: 1.6)),
        const SizedBox(height: 7),
        Text('سطح اطمینان: ${claim.confidence} · منبع: ${claim.sourceTitle}', style: const TextStyle(color: Colors.blueGrey, fontSize: 11)),
        if (claim.evidenceNote.isNotEmpty) ...[const SizedBox(height: 4), Text(claim.evidenceNote, style: const TextStyle(color: Colors.blueGrey, fontSize: 11))],
      ]),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});

  final Map<String, String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.entries.map((entry) => Container(width: 140, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF4F6F3), borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(entry.key, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)), const SizedBox(height: 4), Text(entry.value, style: const TextStyle(fontWeight: FontWeight.w700))]))).toList(),
    );
  }
}
