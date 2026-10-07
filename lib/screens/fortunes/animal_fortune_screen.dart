import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/content/fortunes_content.dart';
import '../../providers/fortune_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import '../traditions/tradition_widgets.dart';

/// حیوان درون — روحِ حیوانیِ برج تو.
class AnimalFortuneScreen extends ConsumerWidget {
  const AnimalFortuneScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sign = ref.watch(profileSignProvider);
    final animal = ref.watch(spiritAnimalProvider);

    if (sign == null || animal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('حیوان درون')),
        body: const ErrorState(message: 'ابتدا تاریخ تولدت را در پروفایل وارد کن.'),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('حیوان درون')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          GlassCard(
            highlight: true,
            accent: const Color(0xFF4CD97B),
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Text('حیوان درونِ برج ${sign.nameFa}',
                    style: _kLabel(theme)),
                const SizedBox(height: 10),
                TraditionEmblem(
                  accent: const Color(0xFF4CD97B),
                  size: 100,
                  child: Text(
                    animal['emoji']! as String,
                    style: const TextStyle(fontSize: 52),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  animal['animal']! as String,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Vazirmatn',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GlassCard(
            accent: const Color(0xFF4CD97B),
            child: BodyText(animal['text']! as String),
          ),
          const SizedBox(height: 20),

          const SectionHeader('روایت سنت'),
          GlassCard(child: BodyText(FortunesContent.animalIntro)),
          const SizedBox(height: 20),

          const SectionHeader('دوازده روحِ حیوانی'),
          GlassCard(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in FortunesContent.spiritAnimals)
                  NatureChip(
                    '${a['emoji']! as String} ${a['animal']! as String}',
                    color: const Color(0xFF4CD97B),
                  ),
              ],
            ),
          ),
          const DisclaimerCard(),
        ],
      ),
    );
  }

  static TextStyle _kLabel(ThemeData theme) => TextStyle(
        fontSize: 12,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        fontFamily: 'Vazirmatn',
      );
}
