class PersianNumberFormatter {
  static const List<String> _englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  static const List<String> _persianDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

  static String toPersian(dynamic input) {
    if (input == null) return '';
    String str = input.toString();
    for (int i = 0; i < _englishDigits.length; i++) {
      str = str.replaceAll(_englishDigits[i], _persianDigits[i]);
    }
    return str;
  }

  static String formatCurrency(double amount, {String unit = 'تومان'}) {
    final numStr = amount.round().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '${toPersian(numStr)} $unit';
  }
}
