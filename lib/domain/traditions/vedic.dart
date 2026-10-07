import '../../data/content/traditions_content.dart';
import 'sky_math.dart';

/// Vedic (Jyotisha) chart essentials derived from the Moon's sidereal
/// position at birth: Chandra rashi (Moon sign) and janma nakshatra
/// (birth star) with its pada (quarter).
class VedicChart {
  const VedicChart({
    required this.siderealMoon,
    required this.rashiIndex,
    required this.nakshatraIndex,
    required this.pada,
  });

  /// Sidereal Moon longitude in degrees [0, 360).
  final double siderealMoon;

  /// 0 = Mesha … 11 = Meena.
  final int rashiIndex;

  /// 0 = Ashwini … 26 = Revati.
  final int nakshatraIndex;

  /// Quarter within the nakshatra, 1–4.
  final int pada;

  Map<String, Object?> get rashi => TraditionsContent.vedicRashis[rashiIndex];
  Map<String, Object?> get nakshatra =>
      TraditionsContent.vedicNakshatras[nakshatraIndex];
}

/// Sidereal (Lahiri ayanamsa) Moon-position calculator.
class VedicCalculator {
  VedicCalculator._();

  static const double _nakshatraSpan = 360 / 27;
  static const double _padaSpan = 360 / 108;

  static VedicChart forDateTime(DateTime utc) {
    final sid = SkyMath.siderealMoon(SkyMath.julianDay(utc));
    return VedicChart(
      siderealMoon: sid,
      rashiIndex: (sid ~/ 30) % 12,
      nakshatraIndex: (sid / _nakshatraSpan).floor(),
      pada: ((sid % _nakshatraSpan) / _padaSpan).floor() + 1,
    );
  }
}
