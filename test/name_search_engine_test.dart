import 'package:flutter_test/flutter_test.dart';
import 'package:nameology_app/domain/engines/name_search_engine.dart';
import 'package:nameology_app/domain/models/name.dart';

void main() {
  const engine = NameSearchEngine();
  const names = [
    Name(id: '1', displayName: 'آوا', normalizedName: 'آوا', transliteration: '', language: 'نامشخص', origin: 'نامشخص', gender: 'نامشخص', meaning: 'نامشخص', etymology: 'نامشخص', pronunciation: 'نامشخص', status: 'unverified', confidence: 'low', styles: ['فارسی', 'کوتاه'], sourceTitle: 'test', sourceNote: ''),
    Name(id: '2', displayName: 'سام', normalizedName: 'سام', transliteration: '', language: 'نامشخص', origin: 'نامشخص', gender: 'نامشخص', meaning: 'نامشخص', etymology: 'نامشخص', pronunciation: 'نامشخص', status: 'unverified', confidence: 'low', styles: ['باستانی'], sourceTitle: 'test', sourceNote: ''),
  ];

  test('filters by style', () {
    final result = engine.filter(names: names, style: 'کوتاه');
    expect(result.map((name) => name.displayName), ['آوا']);
  });
}
