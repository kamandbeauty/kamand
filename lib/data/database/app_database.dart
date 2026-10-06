import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// SQLite database for طالع بین (offline-first).
///
/// Uses `package:sqlite3` directly (no codegen) with explicit versioned
/// migrations via `PRAGMA user_version`.
///
/// Tables: profiles, partners, daily_horoscopes.
/// (Zodiac signs & compatibility live as static domain content — see
/// product spec §53 — so no sync burden exists for immutable data.)
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  /// Current schema version. Append a migration block when bumping.
  static const int schemaVersion = 1;

  /// Opens the on-disk database (app usage).
  static Future<AppDatabase> openDefault() async {
    final dir = await getApplicationDocumentsDirectory();
    return open(p.join(dir.path, 'taalebin.sqlite'));
  }

  /// Opens a database at an explicit path (or in-memory when null).
  static AppDatabase open(String? path) {
    final db = path == null ? sqlite3.openInMemory() : sqlite3.open(path);
    final instance = AppDatabase._(db);
    instance._migrate();
    return instance;
  }

  Database get raw => _db;

  // ── Migrations ────────────────────────────────────────────────────

  /// Re-runs migrations (idempotent). Public for tests and future upgrades.
  void ensureMigrated() => _migrate();

  void _migrate() {
    final current = _userVersion();
    if (current >= schemaVersion) return;

    if (current < 1) {
      _tx([
        '''
        CREATE TABLE IF NOT EXISTS profiles (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          birth_date TEXT NOT NULL,
          birth_time TEXT,
          birth_time_known INTEGER NOT NULL DEFAULT 0,
          birth_city TEXT,
          zodiac_id TEXT NOT NULL,
          is_primary INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
        ''',
        '''
        CREATE TABLE IF NOT EXISTS partners (
          id TEXT PRIMARY KEY,
          profile_id TEXT NOT NULL,
          name TEXT NOT NULL,
          birth_date TEXT NOT NULL,
          birth_time TEXT,
          birth_city TEXT,
          zodiac_id TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
        ''',
        '''
        CREATE INDEX IF NOT EXISTS idx_partners_profile ON partners(profile_id)
        ''',
        '''
        CREATE TABLE IF NOT EXISTS daily_horoscopes (
          id TEXT PRIMARY KEY,
          zodiac_id TEXT NOT NULL,
          date TEXT NOT NULL,
          love_score INTEGER NOT NULL,
          career_score INTEGER NOT NULL,
          finance_score INTEGER NOT NULL,
          mood_score INTEGER NOT NULL,
          energy_score INTEGER NOT NULL,
          general_text TEXT NOT NULL,
          love_text TEXT NOT NULL,
          career_text TEXT NOT NULL,
          finance_text TEXT NOT NULL,
          mood_text TEXT NOT NULL,
          warning_text TEXT NOT NULL,
          opportunity_text TEXT NOT NULL,
          lucky_color TEXT NOT NULL,
          lucky_number INTEGER NOT NULL,
          lucky_time TEXT NOT NULL,
          generated_version INTEGER NOT NULL,
          created_at TEXT NOT NULL
        )
        ''',
        '''
        CREATE UNIQUE INDEX IF NOT EXISTS idx_daily_unique
          ON daily_horoscopes(zodiac_id, date)
        ''',
      ]);
    }

    _setUserVersion(schemaVersion);
  }

  void _tx(List<String> statements) {
    _db.execute('BEGIN');
    try {
      for (final s in statements) {
        _db.execute(s);
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  int _userVersion() {
    final row = _db.select('PRAGMA user_version');
    return row.isNotEmpty ? row[0][0] as int : 0;
  }

  void _setUserVersion(int version) {
    _db.execute('PRAGMA user_version = $version');
  }

  // ── Profile CRUD ──────────────────────────────────────────────────

  /// Primary (only) profile, or null.
  Map<String, Object?>? primaryProfile() {
    final rows = _db.select('SELECT * FROM profiles ORDER BY created_at LIMIT 1');
    return rows.isNotEmpty ? rows[0] : null;
  }

  void upsertProfile(Map<String, Object?> profile) {
    _db.execute(
      '''
      INSERT INTO profiles (id, name, birth_date, birth_time, birth_time_known,
        birth_city, zodiac_id, is_primary, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        birth_date = excluded.birth_date,
        birth_time = excluded.birth_time,
        birth_time_known = excluded.birth_time_known,
        birth_city = excluded.birth_city,
        zodiac_id = excluded.zodiac_id,
        updated_at = excluded.updated_at
      ''',
      [
        profile['id'],
        profile['name'],
        profile['birth_date'],
        profile['birth_time'],
        profile['birth_time_known'],
        profile['birth_city'],
        profile['zodiac_id'],
        profile['created_at'],
        profile['updated_at'],
      ],
    );
  }

  // ── Partner CRUD ──────────────────────────────────────────────────

  Map<String, Object?>? partnerFor(String profileId) {
    final rows = _db.select(
      'SELECT * FROM partners WHERE profile_id = ? ORDER BY created_at LIMIT 1',
      [profileId],
    );
    return rows.isNotEmpty ? rows[0] : null;
  }

  void upsertPartner(Map<String, Object?> partner) {
    _db.execute(
      '''
      INSERT INTO partners (id, profile_id, name, birth_date, birth_time,
        birth_city, zodiac_id, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        name = excluded.name,
        birth_date = excluded.birth_date,
        birth_time = excluded.birth_time,
        birth_city = excluded.birth_city,
        zodiac_id = excluded.zodiac_id
      ''',
      [
        partner['id'],
        partner['profile_id'],
        partner['name'],
        partner['birth_date'],
        partner['birth_time'],
        partner['birth_city'],
        partner['zodiac_id'],
        partner['created_at'],
      ],
    );
  }

  void deletePartner(String partnerId) {
    _db.execute('DELETE FROM partners WHERE id = ?', [partnerId]);
  }

  // ── Daily horoscope cache ─────────────────────────────────────────

  Map<String, Object?>? dailyHoroscope(String zodiacId, String dayKey) {
    final rows = _db.select(
      'SELECT * FROM daily_horoscopes WHERE zodiac_id = ? AND date = ?',
      [zodiacId, dayKey],
    );
    return rows.isNotEmpty ? rows[0] : null;
  }

  void cacheDailyHoroscope(Map<String, Object?> row) {
    _db.execute(
      '''
      INSERT OR REPLACE INTO daily_horoscopes (id, zodiac_id, date,
        love_score, career_score, finance_score, mood_score, energy_score,
        general_text, love_text, career_text, finance_text, mood_text,
        warning_text, opportunity_text, lucky_color, lucky_number, lucky_time,
        generated_version, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        row['id'],
        row['zodiac_id'],
        row['date'],
        row['love_score'],
        row['career_score'],
        row['finance_score'],
        row['mood_score'],
        row['energy_score'],
        row['general_text'],
        row['love_text'],
        row['career_text'],
        row['finance_text'],
        row['mood_text'],
        row['warning_text'],
        row['opportunity_text'],
        row['lucky_color'],
        row['lucky_number'],
        row['lucky_time'],
        row['generated_version'],
        row['created_at'],
      ],
    );
  }

  /// Purges cached horoscopes whose generator version is older than
  /// [version] (cheap forward-migration of cached content).
  int purgeStaleHoroscopes(int version) {
    _db.execute(
      'DELETE FROM daily_horoscopes WHERE generated_version < ?',
      [version],
    );
    return _db.updatedRows;
  }

  // ── Reset ─────────────────────────────────────────────────────────

  /// Deletes all user data (profiles, partners, horoscope cache).
  /// Used by "حذف تمام اطلاعات من" in settings.
  void wipeAll() {
    _tx([
      'DELETE FROM partners',
      'DELETE FROM daily_horoscopes',
      'DELETE FROM profiles',
    ]);
  }

  /// Clears only the generated-horoscope cache (keeps user data).
  void clearHoroscopeCache() {
    _db.execute('DELETE FROM daily_horoscopes');
  }

  void close() => _db.dispose();
}
