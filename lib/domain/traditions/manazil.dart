import '../../data/content/traditions_content.dart';
import 'sky_math.dart';

/// The 28 lunar mansions (manazil al-qamar) of the Iranian-Islamic
/// tradition: stations of the Moon against the fixed stars, inherited from
/// Sasanian astronomy and standard in classical Persian texts on
/// ahkam al-nujum.
class ManazilCalculator {
  ManazilCalculator._();

  static const double _span = 360 / 28;

  /// Index (0–27) of the mansion the sidereal Moon occupies at [utc].
  static int indexFor(DateTime utc) {
    final sid = SkyMath.siderealMoon(SkyMath.julianDay(utc));
    return (sid / _span).floor().clamp(0, 27);
  }

  /// Mansion metadata by index.
  static Map<String, Object?> at(int index) =>
      TraditionsContent.iranianManazil[index.clamp(0, 27)];
}
