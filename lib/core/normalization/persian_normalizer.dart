class PersianNormalizer {
  const PersianNormalizer._();

  static const Map<String, String> _characterMap = {
    'ي': 'ی',
    'ى': 'ی',
    'ی': 'ی',
    'ك': 'ک',
    'ک': 'ک',
    'ۀ': 'ه',
    'ة': 'ه',
    'ؤ': 'و',
    'ئ': 'ی',
    'أ': 'ا',
    'إ': 'ا',
    'ٱ': 'ا',
    'ء': 'ا',
    'ـ': '',
  };

  static const Map<String, String> _digitMap = {
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
  };

  static String normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final character = String.fromCharCode(rune);
      buffer.write(_characterMap[character] ?? character);
    }
    return buffer
        .toString()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll('\u200c', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  static String normalizeForSearch(String input) {
    return normalize(input).replaceAll(RegExp(r'[^\u0600-\u06FFa-z0-9 ]'), '');
  }

  static String toLatinDigits(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final character = String.fromCharCode(rune);
      buffer.write(_digitMap[character] ?? character);
    }
    return buffer.toString();
  }

  static String toPersianDigits(Object value) {
    const digits = '۰۱۲۳۴۵۶۷۸۹';
    return value
        .toString()
        .split('')
        .map((character) {
          final digit = int.tryParse(character);
          return digit == null ? character : digits[digit];
        })
        .join();
  }
}
