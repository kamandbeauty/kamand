/// ابزار پولی هستهٔ حسابداری — همهٔ مبالغ به «تومان» و از نوع Long/INT هستند.
/// طبق قانون طلایی شمارهٔ ۳ و ۴: هرگز از double/float برای محاسبات مالی استفاده نمی‌شود.
library;

class Money {
  /// تبدیل ایمن هر عدد (حتی double قدیمی لایهٔ نمایش) به تومان صحیح.
  static int fromDouble(num value) => value.round().toInt();

  /// جمع امن مبالغ
  static int sum(Iterable<int> values) => values.fold(0, (a, b) => a + b);

  /// درصدِ صحیح از یک مبلغ با دقت «۱۰۰ برابر» (basis points =bps)
  /// مثال: percentOf(10_000_000, 600) == 600_000  (۶۰۰bps == ۶٪)
  static int percentOf(int amount, int bps) {
    if (amount == 0 || bps == 0) return 0;
    return (amount * bps) ~/ 10000;
  }

  /// تقسیم مبلغ به n سهم مساوی بدون گم‌شدن ریال؛ سهم باقی‌مانده به قسط اول می‌رسد.
  static List<int> splitEvenly(int amount, int parts) {
    if (parts <= 0) return [];
    if (amount <= 0) return List.filled(parts, 0);
    final base = amount ~/ parts;
    final remainder = amount - base * parts;
    return [
      for (var i = 0; i < parts; i++) i == 0 ? base + remainder : base,
    ];
  }

  /// فرمت نمایش با جداکنندهٔ هزارگان (اعداد انگلیسی برای استفادهٔ داخلی)
  static String format(int amount) {
    final s = amount.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return amount < 0 ? '-${buf.toString()}' : buf.toString();
  }
}

/// شکست شفاف محاسبهٔ کارمزد سیستم اقساطی (§19)
/// همهٔ محاسبات با اعداد صحیح انجام می‌شود.
class CommissionBreakdown {
  final int grossFinanced; // مبلغ تأمین‌شده توسط سیستم اقساطی
  final int commission; // کارمزد درصدی + ثابت
  final int commissionVat; // مالیات بر ارزش افزودهٔ کارمزد (در صورت پیکربندی)
  final int otherDeductions; // کسورات قراردادی دیگر
  final int netSettlement; // تسویهٔ مورد انتظار از سیستم

  const CommissionBreakdown({
    required this.grossFinanced,
    required this.commission,
    required this.commissionVat,
    required this.otherDeductions,
    required this.netSettlement,
  });

  /// commission + vat + deductions + net باید دقیقاً برابر gross باشد (ناسازگاری = باگ)
  bool get reconciles =>
      commission + commissionVat + otherDeductions + netSettlement ==
      grossFinanced;

  @override
  String toString() =>
      'CommissionBreakdown(gross: $grossFinanced, commission: $commission, '
      'vat: $commissionVat, deductions: $otherDeductions, net: $netSettlement)';
}

class CommissionCalculator {
  /// محاسبهٔ کارمزد بر اساس پیکربندی قرارداد هر سیستم اقساطی.
  /// [commissionBps] درصد کارمزد ×۱۰۰ (۶٪ = ۶۰۰)
  /// [commissionFixed] کارمزد ثابت به تومان
  /// [commissionVatBps] نرخ مالیات ارزش افزوده روی کارمزد ×۱۰۰ (۱۰٪ = ۱۰۰۰؛ صفر = بدون مالیات)
  /// [otherDeductions] کسورات توافقی ثابت به تومان
  ///
  /// نکتهٔ مهم: هیچ نرخی اینجا hard-code نیست؛ همه از پیکربندی provider می‌آید.
  static CommissionBreakdown calculate({
    required int grossFinanced,
    required int commissionBps,
    int commissionFixed = 0,
    int commissionVatBps = 0,
    int otherDeductions = 0,
  }) {
    if (grossFinanced < 0) throw ArgumentError('grossFinanced نمی‌تواند منفی باشد');
    final commission =
        Money.percentOf(grossFinanced, commissionBps) + commissionFixed;
    // کارمزد ثابت نباید از اصل مبلغ بیشتر شود
    final cappedCommission = commission > grossFinanced ? grossFinanced : commission;
    final commissionVat = Money.percentOf(cappedCommission, commissionVatBps);
    var deductions = cappedCommission + commissionVat + otherDeductions;
    if (deductions > grossFinanced) deductions = grossFinanced;
    final net = grossFinanced - deductions;
    return CommissionBreakdown(
      grossFinanced: grossFinanced,
      commission: cappedCommission,
      commissionVat: commissionVat,
      otherDeductions: otherDeductions,
      netSettlement: net,
    );
  }
}
