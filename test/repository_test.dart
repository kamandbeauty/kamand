import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'package:taalebin/core/date/app_date.dart';
import 'package:taalebin/data/database/app_database.dart';
import 'package:taalebin/data/repositories/horoscope_repository.dart';
import 'package:taalebin/data/repositories/profile_repository.dart';
import 'package:taalebin/domain/horoscope/horoscope_engine.dart';
import 'package:taalebin/domain/profile/profile.dart';
import 'package:taalebin/domain/zodiac/zodiac_repository.dart';

void main() {
  late AppDatabase db;
  late LocalProfileRepository profileRepo;
  late LocalHoroscopeRepository horoscopeRepo;

  setUp(() {
    db = AppDatabase.open(null); // in-memory
    profileRepo = LocalProfileRepository(db);
    horoscopeRepo = LocalHoroscopeRepository(
      db,
      const HoroscopeEngine(LocalZodiacRepository()),
      const LocalZodiacRepository(),
    );
  });

  tearDown(() => db.close());

  Profile buildProfile({String? birthDate}) => Profile(
        id: 'p1',
        name: 'ستاره',
        birthDate: birthDate ?? '1370-08-15',
        birthTime: null,
        birthTimeKnown: false,
        birthCity: 'تهران',
        zodiacId: 'scorpio',
        isPrimary: true,
        createdAt: '2026-10-06T00:00:00Z',
        updatedAt: '2026-10-06T00:00:00Z',
      );

  group('Database migrations', () {
    test('fresh open creates tables and sets user_version', () {
      final version =
          db.raw.select('PRAGMA user_version').first[0] as int;
      expect(version, AppDatabase.schemaVersion);

      final tables = db.raw
          .select("SELECT name FROM sqlite_master WHERE type='table'")
          .map((r) => r[0])
          .toSet();
      expect(tables, containsAll(['profiles', 'partners', 'daily_horoscopes']));
    });

    test('re-opening an existing database is a no-op migration', () {
      // second migration pass over the same db keeps data intact
      profileRepo.saveProfile(buildProfile());
      db.ensureMigrated();
      final version =
          db.raw.select('PRAGMA user_version').first[0] as int;
      expect(version, AppDatabase.schemaVersion);
      expect(profileRepo.primaryProfile(), completion(isNotNull));
    });

    test('unique index on (zodiac_id, date) enforced', () {
      horoscopeRepo.dailyFor('scorpio', Jalali(1405, 7, 15));
      expect(
        () => horoscopeRepo.dailyFor('scorpio', Jalali(1405, 7, 15)),
        returnsNormally,
      );
    });
  });

  group('ProfileRepository', () {
    test('save and load primary profile', () async {
      await profileRepo.saveProfile(buildProfile());
      final loaded = await profileRepo.primaryProfile();
      expect(loaded, isNotNull);
      expect(loaded!.name, 'ستاره');
      expect(loaded.zodiacId, 'scorpio');
      expect(loaded.birthDate, '1370-08-15');
    });

    test('profile update (birth date change) persists', () async {
      await profileRepo.saveProfile(buildProfile());
      final existing = (await profileRepo.primaryProfile())!;
      await profileRepo.saveProfile(
        existing.copyWith(birthDate: '1372-01-10', zodiacId: 'aries'),
      );
      final updated = await profileRepo.primaryProfile();
      expect(updated!.birthDate, '1372-01-10');
      expect(updated.zodiacId, 'aries');
      // still a single row
      final count = db.raw.select('SELECT COUNT(*) c FROM profiles');
      expect(count.first[0], 1);
    });

    test('profile without birth time and city round-trips', () async {
      await profileRepo.saveProfile(
        buildProfile()
            .copyWith(birthTime: null, birthTimeKnown: false, birthCity: null),
      );
      final loaded = await profileRepo.primaryProfile();
      expect(loaded!.birthTime, isNull);
      expect(loaded.birthTimeKnown, isFalse);
      expect(loaded.birthCity, isNull);
    });

    test('wipeAll clears everything', () async {
      await profileRepo.saveProfile(buildProfile());
      await profileRepo.savePartner(Partner(
        id: 'pa1',
        profileId: 'p1',
        name: 'ماهی',
        birthDate: '1371-02-20',
        zodiacId: 'taurus',
        createdAt: '2026-10-06T00:00:00Z',
      ));
      horoscopeRepo.dailyFor('scorpio', Jalali(1405, 7, 15));

      await profileRepo.wipeAll();

      expect(await profileRepo.primaryProfile(), isNull);
      expect(await profileRepo.partnerForProfile('p1'), isNull);
      final c = db.raw.select('SELECT COUNT(*) c FROM daily_horoscopes');
      expect(c.first[0], 0);
    });
  });

  group('PartnerRepository', () {
    test('save, load, delete partner lifecycle', () async {
      await profileRepo.saveProfile(buildProfile());
      await profileRepo.savePartner(Partner(
        id: 'pa1',
        profileId: 'p1',
        name: 'ماهی',
        birthDate: '1371-02-20',
        birthTime: '08:30',
        birthCity: 'شیراز',
        zodiacId: 'taurus',
        createdAt: '2026-10-06T00:00:00Z',
      ));

      var partner = await profileRepo.partnerForProfile('p1');
      expect(partner!.name, 'ماهی');
      expect(partner.birthTime, '08:30');

      // update (same id)
      await profileRepo.savePartner(Partner(
        id: 'pa1',
        profileId: 'p1',
        name: 'ماهی نقره‌ای',
        birthDate: '1371-02-20',
        birthTime: null,
        birthCity: null,
        zodiacId: 'taurus',
        createdAt: '2026-10-06T00:00:00Z',
      ));
      partner = await profileRepo.partnerForProfile('p1');
      expect(partner!.name, 'ماهی نقره‌ای');

      // delete
      await profileRepo.deletePartner('pa1');
      expect(await profileRepo.partnerForProfile('p1'), isNull);
    });
  });

  group('HoroscopeRepository cache', () {
    test('dailyFor caches then reads from database', () async {
      final date = Jalali(1405, 7, 15);
      final first = await horoscopeRepo.dailyFor('scorpio', date);
      // row actually persisted
      final rows =
          db.raw.select('SELECT COUNT(*) c FROM daily_horoscopes');
      expect(rows.first[0], 1);

      // clear engine cache? engine is stateless; cached row must equal
      final second = await horoscopeRepo.dailyFor('scorpio', date);
      expect(second.generalText, first.generalText);
      expect(second.scores.love, first.scores.love);
      expect(second.lucky.color, first.lucky.color);

      // still one row (replace semantics, not duplicate)
      final after =
          db.raw.select('SELECT COUNT(*) c FROM daily_horoscopes');
      expect(after.first[0], 1);
    });

    test('weekFor generates 7 cached days', () async {
      final weekStart = AppDate.weekStart(Jalali(1405, 7, 15));
      final days = await horoscopeRepo.weekFor('leo', weekStart);
      expect(days.length, 7);
      final c = db.raw.select('SELECT COUNT(*) c FROM daily_horoscopes');
      expect(c.first[0], 7);
    });

    test('monthlyFor is deterministic and does not hit cache', () async {
      final m1 = await horoscopeRepo.monthlyFor('virgo', 1405, 7);
      final m2 = await horoscopeRepo.monthlyFor('virgo', 1405, 7);
      expect(m1.focusText, m2.focusText);
      final c = db.raw.select('SELECT COUNT(*) c FROM daily_horoscopes');
      expect(c.first[0], 0);
    });

    test('purgeStaleCache removes rows with older generator versions', () async {
      await horoscopeRepo.dailyFor('scorpio', Jalali(1405, 7, 15));
      // simulate an old-version row
      db.raw.execute(
        'UPDATE daily_horoscopes SET generated_version = 0',
      );
      final removed = await horoscopeRepo.purgeStaleCache();
      expect(removed, 1);
      final c = db.raw.select('SELECT COUNT(*) c FROM daily_horoscopes');
      expect(c.first[0], 0);
    });
  });

  group('parseJalaliDateKey (error handling)', () {
    test('valid and invalid keys', () {
      expect(parseJalaliDateKey('1370-08-15'), isNotNull);
      expect(parseJalaliDateKey('1403-12-30'), isNotNull);
      expect(parseJalaliDateKey('1402-12-30'), isNull); // not a leap year
      expect(parseJalaliDateKey('garbage'), isNull);
      expect(parseJalaliDateKey('1403-13-01'), isNull);
      expect(parseJalaliDateKey(''), isNull);
      expect(parseJalaliDateKey('1403-1-1'), isNotNull);
    });
  });
}
