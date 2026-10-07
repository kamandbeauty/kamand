import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../analysis/name_analysis_screen.dart';
import '../archive/archive_screen.dart';
import '../baby_names/baby_names_screen.dart';
import '../compatibility/compatibility_screen.dart';
import '../jafr/jafr_screen.dart';
import '../names/name_detail_screen.dart';
import '../names/name_search_screen.dart';
import '../shared/brand_logo.dart';
import '../shared/section_title.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(namesProvider);
    final featured = names.take(4).toList(growable: false);
    return SafeArea(
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  const BrandLogo(size: 43, showName: true),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_none_rounded),
                    tooltip: 'اعلان‌ها',
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: _WelcomeHero(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NameAnalysisScreen())),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: TextField(
                readOnly: true,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NameSearchScreen())),
                decoration: const InputDecoration(
                  hintText: 'نام، معنی یا ریشه را جست‌وجو کن',
                  prefixIcon: Icon(Icons.search_rounded),
                  suffixIcon: Icon(Icons.tune_rounded),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: const Padding(
              padding: EdgeInsets.fromLTRB(20, 25, 20, 12),
              child: SectionTitle(title: 'شروع سریع', subtitle: 'ابزارهای پرکاربرد'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.28,
              children: [
                _QuickAction(icon: Icons.insights_rounded, title: 'تحلیل نام', caption: 'معنی و ریشه', color: const Color(0xFFE2F2EF), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NameAnalysisScreen()))),
                _QuickAction(icon: Icons.auto_awesome_rounded, title: 'جفر', caption: 'آزمایشگاه علم حروف', color: const Color(0xFFF2EAF7), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const JafrScreen()))),
                _QuickAction(icon: Icons.favorite_rounded, title: 'سازگاری', caption: 'مقایسه دو نام', color: const Color(0xFFF8E9EC), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CompatibilityScreen()))),
                _QuickAction(icon: Icons.child_friendly_rounded, title: 'نام نوزاد', caption: 'پیشنهاد توضیح‌پذیر', color: const Color(0xFFEAF0FA), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BabyNamesScreen()))),
              ],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Row(
                children: [
                  const Expanded(child: SectionTitle(title: 'چند نام برای بررسی', subtitle: 'رکوردهای محلی نسخه آزمایشی')),
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
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NameDetailScreen(nameId: name.id))),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 23,
                                backgroundColor: const Color(0xFFE2F2EF),
                                child: Text(name.displayName.characters.first, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w900)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name.displayName, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(name.meaning, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.blueGrey, fontSize: 12))])),
                              const Icon(Icons.chevron_left_rounded, color: Colors.blueGrey),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: featured.length,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              child: _ArchiveBanner(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ArchiveScreen()))),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 218,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/images/home_hero.png', fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color.fromRGBO(22, 63, 65, .96), const Color.fromRGBO(22, 63, 65, .38), Colors.transparent],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  stops: const [0, .53, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const BrandLogo(size: 34, light: true),
                  const SizedBox(height: 18),
                  const Text('نامت را\nبهتر بشناس', style: TextStyle(color: Colors.white, fontSize: 27, height: 1.18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  FilledButton.tonalIcon(onPressed: onTap, icon: const Icon(Icons.arrow_back_rounded), label: const Text('شروع تحلیل'), style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF176B67))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.title, required this.caption, required this.color, required this.onTap});

  final IconData icon;
  final String title;
  final String caption;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: const Color.fromRGBO(255, 255, 255, .65), shape: BoxShape.circle), child: Icon(icon, color: Theme.of(context).colorScheme.primary)), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(caption, style: const TextStyle(fontSize: 11, color: Colors.blueGrey))])]),
        ),
      ),
    );
  }
}

class _ArchiveBanner extends StatelessWidget {
  const _ArchiveBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF253238),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 116,
          child: Row(
            children: [
              Expanded(child: Padding(padding: const EdgeInsetsDirectional.only(start: 18), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('آرشیو پژوهشی', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 7), const Text('منابع، روش‌ها و مسیر بررسی نام‌ها', style: TextStyle(color: Colors.white70, fontSize: 12)), const SizedBox(height: 8), Text('مشاهده آرشیو  ←', style: TextStyle(color: const Color(0xFFF6EDDC), fontWeight: FontWeight.w800, fontSize: 12))]))),
              SizedBox(width: 128, height: 116, child: Image.asset('assets/images/archive_illustration.png', fit: BoxFit.cover)),
            ],
          ),
        ),
      ),
    );
  }
}
