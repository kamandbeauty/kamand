import 'package:flutter_test/flutter_test.dart';
import 'package:nameology_app/domain/engines/smart_search_engine.dart';
import 'package:nameology_app/domain/models/name.dart';

void main() {
  const engine = SmartSearchEngine();
  const names = [
    Name(id: '1', displayName: 'آوا', normalizedName: 'آوا', transliteration: '', language: 'نامشخص', origin: 'نامشخص', gender: 'دختر', meaning: 'نور و صدا', etymology: '', pronunciation: '', status: 'unverified', confidence: 'low', styles: ['فارسی', 'کوتاه'], sourceTitle: 'test', sourceNote: ''),
    Name(id: '2', displayName: 'ویشتاسپ', normalizedName: 'ویشتاسپ', transliteration: '', language: 'فارسی باستان', origin: 'ایرانی', gender: 'پسر', meaning: 'اسب', etymology: '', pronunciation: '', status: 'verified', confidence: 'high', styles: ['باستانی'], sourceTitle: 'test', sourceNote: ''),
  ];

  test('parses natural language gender and length filters', () {
    final query = engine.parse('اسم دختر کوتاه');
    expect(query.gender, 'دختر');
    expect(query.maxLetters, 5);
  });

  test('filters an example natural language query', () {
    final result = engine.search(names: names, input: 'اسم دختر به معنی نور');
    expect(result.map((name) => name.displayName), ['آوا']);
  });
}
