import 'package:flutter/material.dart';

import '../../../core/app_strings.dart';
import '../../../core/app_theme.dart';
import '../../../core/persian_utils.dart';
import '../../../game_engine/scoring/score_manager.dart';

/// جدول امتیازات دست‌های مسابقه — مثل دفترچهٔ امتیازِ حکم روی میز:
/// برای هر دست، دورهای هر دو تیم، مجموع امتیاز و قانون ویژه (کوت/حاکم‌کوت).
class ScoreTable extends StatelessWidget {
  const ScoreTable({super.key, required this.records});

  final List<RoundRecord> records;

  // نسبت عرض ستون‌ها: دست | دست‌شما | دست‌حریف | کل‌شما | کل‌حریف | قانون
  static const _flex = [3, 2, 2, 2, 2, 3];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _groupHeader(),
          _subHeader(),
          _rows(),
        ],
      ),
    );
  }

  // --- سرستون گروهی: «امتیاز دست» و «امتیاز کل» روی دو زیرستون ---
  Widget _groupHeader() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.gold.withOpacity(0.10),
        border: const Border(
            bottom: BorderSide(color: Colors.white12, width: 0.7)),
      ),
      child: Row(
        children: [
          _hCell('', _flex[0], bold: true),
          _hCell(AppStrings.tricksColumn, _flex[1] + _flex[2], bold: true),
          _hCell(AppStrings.totalColumn, _flex[3] + _flex[4], bold: true),
          _hCell('', _flex[5], bold: true),
        ],
      ),
    );
  }

  Widget _subHeader() {
    const labels = [
      AppStrings.roundColumn,
      AppStrings.youColumn,
      AppStrings.themColumn,
      AppStrings.youColumn,
      AppStrings.themColumn,
      AppStrings.ruleColumn,
    ];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12, width: 0.7)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            _hCell(labels[i], _flex[i], dim: true),
        ],
      ),
    );
  }

  Widget _rows() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 172),
      child: SingleChildScrollView(
        reverse: true, // آخرین دست همیشه دیده شود
        child: Column(
          children: [
            for (var i = 0; i < records.length; i++) _recordRow(records[i], i),
          ],
        ),
      ),
    );
  }

  Widget _recordRow(RoundRecord r, int index) {
    final cells = <Widget>[
      _cell(persianOrdinal(r.roundNumber), _flex[0], dim: true),
      _cell(toPersianDigits(r.tricksUs), _flex[1]),
      _cell(toPersianDigits(r.tricksThem), _flex[2]),
      _cell(
        toPersianDigits(r.totalUs),
        _flex[3],
        bold: true,
        highlighted: r.winnerIsUs,
      ),
      _cell(
        toPersianDigits(r.totalThem),
        _flex[4],
        bold: true,
        highlighted: !r.winnerIsUs,
      ),
      _cell(r.ruleLabel, _flex[5], dim: !r.isKoot && !r.isHakimKoot),
    ];
    return Container(
      decoration: BoxDecoration(
        color: index.isOdd ? Colors.white.withOpacity(0.025) : null,
        border: const Border(
            bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(children: cells),
    );
  }

  Widget _hCell(String text, int flex, {bool bold = false, bool dim = false}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: dim ? Colors.white54 : AppTheme.goldLight,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell(
    String text,
    int flex, {
    bool bold = false,
    bool dim = false,
    bool highlighted = false,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: highlighted
            ? BoxDecoration(
                color: AppTheme.gold.withOpacity(0.22),
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppTheme.gold.withOpacity(0.55)),
              )
            : null,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: highlighted || bold ? FontWeight.w800 : FontWeight.w500,
                color: highlighted
                    ? AppTheme.gold
                    : (dim ? Colors.white54 : Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
