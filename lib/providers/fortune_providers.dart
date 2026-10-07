import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/fortunes/fortune_engines.dart';
import '../domain/zodiac/zodiac_sign.dart';
import 'app_providers.dart';
import 'tradition_providers.dart' show birthUtcProvider;

/// Providers for the seven fortune modules. All of them derive from the
/// profile (name + Jalali birth key) — nothing new is collected.

/// The user's Western ZodiacSign (null until a profile exists).
final profileSignProvider = Provider<ZodiacSign?>((ref) {
  final state = ref.watch(primaryProfileProvider);
  final id = state.profile?.zodiacId;
  if (id == null) return null;
  final repo = ref.watch(zodiacRepositoryProvider);
  return repo.byId(id);
});

/// Display name of the primary profile (fallback: generic).
final profileNameProvider = Provider<String>((ref) {
  final state = ref.watch(primaryProfileProvider);
  final name = state.profile?.name.trim();
  if (name == null || name.isEmpty) return 'مسافرِ آسمان';
  return name;
});

/// Jalali birth month (1..12) parsed straight from the birth key.
final birthMonthProvider = Provider<int?>((ref) {
  final state = ref.watch(primaryProfileProvider);
  final key = state.profile?.birthDate;
  if (key == null) return null;
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final m = int.tryParse(parts[1]);
  if (m == null || m < 1 || m > 12) return null;
  return m;
});

/// Gregorian civil birth date (for the tarot birth card) — converted
/// from the Jalali key, independent of any timezone.
final birthGregorianProvider = Provider<DateTime?>((ref) {
  final birth = ref.watch(birthUtcProvider);
  if (birth == null) return null;
  return DateTime(birth.year, birth.month, birth.day);
});

final gemBirthstoneProvider = Provider<Map<String, Object?>?>((ref) {
  final month = ref.watch(birthMonthProvider);
  if (month == null) return null;
  return GemOracle.birthstoneFor(month);
});

final greekProfileProvider = Provider<Map<String, Object?>?>((ref) {
  final sign = ref.watch(profileSignProvider);
  if (sign == null) return null;
  return GreekAstrology.forSignId(sign.id);
});

final marriageProfileProvider = Provider<Map<String, Object?>?>((ref) {
  final sign = ref.watch(profileSignProvider);
  if (sign == null) return null;
  return MarriageAstrology.forSignId(sign.id);
});

final monthTraitProvider = Provider<Map<String, Object?>?>((ref) {
  final month = ref.watch(birthMonthProvider);
  if (month == null) return null;
  return MonthTraits.forMonth(month);
});

final tarotBirthCardProvider = Provider<Map<String, Object?>?>((ref) {
  final g = ref.watch(birthGregorianProvider);
  if (g == null) return null;
  return Tarot.card(Tarot.birthCard(g));
});

final spiritAnimalProvider = Provider<Map<String, Object?>?>((ref) {
  final sign = ref.watch(profileSignProvider);
  if (sign == null) return null;
  return SpiritAnimal.forSignId(sign.id);
});
