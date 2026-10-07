import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../domain/traditions/chinese_zodiac.dart';
import '../domain/traditions/manazil.dart';
import '../domain/traditions/numerology.dart';
import '../domain/traditions/tzolkin.dart';
import '../domain/traditions/vedic.dart';
import 'app_providers.dart';

/// Providers for the five world-tradition modules.
///
/// All of them derive purely from the birth date (Jalali key) already
/// stored in the profile — nothing new is collected from the user.

/// Jalali birth key ("1370-05-12") + optional "08:30" → UTC instant.
///
/// Birth time is treated as Iran standard time (UTC+3:30; Iran has had no
/// DST since 2022). When the time is unknown, noon is used (the Moon moves
/// ~6°/day, so this only matters for births right on a mansion boundary —
/// the UI discloses the approximation).
DateTime? birthUtcFrom(String key, {String? time}) {
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  final Jalali jalali;
  try {
    jalali = Jalali(y, m, d);
  } catch (_) {
    return null;
  }
  final g = jalali.toDateTime();
  var hour = 12;
  var minute = 0;
  if (time != null) {
    final t = time.split(':');
    if (t.length == 2) {
      final h = int.tryParse(t[0]);
      final mi = int.tryParse(t[1]);
      if (h != null && mi != null && h >= 0 && h < 24 && mi >= 0 && mi < 60) {
        hour = h;
        minute = mi;
      }
    }
  }
  return DateTime.utc(g.year, g.month, g.day, hour, minute)
      .subtract(const Duration(minutes: 210));
}

final birthUtcProvider = Provider<DateTime?>((ref) {
  final state = ref.watch(primaryProfileProvider);
  final profile = state.profile;
  if (profile == null) return null;
  return birthUtcFrom(
    profile.birthDate,
    time: profile.birthTimeKnown ? profile.birthTime : null,
  );
});

/// Whether the profile carries a real birth time (drives the
/// approximation notice on the Moon-based traditions).
final birthTimeKnownProvider = Provider<bool>((ref) {
  final state = ref.watch(primaryProfileProvider);
  return state.profile?.birthTimeKnown ?? false;
});

final chineseSignProvider = Provider<ChineseSign?>((ref) {
  final birth = ref.watch(birthUtcProvider);
  if (birth == null) return null;
  return ChineseZodiacCalculator.signFor(birth);
});

final partnerChineseSignProvider = Provider<ChineseSign?>((ref) {
  final state = ref.watch(partnerProvider);
  final partner = state.partner;
  if (partner == null) return null;
  final birth = birthUtcFrom(partner.birthDate, time: partner.birthTime);
  if (birth == null) return null;
  return ChineseZodiacCalculator.signFor(birth);
});

final lifePathProvider = Provider<int?>((ref) {
  final birth = ref.watch(birthUtcProvider);
  if (birth == null) return null;
  return NumerologyCalculator.lifePath(birth);
});

final personalYearProvider = Provider<int?>((ref) {
  final birth = ref.watch(birthUtcProvider);
  if (birth == null) return null;
  return NumerologyCalculator.personalYear(birth, DateTime.now().year);
});

/// Raw Abjad value of the display name (null when the name has no
/// Abjad-counted letters).
final abjadValueProvider = Provider<int?>((ref) {
  final state = ref.watch(primaryProfileProvider);
  final profile = state.profile;
  if (profile == null || profile.name.trim().isEmpty) return null;
  final value = NumerologyCalculator.abjadValue(profile.name);
  return value > 0 ? value : null;
});

final vedicChartProvider = Provider<VedicChart?>((ref) {
  final birth = ref.watch(birthUtcProvider);
  if (birth == null) return null;
  return VedicCalculator.forDateTime(birth);
});

final tzolkinProvider = Provider<TzolkinDay?>((ref) {
  final birth = ref.watch(birthUtcProvider);
  if (birth == null) return null;
  return TzolkinCalculator.forDate(birth);
});

/// Mansion of the Moon at the user's birth (index 0–27).
final birthManzilProvider = Provider<int?>((ref) {
  final birth = ref.watch(birthUtcProvider);
  if (birth == null) return null;
  return ManazilCalculator.indexFor(birth);
});

/// Mansion of the Moon right now (live astronomy, changes ~daily).
final todayManzilProvider =
    Provider<int>((ref) => ManazilCalculator.indexFor(DateTime.now().toUtc()));
