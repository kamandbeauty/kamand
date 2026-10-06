import '../../data/content/app_content.dart';
import 'zodiac_sign.dart';

/// Repository abstraction over zodiac static data.
///
/// Today the source is the generated [AppContent] constant (offline-first).
/// A future remote repository can implement the same interface.
abstract class ZodiacRepository {
  List<ZodiacSign> allSigns();
  ZodiacSign? byId(String id);
  ZodiacSign byIdOrFail(String id);
}

class LocalZodiacRepository implements ZodiacRepository {
  const LocalZodiacRepository();

  static List<ZodiacSign>? _cache;

  static List<ZodiacSign> _parse() {
    if (_cache != null) return _cache!;
    final signs = <ZodiacSign>[];
    for (final raw in AppContent.zodiacSigns) {
      final daily = raw['daily']! as Map<String, Object?>;
      final weekly = raw['weekly']! as Map<String, Object?>;
      final monthly = raw['monthly']! as Map<String, Object?>;
      signs.add(
        ZodiacSign(
          id: raw['id']! as String,
          nameFa: raw['nameFa']! as String,
          nameEn: raw['nameEn']! as String,
          symbol: raw['symbol']! as String,
          startMonth: raw['startMonth']! as int,
          startDay: raw['startDay']! as int,
          endMonth: raw['endMonth']! as int,
          endDay: raw['endDay']! as int,
          element: raw['element']! as String,
          elementId: raw['elementId']! as String,
          rulingPlanet: raw['rulingPlanet']! as String,
          description: raw['description']! as String,
          personality: raw['personality']! as String,
          strengths: _strings(raw['strengths']),
          weaknesses: _strings(raw['weaknesses']),
          loveStyle: raw['loveStyle']! as String,
          workStyle: raw['workStyle']! as String,
          friendshipStyle: raw['friendshipStyle']! as String,
          luckyColors: _strings(raw['luckyColors']),
          luckyNumbers: _ints(raw['luckyNumbers']),
          luckyTimes: _strings(raw['luckyTimes']),
          dailyGeneral: _strings(daily['general']),
          dailyLove: _strings(daily['love']),
          dailyCareer: _strings(daily['career']),
          dailyFinance: _strings(daily['finance']),
          dailyMood: _strings(daily['mood']),
          dailyWarning: _strings(daily['warning']),
          dailyOpportunity: _strings(daily['opportunity']),
          weeklySummaries: _strings(weekly['summaries']),
          monthlyFocus: _strings(monthly['focus']),
          monthlyLove: _strings(monthly['love']),
          monthlyCareer: _strings(monthly['career']),
          monthlyFinance: _strings(monthly['finance']),
          monthlyEnergy: _strings(monthly['energy']),
          monthlyOpportunity: _strings(monthly['opportunity']),
          monthlyWarning: _strings(monthly['warning']),
        ),
      );
    }
    _cache = List.unmodifiable(signs);
    return _cache!;
  }

  static List<String> _strings(Object? v) =>
      (v! as List<Object?>).whereType<String>().toList();

  static List<int> _ints(Object? v) =>
      (v! as List<Object?>).whereType<int>().toList();

  @override
  List<ZodiacSign> allSigns() => _parse();

  @override
  ZodiacSign? byId(String id) {
    for (final s in _parse()) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  ZodiacSign byIdOrFail(String id) =>
      byId(id) ??
      (throw ArgumentError('Unknown zodiac id: $id'));
}
