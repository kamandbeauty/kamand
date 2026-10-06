import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../core/normalization/persian_normalizer.dart';
import '../../domain/models/archive_entry.dart';
import '../../domain/models/abjad_system.dart';
import '../../domain/models/compatibility_rule.dart';
import '../../domain/models/name.dart';
import '../../domain/models/numerology_rule.dart';
import '../../domain/models/profile.dart';
import '../../domain/models/source.dart';
import '../../domain/models/source_claim.dart';
import 'seed_data.dart';

class AppDatabase {
  AppDatabase._(this._db, this.filePath);

  final Database _db;
  final String filePath;

  static Future<AppDatabase> open() async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = path.join(directory.path, 'nameology.sqlite');
    return _open(sqlite3.open(filePath), filePath);
  }

  static AppDatabase openInMemory() {
    return _open(sqlite3.openInMemory(), ':memory:');
  }

  static AppDatabase _open(Database db, String filePath) {
    final database = AppDatabase._(db, filePath);
    try {
      database._migrate();
      database._seedIfEmpty();
      database._upgradeContentSeed();
      database._ensureCalculationSystems();
      return database;
    } catch (_) {
      db.dispose();
      rethrow;
    }
  }

  void _migrate() {
    _db.execute('PRAGMA foreign_keys = ON');
    var version = (_db.select('PRAGMA user_version').first['user_version'] as int?) ?? 0;

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
      _db.execute('PRAGMA user_version = 1');
      _setMetadata('schema_version', '1');
      _setMetadata('content_version', 'seed-1');
      version = 1;
    }

    if (version < 2) {
      _db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS names_fts USING fts5(
          name_id UNINDEXED,
          display_name,
          normalized_name,
          meaning,
          etymology,
          tokenize = 'unicode61 remove_diacritics 2'
        )
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS source_authors (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          affiliation TEXT NOT NULL DEFAULT '',
          notes TEXT NOT NULL DEFAULT ''
        )
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS source_categories (
          id TEXT PRIMARY KEY,
          category_key TEXT NOT NULL UNIQUE,
          title TEXT NOT NULL
        )
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS source_claims (
          id TEXT PRIMARY KEY,
          claim_group_id TEXT NOT NULL,
          source_id TEXT NOT NULL,
          subject_type TEXT NOT NULL,
          subject_id TEXT NOT NULL,
          claim_type TEXT NOT NULL,
          claim_text TEXT NOT NULL,
          normalized_value TEXT NOT NULL DEFAULT '',
          status TEXT NOT NULL,
          confidence TEXT NOT NULL,
          evidence_note TEXT NOT NULL DEFAULT '',
          review_status TEXT NOT NULL DEFAULT 'pending',
          created_at TEXT NOT NULL,
          FOREIGN KEY(source_id) REFERENCES sources(id) ON DELETE CASCADE
        )
      ''');
      _db.execute('CREATE INDEX IF NOT EXISTS idx_claim_subject ON source_claims(subject_type, subject_id)');
      _db.execute('CREATE INDEX IF NOT EXISTS idx_claim_group ON source_claims(claim_group_id)');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS name_meanings (
          id TEXT PRIMARY KEY,
          name_id TEXT NOT NULL,
          meaning_text TEXT NOT NULL,
          context TEXT NOT NULL DEFAULT '',
          status TEXT NOT NULL,
          confidence TEXT NOT NULL,
          claim_group_id TEXT,
          FOREIGN KEY(name_id) REFERENCES names(id) ON DELETE CASCADE
        )
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS name_etymologies (
          id TEXT PRIMARY KEY,
          name_id TEXT NOT NULL,
          etymology_text TEXT NOT NULL,
          root_form TEXT NOT NULL DEFAULT '',
          source_language TEXT NOT NULL DEFAULT '',
          status TEXT NOT NULL,
          confidence TEXT NOT NULL,
          claim_group_id TEXT,
          FOREIGN KEY(name_id) REFERENCES names(id) ON DELETE CASCADE
        )
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      _db.execute("INSERT OR IGNORE INTO app_settings (key, value) VALUES ('analytics_enabled', 'false')");
      _db.execute("INSERT OR IGNORE INTO app_settings (key, value) VALUES ('personalized_ads_enabled', 'false')");
      _db.execute("INSERT OR IGNORE INTO app_settings (key, value) VALUES ('content_updates_enabled', 'true')");
      _db.execute('PRAGMA user_version = 2');
      _setMetadata('schema_version', '2');
      _setMetadata('content_version', 'seed-2');
      version = 2;
    }

    if (version < 3) {
      _db.execute('''
        CREATE TABLE IF NOT EXISTS name_languages (
          id TEXT PRIMARY KEY,
          name_id TEXT NOT NULL,
          language_code TEXT NOT NULL,
          language_title TEXT NOT NULL,
          status TEXT NOT NULL,
          confidence TEXT NOT NULL,
          claim_group_id TEXT,
          FOREIGN KEY(name_id) REFERENCES names(id) ON DELETE CASCADE
        )
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS name_cultures (
          id TEXT PRIMARY KEY,
          name_id TEXT NOT NULL,
          culture_key TEXT NOT NULL,
          culture_title TEXT NOT NULL,
          status TEXT NOT NULL,
          confidence TEXT NOT NULL,
          claim_group_id TEXT,
          FOREIGN KEY(name_id) REFERENCES names(id) ON DELETE CASCADE
        )
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS name_pronunciations (
          id TEXT PRIMARY KEY,
          name_id TEXT NOT NULL,
          ipa TEXT NOT NULL DEFAULT '',
          local_phonetic TEXT NOT NULL DEFAULT '',
          dialect TEXT NOT NULL DEFAULT '',
          status TEXT NOT NULL,
          confidence TEXT NOT NULL,
          claim_group_id TEXT,
          FOREIGN KEY(name_id) REFERENCES names(id) ON DELETE CASCADE
        )
      ''');
      _db.execute('CREATE INDEX IF NOT EXISTS idx_name_languages_name ON name_languages(name_id)');
      _db.execute('CREATE INDEX IF NOT EXISTS idx_name_cultures_name ON name_cultures(name_id)');
      _db.execute('PRAGMA user_version = 3');
      _setMetadata('schema_version', '3');
      _setMetadata('content_version', 'seed-3');
      version = 3;
    }

    if (version < 4) {
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
      _db.execute('CREATE INDEX IF NOT EXISTS idx_abjad_letters_system ON abjad_letters(system_id)');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS numerology_systems (
          id TEXT PRIMARY KEY,
          system_key TEXT NOT NULL UNIQUE,
          title TEXT NOT NULL,
          description TEXT NOT NULL,
          source_id TEXT,
          version TEXT NOT NULL,
          status TEXT NOT NULL,
          disclaimer TEXT NOT NULL,
          FOREIGN KEY(source_id) REFERENCES sources(id) ON DELETE SET NULL
        )
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS numerology_rules (
          id TEXT PRIMARY KEY,
          system_id TEXT NOT NULL,
          rule_key TEXT NOT NULL,
          operation TEXT NOT NULL,
          configuration_json TEXT NOT NULL DEFAULT '{}',
          source_id TEXT,
          version TEXT NOT NULL,
          status TEXT NOT NULL,
          FOREIGN KEY(system_id) REFERENCES numerology_systems(id) ON DELETE CASCADE,
          FOREIGN KEY(source_id) REFERENCES sources(id) ON DELETE SET NULL
        )
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS numerology_interpretations (
          id TEXT PRIMARY KEY,
          system_id TEXT NOT NULL,
          number_value INTEGER NOT NULL,
          title TEXT NOT NULL,
          description TEXT NOT NULL,
          status TEXT NOT NULL,
          confidence TEXT NOT NULL,
          source_id TEXT,
          FOREIGN KEY(system_id) REFERENCES numerology_systems(id) ON DELETE CASCADE,
          FOREIGN KEY(source_id) REFERENCES sources(id) ON DELETE SET NULL
        )
      ''');
      _db.execute('CREATE INDEX IF NOT EXISTS idx_numerology_rules_system ON numerology_rules(system_id)');
      _db.execute('CREATE INDEX IF NOT EXISTS idx_numerology_interpretations_system ON numerology_interpretations(system_id, number_value)');
      _db.execute('PRAGMA user_version = 4');
      _setMetadata('schema_version', '4');
      _setMetadata('content_version', 'seed-4');
      version = 4;
    }

    if (version < 5) {
      _db.execute('''
        CREATE TABLE IF NOT EXISTS compatibility_systems (
          id TEXT PRIMARY KEY,
          system_key TEXT NOT NULL UNIQUE,
          title TEXT NOT NULL,
          description TEXT NOT NULL,
          source_id TEXT,
          version TEXT NOT NULL,
          status TEXT NOT NULL,
          disclaimer TEXT NOT NULL,
          FOREIGN KEY(source_id) REFERENCES sources(id) ON DELETE SET NULL
        )
      ''');
      _db.execute('''
        CREATE TABLE IF NOT EXISTS compatibility_rules (
          id TEXT PRIMARY KEY,
          system_id TEXT NOT NULL,
          rule_key TEXT NOT NULL,
          operation TEXT NOT NULL,
          configuration_json TEXT NOT NULL DEFAULT '{}',
          source_id TEXT,
          version TEXT NOT NULL,
          status TEXT NOT NULL,
          FOREIGN KEY(system_id) REFERENCES compatibility_systems(id) ON DELETE CASCADE,
          FOREIGN KEY(source_id) REFERENCES sources(id) ON DELETE SET NULL
        )
      ''');
      _db.execute('CREATE INDEX IF NOT EXISTS idx_compatibility_rules_system ON compatibility_rules(system_id)');
      _db.execute('PRAGMA user_version = 5');
      _setMetadata('schema_version', '5');
      _setMetadata('content_version', 'seed-5');
      version = 5;
    }

    if (version < 6) {
      _db.execute("ALTER TABLE profiles ADD COLUMN birth_calendar TEXT NOT NULL DEFAULT ''");
      _db.execute('PRAGMA user_version = 6');
      _setMetadata('schema_version', '6');
      _setMetadata('content_version', 'seed-6');
      version = 6;
    }
  }

  void _seedIfEmpty() {
    final count = (_db.select('SELECT COUNT(*) AS count FROM sources').first['count'] as int?) ?? 0;
    if (count > 0) {
      _refreshSearchIndex();
      return;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute('BEGIN');
    try {
      for (final source in seedSources) {
        _db.execute(
          '''INSERT INTO sources (id, title, author, publisher, publication_year, language, source_type, url, isbn, doi, reliability_level, notes)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            source['id'], source['title'], source['author'], source['publisher'], source['publication_year'],
            source['language'], source['source_type'], source['url'], source['isbn'], source['doi'],
            source['reliability_level'], source['notes'],
          ],
        );
      }
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
      for (final claim in seedClaims) {
        _db.execute(
          '''INSERT INTO source_claims (id, claim_group_id, source_id, subject_type, subject_id, claim_type, claim_text, normalized_value, status, confidence, evidence_note, review_status, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            claim['id'], claim['claim_group_id'], claim['source_id'], claim['subject_type'], claim['subject_id'],
            claim['claim_type'], claim['claim_text'], claim['normalized_value'], claim['status'], claim['confidence'],
            claim['evidence_note'], claim['review_status'], now,
          ],
        );
        if (claim['subject_type'] == 'name' && claim['claim_type'] == 'meaning') {
          _db.execute(
            '''INSERT INTO name_meanings (id, name_id, meaning_text, context, status, confidence, claim_group_id)
               VALUES (?, ?, ?, ?, ?, ?, ?)''',
            ["meaning-${claim['subject_id']}", claim['subject_id'], claim['claim_text'], 'ترجمه/شرح ثبت‌شده در Source Claim', claim['status'], claim['confidence'], claim['claim_group_id']],
          );
        }
        if (claim['subject_type'] == 'name' && claim['claim_type'] == 'etymology') {
          _db.execute(
            '''INSERT INTO name_etymologies (id, name_id, etymology_text, root_form, source_language, status, confidence, claim_group_id)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
            ["etymology-${claim['subject_id']}", claim['subject_id'], claim['claim_text'], '', 'Old Persian / Iranian', claim['status'], claim['confidence'], claim['claim_group_id']],
          );
        }
      }
      for (final entry in seedArchiveEntries) {
        _db.execute(
          '''INSERT INTO archive_entries (id, title, category, body, source_id, status, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?)''',
          [entry['id'], entry['title'], entry['category'], entry['body'], entry['source_id'], entry['status'], now],
        );
      }
      _db.execute('COMMIT');
      _refreshSearchIndex();
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _ensureCalculationSystems() {
    final hasIranica = _db.select("SELECT 1 FROM sources WHERE id = 'source-iranica-abjad' LIMIT 1").isNotEmpty;
    final abjadSource = hasIranica ? 'source-iranica-abjad' : internalSourceId;
    _db.execute('''
      INSERT OR IGNORE INTO abjad_systems (id, system_key, title, description, source_id, version, status)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', ['abjad-kabir-v1', 'kabir', 'ابجد کبیر', 'نگاشت حرف به عدد برای نمایش سنت تاریخی؛ این بخش ادعای علمی یا پیش‌بینی نیست.', abjadSource, '1', 'supported']);
    for (final entry in abjadKabirLetters.entries) {
      _db.execute('''
        INSERT OR IGNORE INTO abjad_letters (id, system_id, letter, normalized_letter, arabic_letter, persian_letter, numeric_value, mapping_status, source_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', ['kabir-${entry.key}', 'abjad-kabir-v1', entry.key, entry.key, entry.key, entry.key, entry.value, 'supported', abjadSource]);
    }
    _db.execute('''
      INSERT OR IGNORE INTO numerology_systems (id, system_key, title, description, source_id, version, status, disclaimer)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      'numerology-abjad-digital-root-v1',
      'abjad-digital-root',
      'کاهش رقمی بر پایه مجموع ابجد',
      'یک عملیات عددی قابل مشاهده برای نمایش مقدار کاهش‌یافته؛ تفسیر شخصیتی در این نسخه ثبت نشده است.',
      null,
      '1',
      'unverified',
      'این نتیجه سنتی و تفسیری است و پیش‌بینی علمی شخصیت یا آینده محسوب نمی‌شود.',
    ]);
    _db.execute('''
      INSERT OR IGNORE INTO numerology_rules (id, system_id, rule_key, operation, configuration_json, source_id, version, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', ['rule-digit-sum-reduce-v1', 'numerology-abjad-digital-root-v1', 'digit_sum_reduce', 'digit_sum_reduce', '{}', null, '1', 'unverified']);
    _db.execute("UPDATE abjad_systems SET source_id = 'source-iranica-abjad', status = 'supported' WHERE system_key = 'kabir' AND EXISTS (SELECT 1 FROM sources WHERE id = 'source-iranica-abjad')");
    _db.execute("UPDATE abjad_letters SET source_id = 'source-iranica-abjad', mapping_status = 'supported' WHERE system_id = (SELECT id FROM abjad_systems WHERE system_key = 'kabir') AND EXISTS (SELECT 1 FROM sources WHERE id = 'source-iranica-abjad')");
    _db.execute('''
      INSERT OR IGNORE INTO compatibility_systems (id, system_key, title, description, source_id, version, status, disclaimer)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      'compatibility-written-form-v1',
      'written-form-similarity',
      'شاخص شباهت نوشتاری',
      'مقایسه‌ای محدود بر اساس حروف یکتای دو ورودی؛ این سیستم ادعای سازگاری عاطفی یا پیش‌بینی رابطه ندارد.',
      null,
      '1',
      'unverified',
      'این شاخص فقط شباهت نوشتاری دو ورودی را نشان می‌دهد و سازگاری علمی، عاطفی یا پیش‌بینی رابطه نیست.',
    ]);
    _db.execute('''
      INSERT OR IGNORE INTO compatibility_rules (id, system_id, rule_key, operation, configuration_json, source_id, version, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', ['rule-written-form-jaccard-v1', 'compatibility-written-form-v1', 'unique_letter_jaccard', 'unique_letter_jaccard', '{}', null, '1', 'unverified']);
  }

  void _upgradeContentSeed() {
    final metadata = getMetadata();
    if (metadata['content_version'] == 'knowledge-1') return;
    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute('BEGIN');
    try {
      for (final source in seedSources) {
        _db.execute(
          '''INSERT OR IGNORE INTO sources (id, title, author, publisher, publication_year, language, source_type, url, isbn, doi, reliability_level, notes)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [source['id'], source['title'], source['author'], source['publisher'], source['publication_year'], source['language'], source['source_type'], source['url'], source['isbn'], source['doi'], source['reliability_level'], source['notes']],
        );
      }
      for (final item in seedNames) {
        _db.execute(
          '''INSERT OR IGNORE INTO names (id, display_name, normalized_name, transliteration, language, origin, gender, meaning, etymology, pronunciation, status, confidence, styles, source_id, source_note, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [item['id'], item['display_name'], item['normalized_name'], item['transliteration'], item['language'], item['origin'], item['gender'], item['meaning'], item['etymology'], item['pronunciation'], item['status'], item['confidence'], item['styles'], item['source_id'], item['source_note'], now, now],
        );
      }
      for (final claim in seedClaims) {
        _db.execute(
          '''INSERT OR IGNORE INTO source_claims (id, claim_group_id, source_id, subject_type, subject_id, claim_type, claim_text, normalized_value, status, confidence, evidence_note, review_status, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [claim['id'], claim['claim_group_id'], claim['source_id'], claim['subject_type'], claim['subject_id'], claim['claim_type'], claim['claim_text'], claim['normalized_value'], claim['status'], claim['confidence'], claim['evidence_note'], claim['review_status'], now],
        );
        if (claim['subject_type'] == 'name' && claim['claim_type'] == 'meaning') {
          _db.execute(
            '''INSERT OR IGNORE INTO name_meanings (id, name_id, meaning_text, context, status, confidence, claim_group_id)
               VALUES (?, ?, ?, ?, ?, ?, ?)''',
            ["meaning-${claim['subject_id']}", claim['subject_id'], claim['claim_text'], 'ترجمه/شرح ثبت‌شده در Source Claim', claim['status'], claim['confidence'], claim['claim_group_id']],
          );
        }
        if (claim['subject_type'] == 'name' && claim['claim_type'] == 'etymology') {
          _db.execute(
            '''INSERT OR IGNORE INTO name_etymologies (id, name_id, etymology_text, root_form, source_language, status, confidence, claim_group_id)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
            ["etymology-${claim['subject_id']}", claim['subject_id'], claim['claim_text'], '', 'Old Persian / Iranian', claim['status'], claim['confidence'], claim['claim_group_id']],
          );
        }
      }
      for (final entry in seedArchiveEntries) {
        _db.execute(
          '''INSERT OR IGNORE INTO archive_entries (id, title, category, body, source_id, status, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?)''',
          [entry['id'], entry['title'], entry['category'], entry['body'], entry['source_id'], entry['status'], now],
        );
      }
      _setMetadata('content_version', 'knowledge-1');
      _db.execute('COMMIT');
      _refreshSearchIndex();
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  void _refreshSearchIndex() {
    _db.execute('DELETE FROM names_fts');
    _db.execute('''
      INSERT INTO names_fts (name_id, display_name, normalized_name, meaning, etymology)
      SELECT id, display_name, normalized_name, meaning, etymology FROM names
    ''');
  }

  void _setMetadata(String key, String value) {
    _db.execute('INSERT OR REPLACE INTO database_metadata (key, value) VALUES (?, ?)', [key, value]);
  }

  List<Name> searchNames(String query) {
    final normalized = PersianNormalizer.normalizeForSearch(query);
    final rows = normalized.isEmpty ? _allNameRows() : _searchRows(normalized);
    return rows.map((row) => Name.fromMap(Map<String, Object?>.from(row))).toList(growable: false);
  }

  List<Map<String, Object?>> _allNameRows() {
    final rows = _db.select('SELECT n.*, s.title AS source_title FROM names n LEFT JOIN sources s ON s.id = n.source_id ORDER BY n.display_name');
    return rows.map((row) => Map<String, Object?>.from(row)).toList(growable: false);
  }

  List<Map<String, Object?>> _searchRows(String normalized) {
    try {
      final match = normalized
          .split(' ')
          .where((token) => token.isNotEmpty)
          .map((token) => '"${token.replaceAll('"', '""')}"*')
          .join(' AND ');
      final rows = _db.select(
        '''SELECT n.*, s.title AS source_title FROM names n
           LEFT JOIN sources s ON s.id = n.source_id
           WHERE n.id IN (SELECT name_id FROM names_fts WHERE names_fts MATCH ?)
           ORDER BY n.display_name''',
        [match],
      );
      if (rows.isNotEmpty) return rows.map((row) => Map<String, Object?>.from(row)).toList(growable: false);
    } catch (_) {
      // User input can contain FTS operators; the LIKE fallback below is intentional.
    }
    final like = '%$normalized%';
    final rows = _db.select(
      '''SELECT n.*, s.title AS source_title FROM names n
         LEFT JOIN sources s ON s.id = n.source_id
         WHERE n.normalized_name LIKE ?
            OR n.meaning LIKE ?
            OR n.origin LIKE ?
            OR n.language LIKE ?
            OR n.styles LIKE ?
         ORDER BY n.display_name''',
      [like, like, like, like, like],
    );
    return rows.map((row) => Map<String, Object?>.from(row)).toList(growable: false);
  }

  Name? getName(String id) {
    final rows = _db.select(
      'SELECT n.*, s.title AS source_title FROM names n LEFT JOIN sources s ON s.id = n.source_id WHERE n.id = ?',
      [id],
    );
    return rows.isEmpty ? null : Name.fromMap(Map<String, Object?>.from(rows.first));
  }

  AbjadSystem? getAbjadSystem(String systemKey) {
    final rows = _db.select(
      '''SELECT a.*, s.title AS source_title
         FROM abjad_systems a LEFT JOIN sources s ON s.id = a.source_id
         WHERE a.system_key = ?''',
      [systemKey],
    );
    return rows.isEmpty ? null : AbjadSystem.fromMap(Map<String, Object?>.from(rows.first));
  }

  Map<String, int> getAbjadMapping(String systemKey) {
    final rows = _db.select(
      '''SELECT l.normalized_letter, l.numeric_value
         FROM abjad_letters l JOIN abjad_systems a ON a.id = l.system_id
         WHERE a.system_key = ? AND l.numeric_value IS NOT NULL
           AND EXISTS (SELECT 1 FROM source_claims c WHERE c.subject_type = 'abjad_system' AND c.subject_id = a.id AND c.status IN ('supported', 'verified'))''',
      [systemKey],
    );
    return {
      for (final row in rows) row['normalized_letter'] as String: row['numeric_value'] as int,
    };
  }

  NumerologyRule? getNumerologyRule(String systemKey) {
    final rows = _db.select(
      '''SELECT r.*, n.system_key, n.title AS system_title, n.disclaimer, s.title AS source_title
         FROM numerology_rules r
         JOIN numerology_systems n ON n.id = r.system_id
         LEFT JOIN sources s ON s.id = r.source_id
         WHERE n.system_key = ?
         ORDER BY r.version DESC LIMIT 1''',
      [systemKey],
    );
    return rows.isEmpty ? null : NumerologyRule.fromMap(Map<String, Object?>.from(rows.first));
  }

  CompatibilityRule? getCompatibilityRule(String systemKey) {
    final rows = _db.select(
      '''SELECT r.*, c.system_key, c.title AS system_title, c.disclaimer, s.title AS source_title
         FROM compatibility_rules r
         JOIN compatibility_systems c ON c.id = r.system_id
         LEFT JOIN sources s ON s.id = r.source_id
         WHERE c.system_key = ?
         ORDER BY r.version DESC LIMIT 1''',
      [systemKey],
    );
    return rows.isEmpty ? null : CompatibilityRule.fromMap(Map<String, Object?>.from(rows.first));
  }

  List<Source> getSources() {
    final rows = _db.select('SELECT * FROM sources ORDER BY title');
    return rows.map((row) => Source.fromMap(Map<String, Object?>.from(row))).toList(growable: false);
  }

  List<SourceClaim> getClaims(String subjectType, String subjectId) {
    final rows = _db.select(
      '''SELECT c.*, s.title AS source_title, s.url AS source_url
         FROM source_claims c LEFT JOIN sources s ON s.id = c.source_id
         WHERE c.subject_type = ? AND c.subject_id = ?
         ORDER BY c.confidence DESC, c.created_at''',
      [subjectType, subjectId],
    );
    return rows.map((row) => SourceClaim.fromMap(Map<String, Object?>.from(row))).toList(growable: false);
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
      '''INSERT OR REPLACE INTO profiles (id, title, name, mother_name, gender, birth_date, birth_calendar, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
      [profile.id, profile.title, profile.name, profile.motherName, profile.gender, profile.birthDate, profile.birthCalendar, profile.createdAt],
    );
  }

  void deleteProfile(String id) {
    _db.execute('DELETE FROM profiles WHERE id = ?', [id]);
  }

  Map<String, String> getMetadata() {
    final rows = _db.select('SELECT key, value FROM database_metadata');
    return {for (final row in rows) row['key'] as String: row['value'] as String};
  }

  Map<String, bool> getPrivacySettings() {
    final rows = _db.select('SELECT key, value FROM app_settings WHERE key IN (?, ?, ?)', ['analytics_enabled', 'personalized_ads_enabled', 'content_updates_enabled']);
    return {
      for (final row in rows) row['key'] as String: (row['value'] as String).toLowerCase() == 'true',
    };
  }

  void setPrivacySetting(String key, bool value) {
    const allowed = {'analytics_enabled', 'personalized_ads_enabled', 'content_updates_enabled'};
    if (!allowed.contains(key)) throw ArgumentError('Unsupported privacy setting: $key');
    _db.execute('INSERT OR REPLACE INTO app_settings (key, value) VALUES (?, ?)', [key, value.toString()]);
  }

  void close() => _db.dispose();
}
