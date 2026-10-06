import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../core/date/app_date.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/persian_numbers.dart';

/// Jalali birth-date picker: three wheels (day/month/year).
///
/// Used by onboarding, profile edit and partner form. All validation is
/// local; invalid combos (e.g. ۳۱ مهر) can never be constructed because the
/// day list is re-built per month.
class BirthDateField extends StatelessWidget {
  const BirthDateField({
    super.key,
    required this.year,
    required this.month,
    required this.day,
    required this.onChanged,
    this.errorText,
  });

  final int year;
  final int month;
  final int day;
  final void Function(int year, int month, int day) onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = AppDate.monthLength(year, month);
    final effectiveDay = day > daysInMonth ? daysInMonth : day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _Wheel(
                label: 'سال',
                value: year,
                items: List.generate(
                  100,
                  (i) => AppDate.maxBirthYear - i,
                ),
                onChanged: (v) => _emit(v, month, effectiveDay),
                display: (v) => PersianNumbers.toPersian(v.toString()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: _Wheel(
                label: 'ماه',
                value: month,
                items: List.generate(12, (i) => i + 1),
                onChanged: (v) => _emit(year, v, effectiveDay),
                display: (v) => AppDate.monthNames[v - 1],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _Wheel(
                label: 'روز',
                value: effectiveDay,
                items: List.generate(daysInMonth, (i) => i + 1),
                onChanged: (v) => _emit(year, month, v),
                display: (v) => PersianNumbers.toPersian(v.toString()),
              ),
            ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 4),
            child: Text(
              errorText!,
              style: const TextStyle(color: Color(0xFFFF7D9C), fontSize: 11.5),
            ),
          ),
      ],
    );
  }

  void _emit(int y, int m, int d) {
    final maxDay = AppDate.monthLength(y, m);
    onChanged(y, m, d > maxDay ? maxDay : d);
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.display,
  });

  final String label;
  final int value;
  final List<int> items;
  final ValueChanged<int> onChanged;
  final String Function(int) display;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4, bottom: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Vazirmatn',
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ),
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? AppTheme.darkCardHigh
                : const Color(0xFFEEEDF9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            ),
          ),
          child: ListWheelScrollView.useDelegate(
            itemExtent: 42,
            diameterRatio: 1.6,
            physics: const FixedExtentScrollPhysics(),
            controller: FixedExtentScrollController(
              initialItem: items.indexOf(value) < 0 ? 0 : items.indexOf(value),
            ),
            onSelectedItemChanged: (i) => onChanged(items[i]),
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: items.length,
              builder: (context, index) {
                final selected = items[index] == value;
                return Center(
                  child: Text(
                    display(items[index]),
                    style: TextStyle(
                      fontSize: selected ? 15 : 13,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                      color: selected
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.45),
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// Optional birth-time picker (hour:minute) with a "don't know" option.
class BirthTimeField extends StatelessWidget {
  const BirthTimeField({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final int? selected; // null = unknown
  final ValueChanged<int?> onChanged; // minutes since midnight

  String get _display {
    if (selected == null) return '';
    final h = selected! ~/ 60;
    final m = selected! % 60;
    return '${PersianNumbers.twoDigits(h)}:${PersianNumbers.twoDigits(m)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        InkWell(
          onTap: () async {
            final initial = selected == null
                ? TimeOfDay.now()
                : TimeOfDay(hour: selected! ~/ 60, minute: selected! % 60);
            final picked = await showTimePicker(
              context: context,
              initialTime: initial,
              helpText: 'ساعت تولد',
              confirmText: 'تأیید',
              cancelText: 'انصراف',
              hourLabelText: 'ساعت',
              minuteLabelText: 'دقیقه',
            );
            if (picked != null) {
              onChanged(picked.hour * 60 + picked.minute);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? AppTheme.darkCardHigh
                  : const Color(0xFFEEEDF9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule,
                    size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    selected == null
                        ? 'انتخاب ساعت تولد (اختیاری)'
                        : 'ساعت تولد: ${_display}',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: theme.colorScheme.onSurface,
                      fontFamily: 'Vazirmatn',
                    ),
                  ),
                ),
                if (selected != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => onChanged(null),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () => onChanged(null),
          icon: const Icon(Icons.help_outline, size: 16),
          label: const Text('ساعت تولدم را نمی‌دانم'),
        ),
      ],
    );
  }
}

/// Jalali → time-of-day label for storage ("08:30").
String minutesToTimeString(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Parses "08:30" → minutes, or null.
int? timeStringToMinutes(String? s) {
  if (s == null) return null;
  final parts = s.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
    return null;
  }
  return h * 60 + m;
}

/// Utility used by forms to format a Jalali key for display.
String formatJalaliKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return key;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return key;
  return AppDate.formatMedium(Jalali(y, m, d));
}
