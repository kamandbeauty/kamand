class NamePronunciation {
  const NamePronunciation({
    required this.id,
    required this.nameId,
    required this.language,
    required this.ipa,
    required this.localPhonetic,
    required this.dialect,
    required this.status,
    required this.confidence,
    required this.sourceTitle,
    required this.sourceUrl,
  });

  final String id;
  final String nameId;
  final String language;
  final String ipa;
  final String localPhonetic;
  final String dialect;
  final String status;
  final String confidence;
  final String sourceTitle;
  final String sourceUrl;

  bool get hasIpa => ipa.trim().isNotEmpty;

  factory NamePronunciation.fromMap(Map<String, Object?> map) {
    return NamePronunciation(
      id: map['id'] as String? ?? '',
      nameId: map['name_id'] as String? ?? '',
      language: map['language_title'] as String? ?? map['language_code'] as String? ?? 'نامشخص',
      ipa: map['ipa'] as String? ?? '',
      localPhonetic: map['local_phonetic'] as String? ?? '',
      dialect: map['dialect'] as String? ?? '',
      status: map['status'] as String? ?? 'unknown',
      confidence: map['confidence'] as String? ?? 'low',
      sourceTitle: map['source_title'] as String? ?? 'بدون منبع',
      sourceUrl: map['source_url'] as String? ?? '',
    );
  }
}
