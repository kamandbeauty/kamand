import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/persian_numbers.dart';
import '../../data/content/fortunes_content.dart';
import '../../domain/fortunes/fortune_engines.dart';
import '../../providers/fortune_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/glass_card.dart';
import '../traditions/tradition_widgets.dart';

/// فال ابجد — نام + نام مادر + نیت.
class AbjadFalScreen extends ConsumerStatefulWidget {
  const AbjadFalScreen({super.key});

  @override
  ConsumerState<AbjadFalScreen> createState() => _AbjadFalScreenState();
}

class _AbjadFalScreenState extends ConsumerState<AbjadFalScreen> {
  late final TextEditingController _name;
  final TextEditingController _mother = TextEditingController();
  final TextEditingController _niyat = TextEditingController();
  String? _result;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: ref.read(profileNameProvider));
  }

  @override
  void dispose() {
    _name.dispose();
    _mother.dispose();
    _niyat.dispose();
    super.dispose();
  }

  void _read() {
    setState(() {
      _submitted = true;
      final name = _name.text.trim();
      final mother = _mother.text.trim();
      if (name.isEmpty && mother.isEmpty) {
        _result = null;
        return;
      }
      _result = AbjadFortune.fortuneFor(
        name: name,
        motherName: mother,
        dayKey: _todayKey(),
      );
    });
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('فال ابجد')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          GlassCard(
            highlight: true,
            accent: AppTheme.violet,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BodyText(FortunesContent.abjadFalIntro),
                const SizedBox(height: 14),
                _Field(controller: _name, label: 'نامِ خودت', icon: Icons.person_outline),
                const SizedBox(height: 10),
                _Field(controller: _mother, label: 'نامِ مادرت', icon: Icons.favorite_border),
                const SizedBox(height: 10),
                _Field(
                  controller: _niyat,
                  label: 'نیت یا سؤالت (اختیاری)',
                  icon: Icons.help_outline,
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _read,
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: const Text('فال بگیر'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_result != null) ...[
            const SectionHeader('تعبیرِ فال'),
            GlassCard(
              accent: AppTheme.gold,
              child: Column(
                children: [
                  _AbjadNumbers(
                    name: _name.text.trim(),
                    mother: _mother.text.trim(),
                  ),
                  const SizedBox(height: 12),
                  BodyText(_result!),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else if (_submitted)
            const ErrorState(message: 'حداقل نامِ خودت یا نامِ مادرت را وارد کن.')
          else
            GlassCard(
              accent: AppTheme.sky,
              child: BodyText(
                'در فالِ ابجد، هرچه بنویسی فقط نزد خودت می‌ماند — این فال '
                'کاملاً روی گوشیِ تو محاسبه می‌شود و هیچ‌جا ارسال نمی‌شود.',
              ),
            ),
          const SizedBox(height: 20),
          const DisclaimerCard(),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.label, required this.icon});

  final TextEditingController controller;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textDirection: TextDirection.rtl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        isDense: true,
      ),
    );
  }
}

/// The abjad number breakdown of the entered names.
class _AbjadNumbers extends StatelessWidget {
  const _AbjadNumbers({required this.name, required this.mother});

  final String name;
  final String mother;

  @override
  Widget build(BuildContext context) {
    final nameValue = name.isEmpty ? 0 : AbjadFortune.valueOf(name);
    final motherValue = mother.isEmpty ? 0 : AbjadFortune.valueOf(mother);
    final total = nameValue + motherValue;
    final hasName = name.isNotEmpty;
    final hasMother = mother.isNotEmpty;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        if (hasName)
          NatureChip('ابجدِ نام: ${PersianNumbers.format(nameValue)}',
              color: AppTheme.violet),
        if (hasMother)
          NatureChip('ابجدِ مادر: ${PersianNumbers.format(motherValue)}',
              color: AppTheme.rose),
        if (hasName || hasMother)
          NatureChip('جمع: ${PersianNumbers.format(total)}',
              color: AppTheme.gold),
      ],
    );
  }
}
