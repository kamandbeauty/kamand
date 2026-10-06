import '../../core/normalization/persian_normalizer.dart';
import '../models/name.dart';

class SmartSearchQuery {
  const SmartSearchQuery({
    required this.text,
    required this.gender,
    required this.style,
    required this.firstLetter,
    required this.maxLetters,
  });

  final String text;
  final String? gender;
  final String? style;
  final String? firstLetter;
  final int? maxLetters;
}

class SmartSearchEngine {
  const SmartSearchEngine();

  SmartSearchQuery parse(String input) {
    final normalized = PersianNormalizer.normalizeForSearch(PersianNormalizer.toLatinDigits(input));
    final tokens = normalized.split(' ').where((token) => token.isNotEmpty).toList();
    String? gender;
    String? style;
    String? firstLetter;
    int? maxLetters;

    if (tokens.contains('دختر')) gender = 'دختر';
    if (tokens.contains('پسر')) gender = 'پسر';

    const styles = ['ایرانی', 'فارسی', 'باستانی', 'کردی', 'لری', 'ترکی', 'عربی', 'مذهبی', 'مدرن', 'سنتی', 'بین المللی', 'خاص', 'کمیاب', 'کوتاه'];
    for (final candidate in styles) {
      if (normalized.contains(candidate)) {
        style = candidate;
        break;
      }
    }

    final firstMatch = RegExp(r'(?:با|حرف)\s+([اآبپتثجچحخدذرزژسشصضطظعغفقکگلمنوهی])').firstMatch(normalized);
    if (firstMatch != null) firstLetter = firstMatch.group(1);

    final lengthMatch = RegExp(r'(?:کمتر از|حداکثر)\s*([0-9]+)\s*حرف').firstMatch(PersianNormalizer.toLatinDigits(normalized));
    if (lengthMatch != null) maxLetters = int.tryParse(lengthMatch.group(1)!);
    if (normalized.contains('کوتاه') && maxLetters == null) maxLetters = 5;

    final stopWords = {
      'اسم', 'نام', 'دختر', 'پسر', 'به', 'معنی', 'با', 'حرف', 'کمتر', 'از', 'حداکثر',
      ...styles,
    };
    final text = tokens.where((token) => !stopWords.contains(token) && token != 'بین' && token != 'المللی').join(' ');
    return SmartSearchQuery(text: text, gender: gender, style: style, firstLetter: firstLetter, maxLetters: maxLetters);
  }

  List<Name> search({required List<Name> names, required String input, String selectedStyle = 'همه'}) {
    final query = parse(input);
    return names.where((name) {
      final normalizedName = PersianNormalizer.normalizeForSearch(name.displayName);
      final textMatches = query.text.isEmpty ||
          name.normalizedName.contains(query.text) ||
          PersianNormalizer.normalizeForSearch(name.meaning).contains(query.text) ||
          PersianNormalizer.normalizeForSearch(name.origin).contains(query.text);
      final genderMatches = query.gender == null || name.gender == query.gender;
      final styleMatches = selectedStyle == 'همه' || name.styles.contains(selectedStyle) || query.style == selectedStyle;
      final parsedStyleMatches = query.style == null || name.styles.contains(query.style) || query.style == 'بین المللی' && name.styles.contains('بین‌المللی');
      final firstMatches = query.firstLetter == null || normalizedName.startsWith(query.firstLetter!);
      final lengthMatches = query.maxLetters == null || name.letterCount <= query.maxLetters!;
      return textMatches && genderMatches && styleMatches && parsedStyleMatches && firstMatches && lengthMatches;
    }).toList(growable: false);
  }
}
