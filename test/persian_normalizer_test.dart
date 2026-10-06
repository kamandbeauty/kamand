import 'package:flutter_test/flutter_test.dart';
import 'package:nameology_app/core/normalization/persian_normalizer.dart';

void main() {
  test('normalizes Arabic/Persian letter variants', () {
    expect(PersianNormalizer.normalize('ي ك ة ۀ أ إ'), 'ی ک ه ه ا ا');
  });

  test('removes diacritics and normalizes spacing', () {
    expect(PersianNormalizer.normalize('  آریا\u064E  '), 'آریا');
  });

  test('converts Persian digits to Latin digits', () {
    expect(PersianNormalizer.toLatinDigits('۱۴۰۵/۰۱/۰۲'), '1405/01/02');
  });
}
