import 'dart:math';

import '../../core/date/app_date.dart';
import '../../domain/profile/profile.dart';
import '../database/app_database.dart';

/// Repository abstraction over user/partner storage (future remote sync can
/// implement this without UI changes — product spec §25).
abstract class ProfileRepository {
  Future<Profile?> primaryProfile();
  Future<void> saveProfile(Profile profile);
  Future<Partner?> partnerForProfile(String profileId);
  Future<void> savePartner(Partner partner);
  Future<void> deletePartner(String partnerId);
  Future<void> wipeAll();
}

class LocalProfileRepository implements ProfileRepository {
  LocalProfileRepository(this._db);

  final AppDatabase _db;

  static Profile _rowToProfile(Map<String, Object?> row) => Profile(
        id: row['id']! as String,
        name: row['name']! as String,
        birthDate: row['birth_date']! as String,
        birthTime: row['birth_time'] as String?,
        birthTimeKnown: (row['birth_time_known'] as int) == 1,
        birthCity: row['birth_city'] as String?,
        zodiacId: row['zodiac_id']! as String,
        isPrimary: (row['is_primary'] as int) == 1,
        createdAt: row['created_at']! as String,
        updatedAt: row['updated_at']! as String,
      );

  static Partner _rowToPartner(Map<String, Object?> row) => Partner(
        id: row['id']! as String,
        profileId: row['profile_id']! as String,
        name: row['name']! as String,
        birthDate: row['birth_date']! as String,
        birthTime: row['birth_time'] as String?,
        birthCity: row['birth_city'] as String?,
        zodiacId: row['zodiac_id']! as String,
        createdAt: row['created_at']! as String,
      );

  @override
  Future<Profile?> primaryProfile() async {
    final row = _db.primaryProfile();
    return row == null ? null : _rowToProfile(row);
  }

  @override
  Future<void> saveProfile(Profile profile) async {
    _db.upsertProfile({
      'id': profile.id,
      'name': profile.name,
      'birth_date': profile.birthDate,
      'birth_time': profile.birthTime,
      'birth_time_known': profile.birthTimeKnown ? 1 : 0,
      'birth_city': profile.birthCity,
      'zodiac_id': profile.zodiacId,
      'created_at': profile.createdAt,
      'updated_at': profile.updatedAt,
    });
  }

  @override
  Future<Partner?> partnerForProfile(String profileId) async {
    final row = _db.partnerFor(profileId);
    return row == null ? null : _rowToPartner(row);
  }

  @override
  Future<void> savePartner(Partner partner) async {
    _db.upsertPartner({
      'id': partner.id,
      'profile_id': partner.profileId,
      'name': partner.name,
      'birth_date': partner.birthDate,
      'birth_time': partner.birthTime,
      'birth_city': partner.birthCity,
      'zodiac_id': partner.zodiacId,
      'created_at': partner.createdAt,
    });
  }

  @override
  Future<void> deletePartner(String partnerId) async {
    _db.deletePartner(partnerId);
  }

  @override
  Future<void> wipeAll() async {
    _db.wipeAll();
  }
}

/// Small id generator (timestamp + random suffix — not used for any
/// deterministic domain math).
String generateId() {
  final rng = Random();
  final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final suffix =
      List.generate(6, (_) => rng.nextInt(36).toRadixString(36)).join();
  return '$ts$suffix';
}

String utcNowIso() => DateTime.now().toUtc().toIso8601String();

/// Parses "1370-05-12" into a Jalali date, or null when malformed.
/// Never throws for user data (error handling spec §36).
 JalaliDateParseResult? parseJalaliDateKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  if (!AppDate.isValid(y, m, d)) return null;
  return JalaliDateParseResult(y, m, d);
}

class JalaliDateParseResult {
  const JalaliDateParseResult(this.year, this.month, this.day);
  final int year;
  final int month;
  final int day;
}
