class Name {
  const Name({
    required this.id,
    required this.displayName,
    required this.normalizedName,
    required this.transliteration,
    required this.language,
    required this.origin,
    required this.gender,
    required this.meaning,
    required this.etymology,
    required this.pronunciation,
    required this.status,
    required this.confidence,
    required this.styles,
    required this.sourceTitle,
    required this.sourceNote,
  });

  final String id;
  final String displayName;
  final String normalizedName;
  final String transliteration;
  final String language;
  final String origin;
  final String gender;
  final String meaning;
  final String etymology;
  final String pronunciation;
  final String status;
  final String confidence;
  final List<String> styles;
  final String sourceTitle;
  final String sourceNote;

  bool get isVerified => status == 'verified';
  bool get isUnverified => status == 'unverified';
  int get letterCount => normalizedName.replaceAll(RegExp(r'\s+'), '').runes.length;

  factory Name.fromMap(Map<String, Object?> map) {
    final styles = (map['styles'] as String? ?? '')
        .split('|')
        .where((item) => item.trim().isNotEmpty)
        .toList(growable: false);
    return Name(
      id: map['id'] as String,
      displayName: map['display_name'] as String? ?? '',
      normalizedName: map['normalized_name'] as String? ?? '',
      transliteration: map['transliteration'] as String? ?? '',
      language: map['language'] as String? ?? 'نامشخص',
      origin: map['origin'] as String? ?? 'نامشخص',
      gender: map['gender'] as String? ?? 'نامشخص',
      meaning: map['meaning'] as String? ?? 'نامشخص',
      etymology: map['etymology'] as String? ?? 'اطلاعات ریشه‌شناختی ثبت نشده است.',
      pronunciation: map['pronunciation'] as String? ?? 'نامشخص',
      status: map['status'] as String? ?? 'unverified',
      confidence: map['confidence'] as String? ?? 'low',
      styles: styles,
      sourceTitle: map['source_title'] as String? ?? 'بدون منبع',
      sourceNote: map['source_note'] as String? ?? '',
    );
  }
}
