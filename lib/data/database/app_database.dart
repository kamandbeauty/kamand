import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../domain/models/archive_entry.dart';
import '../../domain/models/name.dart';
import '../../domain/models/profile.dart';
import '../../domain/models/source.dart';
import '../../core/normalization/persian_normalizer.dart';
import 'seed_data.dart';

class AppDatabase {
  AppDatabase._(this._db, this.filePath);

  final Database _db;
  final String filePath;

  static Future<AppDatabase> open() async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = path.join(directory.path, 'nameology.sqlite');
    final db = sqlite3.open(filePath);
    final database = AppDatabase._(db, filePath);
    database._migrate();
    database._seedIfEmpty();
    return database;
  }

  void _migrate() {
    _db.execute('PRAGMA foreign_keys = ON');
    final version = _db.select('PRAGMA user_version').first['user_version'] as int;
    if (version < 1) {
      _db.execute('''
        CREATE TABLE IF NOT EXISTS database_metadata (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS sources (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          author TEXT NOT NULL,
          publisher TEXT NOT NULL,
          publication_year INTEGER,
          language TEXT NOT NULL,
          source_type TEXT NOT NULL,
          url TEXT NOT NULL DEFAULT '',
          isbn TEXT,
          doi TEXT,
          reliability_level TEXT NOT NULL,
          notes TEXT NOT NULL DEFAULT ''
        )
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS names (
          id TEXT PRIMARY KEY,
          display_name TEXT NOT NULL,
          normalized_name TEXT NOT NULL,
          transliteration TEXT NOT NULL DEFAULT '',
          language TEXT NOT NULL DEFAULT 'نامشخص',
          origin TEXT NOT NULL DEFAULT 'نامشخص',
          gender TEXT NOT NULL DEFAULT 'نامشخص',
          meaning TEXT NOT NULL DEFAULT 'نامشخص',
          etymology TEXT NOT NULL DEFAULT 'نامشخص',
          pronunciation TEXT NOT NULL DEFAULT 'نامشخص',
          status TEXT NOT NULL,
          confidence TEXT NOT NULL,
          styles TEXT NOT NULL DEFAULT '',
          source_id TEXT,
          source_note TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY(source_id) REFERENCES sources(id) ON DELETE SET NULL
        )
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS name_variants (
          id TEXT PRIMARY KEY,
          name_id TEXT NOT NULL,
          variant_text TEXT NOT NULL,
          normalized_text TEXT NOT NULL,
          script TEXT NOT NULL DEFAULT 'fa',
          variant_type TEXT NOT NULL DEFAULT 'spelling',
          FOREIGN KEY(name_id) REFERENCES names(id) ON DELETE CASCADE
        )
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS abjad_systems (
          id TEXT PRIMARY KEY,
          system_key TEXT NOT NULL UNIQUE,
          title TEXT NOT NULL,
          description TEXT NOT NULL,
          source_id TEXT,
          version TEXT NOT NULL,
          status TEXT NOT NULL,
          FOREIGN KEY(source_id) REFERENCES sources(id) ON DELETE SET NULL
        )
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS abjad_letters (
          id TEXT PRIMARY KEY,
          system_id TEXT NOT NULL,
          letter TEXT NOT NULL,
          normalized_letter TEXT NOT NULL,
          arabic_letter TEXT NOT NULL DEFAULT '',
          persian_letter TEXT NOT NULL DEFAULT '',
          numeric_value INTEGER,
          mapping_status TEXT NOT NULL,
          source_id TEXT,
          FOREIGN KEY(system_id) REFERENCES abjad_systems(id) ON DELETE CASCADE,
          FOREIGN KEY(source_id) REFERENCES sources(id) ON DELETE SET NULL
        )
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS profiles (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          name TEXT NOT NULL,
          mother_name TEXT NOT NULL DEFAULT '',
          gender TEXT NOT NULL DEFAULT 'نامشخص',
          birth_date TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL
        )
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS archive_entries (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          category TEXT NOT NULL,
          body TEXT NOT NULL,
          source_id TEXT,
          status TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY(source_id) REFERENCES sources(id) ON DELETE SET NULL
        )
      ''');
      _db.execute('CREATE INDEX IF NOT EXISTS idx_names_normalized ON names(normalized_name)');
      _db.execute('CREATE INDEX IF NOT EXISTS idx_names_status ON names(status)');
      _db.execute('CREATE INDEX IF NOT EXISTS idx_archive_category ON archive_entries(category)');
      _db.execute("PRAGMA user_version = 1");
      _setMetadata('schema_version', '1');
      _setMetadata('content_version', 'seed-1');
    }
  }

  void _seedIfEmpty() {
    final count = (_db.select('SELECT COUNT(*) AS count FROM sources').first['count'] as int?) ?? 0;
    if (count > 0) return;
    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute('BEGIN');
    try {
      _db.execute(
        '''INSERT INTO sources (id, title, author, publisher, publication_year, language, source_type, url, reliability_level, notes)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          seedSource['id'], seedSource['title'], seedSource['author'], seedSource['publisher'],
          seedSource['publication_year'], seedSource['language'], seedSource['source_type'],
          seedSource['url'], seedSource['reliability_level'], seedSource['notes'],
        ],
      );
      _db.execute(
        '''INSERT INTO abjad_systems (id, system_key, title, description, source_id, version, status)
           VALUES (?, ?, ?, ?, ?, ?, ?)''',
        ['abjad-kabir-v1', 'kabir', 'ابجد کبیر', 'نگاشت اولیه و وضعیت‌دار برای نمایش آموزشی؛ بررسی منبع پیش از انتشار الزامی است.', internalSourceId, '1', 'unverified'],
      );
      for (final entry in abjadKabirLetters.entries) {
        _db.execute(
          '''INSERT INTO abjad_letters (id, system_id, letter, normalized_letter, arabic_letter, persian_letter, numeric_value, mapping_status, source_id)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          ['kabir-${entry.key}', 'abjad-kabir-v1', entry.key, entry.key, entry.key, entry.key, entry.value, 'unverified', internalSourceId],
        );
      }
      for (final item in seedNames) {
        _db.execute(
          '''INSERT INTO names (id, display_name, normalized_name, transliteration, language, origin, gender, meaning, etymology, pronunciation, status, confidence, styles, source_id, source_note, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            item['id'], item['display_name'], item['normalized_name'], item['transliteration'], item['language'],
            item['origin'], item['gender'], item['meaning'], item['etymology'], item['pronunciation'],
            item['status'], item['confidence'], item['styles'], item['source_id'], item['source_note'], now, now,
          ],
        );
      }
      for (final entry in seedArchiveEntries) {
        _db.execute(
          '''INSERT INTO archive_entries (id, title, category, body, source_id, status, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?)''',
          [entry['id'], entry['title'], entry['category'], entry['body'], entry['source_id'], entry['status'], now],
        );
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _setMetadata(String key, String value) {
    _db.execute(
      'INSERT OR REPLACE INTO database_metadata (key, value) VALUES (?, ?)',
      [key, value],
    );
  }

  List<Name> searchNames(String query) {
    final normalized = PersianNormalizer.normalizeForSearch(query);
    final rows = normalized.isEmpty
        ? _db.select('SELECT n.*, s.title AS source_title FROM names n LEFT JOIN sources s ON s.id = n.source_id ORDER BY n.display_name')
        : _db.select(
            '''SELECT n.*, s.title AS source_title FROM names n
               LEFT JOIN sources s ON s.id = n.source_id
               WHERE n.normalized_name LIKE ?
                  OR n.meaning LIKE ?
                  OR n.origin LIKE ?
                  OR n.language LIKE ?
                  OR n.styles LIKE ?
               ORDER BY n.display_name''',
            ['%$normalized%', '%$normalized%', '%$normalized%', '%$normalized%', '%$normalized%'],
          );
    return rows.map((row) => Name.fromMap(Map<String, Object?>.from(row))).toList(growable: false);
  }

  Name? getName(String id) {
    final rows = _db.select(
      'SELECT n.*, s.title AS source_title FROM names n LEFT JOIN sources s ON s.id = n.source_id WHERE n.id = ?',
      [id],
    );
    return rows.isEmpty ? null : Name.fromMap(Map<String, Object?>.from(rows.first));
  }

  List<Source> getSources() {
    final rows = _db.select('SELECT * FROM sources ORDER BY title');
    return rows.map((row) => Source.fromMap(Map<String, Object?>.from(row))).toList(growable: false);
  }

  List<ArchiveEntry> getArchiveEntries([String? category]) {
    final rows = category == null
        ? _db.select('SELECT a.*, s.title AS source_title FROM archive_entries a LEFT JOIN sources s ON s.id = a.source_id ORDER BY a.created_at DESC')
        : _db.select('SELECT a.*, s.title AS source_title FROM archive_entries a LEFT JOIN sources s ON s.id = a.source_id WHERE a.category = ? ORDER BY a.created_at DESC', [category]);
    return rows.map((row) => ArchiveEntry.fromMap(Map<String, Object?>.from(row))).toList(growable: false);
  }

  List<Profile> getProfiles() {
    final rows = _db.select('SELECT * FROM profiles ORDER BY created_at');
    return rows.map((row) => Profile.fromMap(Map<String, Object?>.from(row))).toList(growable: false);
  }

  void saveProfile(Profile profile) {
    _db.execute(
      '''INSERT OR REPLACE INTO profiles (id, title, name, mother_name, gender, birth_date, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?)''',
      [profile.id, profile.title, profile.name, profile.motherName, profile.gender, profile.birthDate, profile.createdAt],
    );
  }

  void deleteProfile(String id) {
    _db.execute('DELETE FROM profiles WHERE id = ?', [id]);
  }

  Map<String, String> getMetadata() {
    final rows = _db.select('SELECT key, value FROM database_metadata');
    return {for (final row in rows) row['key'] as String: row['value'] as String};
  }

  void close() => _db.dispose();
}
