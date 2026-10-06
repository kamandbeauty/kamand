import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../analysis/name_analysis_screen.dart';
import '../archive/archive_screen.dart';
import '../baby_names/baby_names_screen.dart';
import '../compatibility/compatibility_screen.dart';
import '../names/name_detail_screen.dart';
import '../names/name_search_screen.dart';
import '../shared/section_title.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(namesProvider);
    final featured = names.take(4).toList(growable: false);
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('علم اسامی', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 5),
                            Text('نامت را بهتر بشناس', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.blueGrey)),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: const Color(0xFFE2F2EF),
                        child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    readOnly: true,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NameSearchScreen())),
                    decoration: const InputDecoration(
                      hintText: 'نام، معنی یا ریشه را جست‌وجو کن',
                      prefixIcon: Icon(Icons.search),
                      suffixIcon: Icon(Icons.tune),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _DisclaimerCard(),
                  const SizedBox(height: 24),
                  const SectionTitle(title: 'شروع سریع', subtitle: 'ابزارهای پرکاربرد'),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.45,
              children: [
                _QuickAction(icon: Icons.insights, title: 'تحلیل نام', color: const Color(0xFFE2F2EF), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NameAnalysisScreen()))),
                _QuickAction(icon: Icons.calculate_outlined, title: 'ابجد', color: const Color(0xFFF6EDDC), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NameAnalysisScreen()))),
                _QuickAction(icon: Icons.favorite_outline, title: 'سازگاری', color: const Color(0xFFF8E9EC), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompatibilityScreen()))),
                _QuickAction(icon: Icons.child_friendly_outlined, title: 'نام نوزاد', color: const Color(0xFFEAF0FA), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BabyNamesScreen()))),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Row(
                children: [
                  const Expanded(child: SectionTitle(title: 'چند نام برای بررسی', subtitle: 'داده‌های نسخه آزمایشی')),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NameSearchScreen())),
                    child: const Text('همه'),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                final name = featured[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFE2F2EF),
                      child: Text(name.displayName.characters.first, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800)),
                    ),
                    title: Text(name.displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(name.meaning),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NameDetailScreen(nameId: name.id))),
                  ),
                );
              },
              childCount: featured.length,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ArchiveScreen())),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('آرشیو پژوهشی و روش‌شناسی'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.title, required this.color, required this.onTap});

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF253238),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Color(0xFFF6EDDC)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'در علم اسامی، ادعاهای تاریخی و زبانی از تفسیرهای سنتی جدا هستند. نتایج ابجد و عددشناسی جنبه تفسیری و سرگرمی دارند.',
              style: TextStyle(color: Colors.white, height: 1.6, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
