class BankCardModel {
  final String id;
  final String cardNumber; // 16 digits without dash, e.g. 6104337767686528
  final String sheba; // without IR, max 24 digits
  final String bankName; // e.g. بانک ملت
  final String persianName; // e.g. جاوید سلمان

  BankCardModel({
    required this.id,
    required this.cardNumber,
    required this.sheba,
    required this.bankName,
    required this.persianName,
  });

  /// گروه‌بندی ۴تایی با حفظ ترتیب LTR (از چپ به راست ارقام اصلی)
  static String groupDigits(String digits, {int groupSize = 4}) {
    final d = digits.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return '';
    final buf = StringBuffer();
    for (int i = 0; i < d.length; i++) {
      if (i > 0 && i % groupSize == 0) buf.write(' ');
      buf.write(d[i]);
    }
    return buf.toString();
  }

  String get formattedCard => groupDigits(cardNumber);

  String get spacedCardDash {
    final d = cardNumber.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return '';
    final buf = StringBuffer();
    for (int i = 0; i < d.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' - ');
      buf.write(d[i]);
    }
    return buf.toString();
  }

  /// فقط ۲۴ رقم شبا (بدون pad اشتباه که ترتیب را خراب کند)
  String get sheba24 {
    final d = sheba.replaceAll(RegExp(r'\D'), '');
    if (d.length <= 24) return d;
    return d.substring(d.length - 24);
  }

  String get formattedSheba => sheba24.isEmpty ? '' : 'IR$sheba24';

  /// شبا فاصله‌دار: IR25 5475 9665 ... (حفظ ترتیب LTR)
  String get spacedSheba {
    final full = formattedSheba;
    if (full.isEmpty) return '';
    final buf = StringBuffer();
    for (int i = 0; i < full.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(full[i]);
    }
    return buf.toString();
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'cardNumber': cardNumber,
        'sheba': sheba,
        'bankName': bankName,
        'persianName': persianName,
      };

  factory BankCardModel.fromMap(Map<String, dynamic> m) => BankCardModel(
        id: m['id'] ?? '',
        cardNumber: m['cardNumber'] ?? '',
        sheba: m['sheba'] ?? '',
        bankName: m['bankName'] ?? '',
        persianName: m['persianName'] ?? '',
      );
}
