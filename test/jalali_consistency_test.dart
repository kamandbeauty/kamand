import 'package:flutter_test/flutter_test.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:taalebin/core/date/app_date.dart';
import 'package:taalebin/domain/astrology/natal_engine.dart';

/// Cross-checks the natal engine's own Jalali→Gregorian conversion (a
/// 33-year-cycle implementation, verified against historical anchors in
/// tool/natal_engine_validate.py) against the app-wide shamsi_date
/// calendar — the authority behind every other screen. If the two ever
/// disagree, a birth chart would show for the wrong day.
void main() {
  group('NatalEngine calendar vs shamsi_date (1300–1450 AP)', () {
    test('every sampled date converts to the same Gregorian day', () {
      for (var jy = 1300; jy <= 1450; jy++) {
        for (var jm = 1; jm <= 12; jm++) {
          final days = <int>[1, 10, 20, 29];
          if (jm <= 11) days.add(30);
          if (jm == 12 && AppDate.isValid(jy, 12, 30)) days.add(30);
          for (final jd in days) {
            final utc = NatalEngine.jalaliBirthToUtc(jy, jm, jd, '12:00');
            final g = Jalali(jy, jm, jd).toDateTime();
            expect(
              '${utc.year}-${utc.month}-${utc.day}',
              '${g.year}-${g.month}-${g.day}',
              reason: '$jy-$jm-$jd: engine ${utc.year}-${utc.month}-'
                  '${utc.day} vs shamsi ${g.year}-${g.month}-${g.day}',
            );
          }
        }
      }
    });

    test('leap years agree with shamsi_date via Esfand 30', () {
      for (var jy = 1300; jy <= 1450; jy++) {
        final shamsiLeap = AppDate.isValid(jy, 12, 30);
        // Engine: Esfand 30 → Farvardin 1 gap must match leap-ness.
        final esfand29 = NatalEngine.jalaliBirthToUtc(jy, 12, 29, '12:00');
        final nextNowruz = NatalEngine.jalaliBirthToUtc(jy + 1, 1, 1, '12:00');
        final dayGap =
            nextNowruz.difference(esfand29).inHours.clamp(0, 96) / 24.0;
        if (shamsiLeap) {
          // 1399-12-29 → 1400-01-01 is 2 days (Esfand 30 exists).
          expect(dayGap, 2.0, reason: '$jy should be leap');
        } else {
          expect(dayGap, 1.0, reason: '$jy should NOT be leap');
        }
      }
    });

    test('known anchors', () {
      // Unix epoch day + the golden-chart birth day.
      expect(NatalEngine.jalaliBirthToUtc(1348, 10, 11, '12:00'),
          DateTime.utc(1970, 1, 1, 8, 30));
      expect(NatalEngine.jalaliBirthToUtc(1370, 5, 12, '12:00'),
          DateTime.utc(1991, 8, 3, 8, 30));
      // Esfand 30 of 1399 (leap) exists; of 1400 it does not.
      expect(AppDate.isValid(1399, 12, 30), isTrue);
      expect(AppDate.isValid(1400, 12, 30), isFalse);
    });
  });
}
