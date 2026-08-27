import 'package:flutter_test/flutter_test.dart';
import 'package:factor_ruby/store/core/money.dart';

void main() {
  group('Money', () {
    test('تقسیم مساوی بدون گم‌شدن مبلغ', () {
      final parts = Money.splitEvenly(10_000_000, 4);
      expect(parts.length, 4);
      expect(parts.fold(0, (a, b) => a + b), 10_000_000);
      expect(parts, equals([2_500_000, 2_500_000, 2_500_000, 2_500_000]));
    });

    test('تقسیم نامساوی (باقیمانده روی قسط اول)', () {
      final parts = Money.splitEvenly(1_000_001, 3);
      expect(parts.fold(0, (a, b) => a + b), 1_000_001);
      expect(parts.first, greaterThan(parts.last));
    });

    test('درصد با basis points دقیق است', () {
      expect(Money.percentOf(10_000_000, 600), 600_000);
      expect(Money.percentOf(10_000_000, 0), 0);
      expect(Money.percentOf(0, 600), 0);
    });

    test('تبدیل double قدیمی به Long بدون خطا', () {
      expect(Money.fromDouble(1234567.6), 1234568);
      expect(Money.fromDouble(-0.4), 0);
    });
  });

  group('CommissionCalculator — سناریوی بحرانی §60', () {
    test('ترب‌پی: ۱۰م با کارمزد ۶٪ → تسویهٔ ۹٫۴م', () {
      final b = CommissionCalculator.calculate(
        grossFinanced: 10_000_000,
        commissionBps: 600,
      );
      expect(b.commission, 600_000);
      expect(b.commissionVat, 0);
      expect(b.netSettlement, 9_400_000);
      expect(b.reconciles, isTrue);
      expect(
        b.commission + b.netSettlement,
        equals(b.grossFinanced),
      );
    });

    test('کارمزد + مالیات ارزش افزوده', () {
      final b = CommissionCalculator.calculate(
        grossFinanced: 1_000_000,
        commissionBps: 300,
        commissionVatBps: 1000, // ۱۰٪
      );
      expect(b.commission, 30_000);
      expect(b.commissionVat, 3_000);
      expect(b.netSettlement, 967_000);
      expect(b.reconciles, isTrue);
    });

    test('کارمزد ثابت + کسورات', () {
      final b = CommissionCalculator.calculate(
        grossFinanced: 5_000_000,
        commissionBps: 200,
        commissionFixed: 50_000,
        otherDeductions: 100_000,
      );
      expect(b.commission, 150_000);
      expect(b.netSettlement, 4_750_000);
      expect(b.reconciles, isTrue);
    });

    test('کارمزد بیشتر از اصل مبلغ cap می‌شود', () {
      final b = CommissionCalculator.calculate(
        grossFinanced: 100_000,
        commissionBps: 20000,
      );
      expect(b.commission, 100_000);
      expect(b.netSettlement, 0);
      expect(b.reconciles, isTrue);
    });

    test('مبلغ منفی رد می‌شود', () {
      expect(
        () => CommissionCalculator.calculate(grossFinanced: -1, commissionBps: 0),
        throwsArgumentError,
      );
    });
  });
}
