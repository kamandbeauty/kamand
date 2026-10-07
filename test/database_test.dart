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
    expect(metadata['schema_version'], '9');
    expect(metadata['content_version'], 'knowledge-4');
    expect(database.getSources().length, greaterThan(20));
    expect(database.searchNames('آ'), isNotEmpty);
    expect(database.getName('name-catalog-نیلوفر')?.meaning, contains('گل'));
    expect(database.getName('name-catalog-نیلوفر')?.status, 'unverified');
    expect(database.getSources().singleWhere((source) => source.id == 'source-wiktionary-persian-given-names').license, contains('CC BY-SA'));
    expect(database.getClaims('name', 'name-catalog-آرش'), isNotEmpty);
    expect(database.getClaims('name', 'name-داریوش'), isNotEmpty);
    expect(database.getName('name-کوروش')?.etymology, contains('Kuruš'));
    final importedNames = database.searchNames('');
    expect(importedNames.length, greaterThan(8500));
    expect(database.getName('name-nabidam-فاطمه')?.gender, 'مؤنث');
    expect(database.getName('name-nabidam-فاطمه')?.meaning, 'نامشخص');
    expect(database.getClaims('name', 'name-nabidam-فاطمه').single.sourceTitle, 'Persian Names dataset');
    expect(database.getSources().singleWhere((source) => source.id == 'source-nabidam-persian-names').license, contains('MIT'));
  });

  test('reports content integrity without treating unknown meaning as an orphan', () {
    final report = database.auditContent();
    expect(report.isHealthy, isTrue);
    expect(report.namesWithoutMeaning, greaterThan(0));
    expect(report.claimsWithoutSource, 0);
    expect(report.claimsWithoutSubject, 0);
    expect(report.orphanVariants, 0);
    expect(report.orphanMeanings, 0);
    expect(report.orphanEtymologies, 0);
    expect(report.orphanPronunciations, 0);
    expect(database.getPronunciations('name-catalog-نیلوفر'), isEmpty);
  });

  test('loads sourced calculation systems and refuses unsupported letter guesses', () {
    final system = database.getAbjadSystem('kabir');
    final mapping = database.getAbjadMapping('kabir');
    final systems = database.getAbjadSystems();
    final saghir = database.getAbjadMapping('saghir');
    final persianMapping = database.getAbjadMapping('kabir-persian');
    final rule = database.getNumerologyRule('abjad-digital-root');
    expect(system?.status, 'supported');
    expect(mapping['ا'], 1);
    expect(mapping.containsKey('پ'), isFalse);
    expect(systems.map((item) => item.key), containsAll(<String>['kabir', 'saghir', 'wasit', 'akbar']));
    expect(saghir['ی'], 1);
    expect(persianMapping['پ'], 2);
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
