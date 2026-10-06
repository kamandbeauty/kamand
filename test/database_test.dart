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
    expect(metadata['schema_version'], '3');
    expect(metadata['content_version'], 'knowledge-1');
    expect(database.getSources().length, greaterThan(3));
    expect(database.searchNames('آ'), isNotEmpty);
    expect(database.getClaims('name', 'name-داریوش'), isNotEmpty);
  });

  test('persists and deletes local profiles', () {
    final now = DateTime.now().toUtc().toIso8601String();
    database.saveProfile(Profile(id: 'profile-test', title: 'من', name: 'آوا', motherName: '', gender: 'نامشخص', birthDate: '', createdAt: now));
    expect(database.getProfiles().single.name, 'آوا');
    database.deleteProfile('profile-test');
    expect(database.getProfiles(), isEmpty);
  });
}
