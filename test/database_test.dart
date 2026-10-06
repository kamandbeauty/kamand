import 'package:flutter_test/flutter_test.dart';
import 'package:nameology_app/data/database/app_database.dart';
import 'package:nameology_app/domain/models/profile.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.openInMemory();
  });

  tearDown(() {
    database.close();
  });

  test('creates the current schema and seed metadata', () {
    final metadata = database.getMetadata();
    expect(metadata['schema_version'], '6');
    expect(metadata['content_version'], 'knowledge-1');
    expect(database.getSources().length, greaterThan(3));
    expect(database.searchNames('آ'), isNotEmpty);
    expect(database.getClaims('name', 'name-داریوش'), isNotEmpty);
  });

  test('loads sourced calculation systems and refuses unsupported letter guesses', () {
    final system = database.getAbjadSystem('kabir');
    final mapping = database.getAbjadMapping('kabir');
    final rule = database.getNumerologyRule('abjad-digital-root');
    expect(system?.status, 'supported');
    expect(mapping['ا'], 1);
    expect(mapping.containsKey('پ'), isFalse);
    expect(rule?.operation, 'digit_sum_reduce');
    expect(rule?.status, 'unverified');
    final compatibilityRule = database.getCompatibilityRule('written-form-similarity');
    expect(compatibilityRule?.operation, 'unique_letter_jaccard');
    expect(compatibilityRule?.status, 'unverified');
  });

  test('persists and deletes local profiles', () {
    final now = DateTime.now().toUtc().toIso8601String();
    database.saveProfile(Profile(id: 'profile-test', title: 'من', name: 'آوا', motherName: '', gender: 'نامشخص', birthDate: '1403-01-01', birthCalendar: 'jalali', createdAt: now));
    expect(database.getProfiles().single.name, 'آوا');
    expect(database.getProfiles().single.birthCalendar, 'jalali');
    database.deleteProfile('profile-test');
    expect(database.getProfiles(), isEmpty);
  });
}
