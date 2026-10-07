/// تنظیمات بازی: سطح حریف، تم زمین، طرح کارت و قوانین.
library;

import 'package:flutter/material.dart';

import '../../game/scoring.dart';
import '../../model/enums.dart';
import '../../state/game_controller.dart';
import '../../state/settings.dart';
import '../../util/persian.dart';
import '../theme.dart';
import '../widgets/card_view.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings s = widget.controller.settings.copy();
  late final TextEditingController _nameController =
      TextEditingController(text: s.playerName);

  bool get inGame => widget.controller.engine != null;

  void _apply(void Function() change) {
    setState(change);
    widget.controller.applySettings(s);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تنظیمات'),
        backgroundColor: AppColors.panel,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 30),
        children: <Widget>[
          _section('بازیکن'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: TextField(
              controller: _nameController,
              maxLength: 12,
              decoration: const InputDecoration(
                labelText: 'نام شما',
                counterText: '',
                border: OutlineInputBorder(),
              ),
              onChanged: (String v) => _apply(() => s.playerName = v),
            ),
          ),

          _section('تعداد بازیکنان'),
          _SelectTile(
            title: 'چهار نفره (دو تیم دو نفره)',
            subtitle: 'بازی کلاسیکِ شلم: شما و یارتان در برابر دو حریف. '
                'هر نفر ۱۲ برگ، ۱۲ دست، ۱۶۵ امتیاز.',
            selected: s.rules.players == 4,
            onTap: () => _apply(() => s.rules = s.rulesWith(players: 4)),
          ),
          _SelectTile(
            title: 'دو نفره (نفر به نفر)',
            subtitle: 'شما در برابر یک حریف. هر نفر ۱۲ برگ و بعد از هر دست '
                'یک برگ از روی هم برمی‌دارید؛ ۲۴ دست و ۲۲۵ امتیاز.',
            selected: s.rules.players == 2,
            onTap: () => _apply(() => s.rules = s.rulesWith(players: 2)),
          ),

          _section('سطح حریف‌ها'),
          for (final Difficulty d in Difficulty.values)
            _SelectTile(
              title: d.fa,
              subtitle: d.description,
              selected: s.difficulty == d,
              onTap: () => _apply(() => s.difficulty = d),
            ),

          _section('محیط بازی'),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.05,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: <Widget>[
              for (final TableSurface t in TableSurface.values)
                _SurfaceTile(
                  surface: t,
                  selected: s.surface == t,
                  onTap: () => _apply(() => s.surface = t),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              s.surface.faHint,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFFB7AA92)),
            ),
          ),

          _section('طرح پشت کارت'),
          SizedBox(
            height: 92,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                for (final CardBack b in CardBack.values)
                  GestureDetector(
                    onTap: () => _apply(() => s.cardBack = b),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: s.cardBack == b
                              ? AppColors.gold
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          CardBackView(width: 40, back: b),
                          const SizedBox(height: 3),
                          Text(b.fa, style: const TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          _section('نمایش و صدا'),
          _segment<GameSpeed>(
            label: 'سرعت بازی',
            value: s.speed,
            values: GameSpeed.values,
            labels: GameSpeed.values.map((GameSpeed v) => v.fa).toList(),
            onChanged: (GameSpeed v) => _apply(() => s.speed = v),
          ),
          _ToggleTile(
            value: s.sound,
            onChanged: (bool v) => _apply(() => s.sound = v),
            title: const Text('افکت صوتی'),
          ),
          _ToggleTile(
            value: s.haptics,
            onChanged: (bool v) => _apply(() => s.haptics = v),
            title: const Text('لرزش'),
          ),
          _ToggleTile(
            value: s.highlightLegal,
            onChanged: (bool v) => _apply(() => s.highlightLegal = v),
            title: const Text('هایلایت کارت‌های مجاز'),
          ),
          _ToggleTile(
            value: s.sortHand,
            onChanged: (bool v) => _apply(() => s.sortHand = v),
            title: const Text('مرتب‌سازی خودکار دست'),
          ),
          _ToggleTile(
            value: s.showBotHands,
            onChanged: (bool v) => _apply(() => s.showBotHands = v),
            title: const Text('حالت تمرین (دیدن کارت ربات‌ها)'),
          ),

          _section('قوانین'),
          if (inGame)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'تغییر قوانینِ پایه از راند بعد اعمال می‌شود.',
                style: TextStyle(fontSize: 11, color: Color(0xFFBDAE92)),
              ),
            ),
          _ToggleTile(
            value: s.declareTrumpWithPicker,
            onChanged: (bool v) => _apply(() => s.declareTrumpWithPicker = v),
            title: const Text('اعلام حکم از منو'),
            subtitle: const Text(
              'به‌جای قانون سنتیِ «اولین برگِ حاکم، حکم را تعیین می‌کند»',
              style: TextStyle(fontSize: 11),
            ),
          ),
          _ToggleTile(
            value: s.rules.withJokers,
            onChanged: (bool v) => _apply(() => s.rules = s.rulesWith(withJokers: v)),
            title: const Text('بازی با جوکر (۲۰۰ امتیازی)'),
            subtitle: const Text(
              'جوکر قرمز ۲۰ و سیاه ۱۵ امتیاز؛ گلِ وسط ۶ برگ و حداقل خواندن ۱۲۰',
              style: TextStyle(fontSize: 11),
            ),
          ),
          _ToggleTile(
            value: s.rules.allowShelemBid,
            onChanged: (bool v) => _apply(() => s.rules = s.rulesWith(allowShelemBid: v)),
            title: const Text('اجازهٔ خواندنِ «شلم»'),
            subtitle: const Text(
              'تعهد به گرفتن تمام دست‌ها (۳۳۰ مثبت یا منفی)',
              style: TextStyle(fontSize: 11),
            ),
          ),
          _ToggleTile(
            value: s.rules.allowSarShelemBid,
            onChanged: (bool v) => _apply(() => s.rules = s.rulesWith(allowSarShelemBid: v)),
            title: const Text('اجازهٔ «سرشلم» (شلمِ بسته)'),
            subtitle: const Text(
              'بدون برداشتن گل، تمام دست‌ها (۶۶۰ مثبت یا منفی)',
              style: TextStyle(fontSize: 11),
            ),
          ),
          _ToggleTile(
            value: s.rules.forceDealerBidOnAllPass,
            onChanged: (bool v) => _apply(
                () => s.rules = s.rulesWith(forceDealerBidOnAllPass: v)),
            title: const Text('اجبار صاحب‌دست در صورت پاسِ همه'),
            subtitle: const Text(
              'در غیر این صورت کارت‌ها دوباره پخش می‌شود',
              style: TextStyle(fontSize: 11),
            ),
          ),
          _segment<YasaRule>(
            label: 'قانون یاسا',
            value: s.rules.scoring.yasa,
            values: YasaRule.values,
            labels: const <String>['ندارد', 'کمتر از حریف', 'کمتر از نصف'],
            onChanged: (YasaRule v) =>
                _apply(() => s.rules = s.rulesWith(yasa: v)),
          ),
          _segment<HakemAward>(
            label: 'امتیاز حاکم در صورت برد',
            value: s.rules.scoring.hakemAward,
            values: HakemAward.values,
            labels: const <String>['عددِ قرارداد', 'امتیاز واقعی'],
            onChanged: (HakemAward v) =>
                _apply(() => s.rules = s.rulesWith(hakemAward: v)),
          ),
          _segment<SlamAward>(
            label: 'پاداش شلم',
            value: s.rules.scoring.slamAward,
            values: SlamAward.values,
            labels: const <String>['۲ برابر قرارداد', '۳۳۰ ثابت'],
            onChanged: (SlamAward v) =>
                _apply(() => s.rules = s.rulesWith(slamAward: v)),
          ),
          _ToggleTile(
            value: s.rules.scoring.opponentAlwaysScores,
            onChanged: (bool v) => _apply(() => s.rules = s.rulesWith(opponentAlwaysScores: v)),
            title: const Text('تیم مقابل همیشه امتیازش را می‌گیرد'),
          ),
          _segment<int>(
            label: 'امتیاز پایان بازی',
            value: s.rules.targetScore,
            values: const <int>[660, 1100, 1165, 1200],
            labels: <String>[fa(660), fa(1100), fa(1165), fa(1200)],
            onChanged: (int v) =>
                _apply(() => s.rules = s.rulesWith(targetScore: v)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 6),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: AppColors.gold,
          ),
        ),
      );

  Widget _segment<T>({
    required String label,
    required T value,
    required List<T> values,
    required List<String> labels,
    required void Function(T) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: <Widget>[
              for (int i = 0; i < values.length; i++)
                ChoiceChip(
                  label: Text(labels[i], style: const TextStyle(fontSize: 12)),
                  selected: value == values[i],
                  onSelected: (_) => onChanged(values[i]),
                  selectedColor: AppColors.gold,
                  labelStyle: TextStyle(
                    color: value == values[i]
                        ? const Color(0xFF241B06)
                        : const Color(0xFFE6DAC2),
                  ),
                  backgroundColor: AppColors.panelLight,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SurfaceTile extends StatelessWidget {
  const _SurfaceTile({
    required this.surface,
    required this.selected,
    required this.onTap,
  });

  final TableSurface surface;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? asset = surface.asset;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.gold : Colors.white24,
            width: selected ? 2.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (asset != null)
              Image.asset(asset, fit: BoxFit.cover)
            else
              const DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFF156B4A)),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                color: Colors.black.withValues(alpha: 0.55),
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(
                  surface.fa,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    color: selected ? AppColors.gold : Colors.white,
                  ),
                ),
              ),
            ),
            if (selected)
              Align(
                alignment: Alignment.topLeft,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 12,
                    color: Color(0xFF1C2B22),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ردیف انتخابی با علامت تیک (جایگزین RadioListTile).
class _SelectTile extends StatelessWidget {
  const _SelectTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          children: <Widget>[
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.gold : Colors.white38,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected ? AppColors.gold : null,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFBDAE92),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// کلید روشن/خاموش با عنوان و توضیح.
class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget title;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  DefaultTextStyle.merge(
                    style: const TextStyle(fontSize: 14),
                    child: title,
                  ),
                  if (subtitle != null)
                    DefaultTextStyle.merge(
                      style: const TextStyle(color: Color(0xFFBDAE92)),
                      child: subtitle!,
                    ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
