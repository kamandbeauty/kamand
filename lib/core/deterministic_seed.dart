import 'normalization/persian_normalizer.dart';

class DeterministicSeed {
  const DeterministicSeed._();

  static int forDay({required String name, required DateTime localDate, required String systemKey}) {
    final value = '${PersianNormalizer.normalizeForSearch(name)}|${localDate.year.toString().padLeft(4, '0')}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}|$systemKey';
    var hash = 17;
    for (final codeUnit in value.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash;
  }
}
