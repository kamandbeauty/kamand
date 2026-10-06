import '../models/name.dart';

class NameSearchEngine {
  const NameSearchEngine();

  List<Name> filter({
    required List<Name> names,
    String query = '',
    String gender = 'همه',
    String style = 'همه',
    int? maxLetters,
  }) {
    final normalizedQuery = query.trim();
    return names.where((name) {
      final matchesQuery = normalizedQuery.isEmpty ||
          name.displayName.contains(normalizedQuery) ||
          name.meaning.contains(normalizedQuery) ||
          name.origin.contains(normalizedQuery);
      final matchesGender = gender == 'همه' || name.gender == gender;
      final matchesStyle = style == 'همه' || name.styles.contains(style);
      final matchesLength = maxLetters == null || name.letterCount <= maxLetters;
      return matchesQuery && matchesGender && matchesStyle && matchesLength;
    }).toList(growable: false);
  }
}
