import '../../data/content/app_content.dart';
import '../zodiac/zodiac_repository.dart';
import '../zodiac/zodiac_sign.dart';
import '../horoscope/deterministic_random.dart';

/// The six compatibility dimensions (all 0..100, deterministic per pair).
class CompatibilityScores {
  const CompatibilityScores({
    required this.love,
    required this.communication,
    required this.attraction,
    required this.trust,
    required this.longTerm,
  });

  final int love;
  final int communication;
  final int attraction;
  final int trust;
  final int longTerm;

  int get overall {
    final v = (love * 0.28 +
            attraction * 0.20 +
            communication * 0.20 +
            trust * 0.16 +
            longTerm * 0.16)
        .round();
    return v < 0 ? 0 : (v > 100 ? 100 : v);
  }
}

enum CompatibilityLevel {
  excellent, // ≥ 85
  good, // ≥ 72
  fair, // ≥ 60
  challenging, // ≥ 48
  hard, // < 48
}

class CompatibilityResult {
  const CompatibilityResult({
    required this.signA,
    required this.signB,
    required this.scores,
    required this.aspectId,
    required this.aspectTitle,
    required this.whyText,
    required this.elementChemistryText,
  });

  final ZodiacSign signA;
  final ZodiacSign signB;
  final CompatibilityScores scores;
  final String aspectId;
  final String aspectTitle;
  final String whyText;
  final String elementChemistryText;

  CompatibilityLevel get level {
    final o = scores.overall;
    if (o >= 85) return CompatibilityLevel.excellent;
    if (o >= 72) return CompatibilityLevel.good;
    if (o >= 60) return CompatibilityLevel.fair;
    if (o >= 48) return CompatibilityLevel.challenging;
    return CompatibilityLevel.hard;
  }
}

/// Deterministic 12×12 compatibility matrix, computed from zodiac geometry
/// (aspect) + element chemistry + a symmetric per-pair seed.
///
/// Stored in the domain layer as an algorithm rather than 144 hand-written
/// rows — see product spec §53.
class CompatibilityEngine {
  const CompatibilityEngine(this._repository);

  final ZodiacRepository _repository;

  static const Map<String, int> _aspectBase = {
    'conjunction': 79,
    'semisextile': 69,
    'sextile': 84,
    'square': 58,
    'trine': 90,
    'quincunx': 60,
    'opposition': 71,
  };

  /// Element chemistry factor 0..1 (higher = more natural harmony).
  static const Map<String, double> _elementFactor = {
    'fire-fire': 1.00,
    'earth-earth': 1.00,
    'air-air': 1.00,
    'water-water': 1.00,
    'fire-air': 0.95,
    'earth-water': 0.95,
    'fire-earth': 0.60,
    'air-water': 0.65,
    'fire-water': 0.55,
    'air-earth': 0.55,
  };

  CompatibilityResult compute(String idA, String idB) {
    final a = _repository.byIdOrFail(idA);
    final b = _repository.byIdOrFail(idB);
    final ia = _index(a);
    final ib = _index(b);
    final distance = (ib - ia + 12) % 12;
    final aspectId = aspectForDistance(distance);

    // Symmetric pair seed (order-independent → matrix is symmetric).
    final first = idA.compareTo(idB) < 0 ? idA : idB;
    final second = idA.compareTo(idB) < 0 ? idB : idA;
    final pairSeed = fnv1a32('compat|$first|$second');
    final rng = DetRandom(pairSeed);

    final base = _aspectBase[aspectId]!;
    final pair = _elementKey(a.elementId, b.elementId);
    final factor = _elementFactor[pair] ?? 0.6;
    final elementAdj = (factor * 16 - 8).round(); // −8..+8

    int dim(int spread) =>
        clampInt(base + elementAdj + rng.nextInt(spread) - spread ~/ 2, 12, 99);

    final scores = CompatibilityScores(
      love: dim(15),
      attraction: dim(21),
      communication: dim(13),
      trust: dim(11),
      longTerm: dim(13),
    );

    // Why-text: deterministic pick from authored aspect texts.
    final aspectData = _repositoryAspect(aspectId);
    final why = DetRandom(pairSeed ^ 0x9E3779B9)
        .pick((aspectData['why']! as List<Object?>).whereType<String>().toList())
        .replaceAll('{a}', a.nameFa)
        .replaceAll('{b}', b.nameFa);
    final chemistry = _chemistry(pair);

    return CompatibilityResult(
      signA: a,
      signB: b,
      scores: scores,
      aspectId: aspectId,
      aspectTitle: aspectData['title']! as String,
      whyText: why,
      elementChemistryText: chemistry,
    );
  }

  /// All 12 signs ranked against [idA] by overall score (desc).
  List<CompatibilityResult> rankedFor(String idA) {
    final results = <CompatibilityResult>[];
    for (final sign in _repository.allSigns()) {
      if (sign.id == idA) continue;
      results.add(compute(idA, sign.id));
    }
    results.sort((x, y) => y.scores.overall.compareTo(x.scores.overall));
    return results;
  }

  static String aspectForDistance(int distance) {
    switch (distance) {
      case 0:
        return 'conjunction';
      case 1:
      case 11:
        return 'semisextile';
      case 2:
      case 10:
        return 'sextile';
      case 3:
      case 9:
        return 'square';
      case 4:
      case 8:
        return 'trine';
      case 6:
        return 'opposition';
      default: // 5, 7
        return 'quincunx';
    }
  }

  static String levelLabelFa(CompatibilityLevel level) {
    switch (level) {
      case CompatibilityLevel.excellent:
        return 'بسیار هماهنگ';
      case CompatibilityLevel.good:
        return 'هماهنگ';
      case CompatibilityLevel.fair:
        return 'متوسط';
      case CompatibilityLevel.challenging:
        return 'نیازمند تلاش';
      case CompatibilityLevel.hard:
        return 'چالش‌برانگیز';
    }
  }

  int _index(ZodiacSign sign) {
    final all = _repository.allSigns();
    for (var i = 0; i < all.length; i++) {
      if (all[i].id == sign.id) return i;
    }
    return 0;
  }

  static String _elementKey(String e1, String e2) {
    final keys = [e1, e2]..sort();
    return '${keys[0]}-${keys[1]}';
  }

  Map<String, Object?> _repositoryAspect(String aspectId) {
    final compat =
        _compatibilityData()['aspectTexts']! as Map<String, Object?>;
    return compat[aspectId]! as Map<String, Object?>;
  }

  String _chemistry(String pairKey) {
    final chemistry =
        _compatibilityData()['elementChemistry']! as Map<String, Object?>;
    return (chemistry[pairKey] ?? chemistry['fire-fire'])! as String;
  }

  static Map<String, Object?>? _cached;
  static Map<String, Object?> _compatibilityData() {
    return _cached ??= (AppContent.compatibility as Map<String, Object?>)
        .cast<String, Object?>();
  }
}

// Imported lazily to keep engine free of Flutter deps.
// ignore: always_use_package_imports
import '../../data/content/app_content.dart';
