import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/date/app_date.dart';
import '../domain/compatibility/compatibility_engine.dart';
import '../domain/horoscope/horoscope_models.dart';
import '../domain/zodiac/zodiac_sign.dart';
import 'app_providers.dart';

/// Today's daily horoscope for the active profile's sign (cache-or-generate).
final dailyHoroscopeProvider =
    FutureProvider.autoDispose<DailyHoroscope>((ref) async {
  final profile = ref.watch(primaryProfileProvider);
  if (!profile.ready || profile.profile == null) {
    throw StateError('no profile');
  }
  final repo = ref.watch(horoscopeRepositoryProvider);
  return repo.dailyFor(profile.profile!.zodiacId, AppDate.now());
});

/// Current week (Saturday→Friday) for the active sign.
final weeklyHoroscopeProvider =
    FutureProvider.autoDispose<WeeklyHoroscope>((ref) async {
  final profile = ref.watch(primaryProfileProvider);
  if (!profile.ready || profile.profile == null) {
    throw StateError('no profile');
  }
  final engine = ref.watch(horoscopeEngineProvider);
  final repo = ref.watch(horoscopeRepositoryProvider);
  final weekStart = AppDate.weekStart(AppDate.now());
  final dailies = await repo.weekFor(profile.profile!.zodiacId, weekStart);
  final days = <WeeklyDay>[
    for (var i = 0; i < dailies.length; i++)
      WeeklyDay(
        date: AppDate.addDays(weekStart, i),
        scores: dailies[i].scores,
      ),
  ];
  return WeeklyHoroscope(
    zodiacId: profile.profile!.zodiacId,
    weekStart: weekStart,
    days: days,
    summaryText:
        engine.generateWeeklyById(profile.profile!.zodiacId, weekStart)
            .summaryText,
  );
});

/// Current Jalali month for the active sign.
final monthlyHoroscopeProvider =
    FutureProvider.autoDispose<MonthlyHoroscope>((ref) async {
  final profile = ref.watch(primaryProfileProvider);
  if (!profile.ready || profile.profile == null) {
    throw StateError('no profile');
  }
  final repo = ref.watch(horoscopeRepositoryProvider);
  final now = AppDate.now();
  return repo.monthlyFor(profile.profile!.zodiacId, now.year, now.month);
});

class CompatibilityParams {
  const CompatibilityParams(this.signA, this.signB);

  final String signA;
  final String signB;

  @override
  bool operator ==(Object other) =>
      other is CompatibilityParams &&
      ((other.signA == signA && other.signB == signB) ||
          (other.signA == signB && other.signB == signA));

  @override
  int get hashCode => signA.hashCode ^ signB.hashCode;
}

/// Compatibility between two signs (symmetric).
final compatibilityProvider = FutureProvider.autoDispose
    .family<CompatibilityResult, CompatibilityParams>((ref, params) async {
  final engine = ref.watch(compatibilityEngineProvider);
  return engine.compute(params.signA, params.signB);
});

/// All 12 signs ranked against the active profile's sign.
class RankedCompatibility {
  const RankedCompatibility({
    required this.userSignId,
    required this.ranked,
    required this.best,
    required this.challenging,
  });

  final String userSignId;
  final List<CompatibilityResult> ranked;
  final List<CompatibilityResult> best;
  final List<CompatibilityResult> challenging;
}

final rankedCompatibilityProvider =
    FutureProvider.autoDispose<RankedCompatibility>((ref) async {
  final profile = ref.watch(primaryProfileProvider);
  if (!profile.ready || profile.profile == null) {
    throw StateError('no profile');
  }
  final engine = ref.watch(compatibilityEngineProvider);
  final ranked = engine.rankedFor(profile.profile!.zodiacId);
  return RankedCompatibility(
    userSignId: profile.profile!.zodiacId,
    ranked: ranked,
    best: ranked.take(3).toList(),
    challenging: ranked.reversed.take(3).toList(),
  );
});

/// Compatibility between the user and their partner (if any).
final coupleCompatibilityProvider =
    FutureProvider.autoDispose<CompatibilityResult?>((ref) async {
  final profile = ref.watch(primaryProfileProvider);
  final partnerState = ref.watch(partnerProvider);
  if (!profile.ready || profile.profile == null) return null;
  if (!partnerState.ready || partnerState.partner == null) return null;
  final engine = ref.watch(compatibilityEngineProvider);
  return engine.compute(
    profile.profile!.zodiacId,
    partnerState.partner!.zodiacId,
  );
});

/// Resolves a zodiac sign object for any id (static data — sync).
final zodiacSignByIdProvider =
    Provider.autoDispose.family<ZodiacSign?, String>((ref, id) {
  return ref.watch(zodiacRepositoryProvider).byId(id);
});

/// The three days after today for the active profile's sign — the home
/// screen's "روزهای پیشِ رو" strip (mockup: "Braver Days Ahead").
final upcomingDaysProvider =
    FutureProvider.autoDispose<List<DailyHoroscope>>((ref) async {
  final profile = ref.watch(primaryProfileProvider);
  if (!profile.ready || profile.profile == null) {
    throw StateError('no profile');
  }
  final repo = ref.watch(horoscopeRepositoryProvider);
  final today = AppDate.now();
  return [
    for (var k = 1; k <= 3; k++)
      await repo.dailyFor(profile.profile!.zodiacId, AppDate.addDays(today, k)),
  ];
});

/// Today's horoscope for *all twelve* signs — the home screen's zodiac
/// strip (mockup: the 12-sign row with percentages).
final allSignsTodayProvider =
    FutureProvider.autoDispose<List<DailyHoroscope>>((ref) async {
  final repo = ref.watch(horoscopeRepositoryProvider);
  final zodiac = ref.watch(zodiacRepositoryProvider);
  final today = AppDate.now();
  return [
    for (final sign in zodiac.allSigns())
      await repo.dailyFor(sign.id, today),
  ];
});
