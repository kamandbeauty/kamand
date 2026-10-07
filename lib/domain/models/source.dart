class Source {
  const Source({
    required this.id,
    required this.title,
    required this.author,
    required this.publisher,
    required this.year,
    required this.language,
    required this.type,
    required this.url,
    required this.reliability,
    required this.notes,
    required this.license,
    required this.accessedAt,
    required this.coverage,
    required this.reviewStatus,
  });

  final String id;
  final String title;
  final String author;
  final String publisher;
  final int? year;
  final String language;
  final String type;
  final String url;
  final String reliability;
  final String notes;
  final String license;
  final String accessedAt;
  final String coverage;
  final String reviewStatus;

  factory Source.fromMap(Map<String, Object?> map) {
    return Source(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      author: map['author'] as String? ?? 'نامشخص',
      publisher: map['publisher'] as String? ?? 'نامشخص',
      year: map['publication_year'] as int?,
      language: map['language'] as String? ?? 'fa',
      type: map['source_type'] as String? ?? 'unknown',
      url: map['url'] as String? ?? '',
      reliability: map['reliability_level'] as String? ?? 'low',
      notes: map['notes'] as String? ?? '',
      license: map['license'] as String? ?? '',
      accessedAt: map['accessed_at'] as String? ?? '',
      coverage: map['coverage'] as String? ?? '',
      reviewStatus: map['review_status'] as String? ?? 'pending',
    );
  }
}
