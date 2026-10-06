class ArchiveEntry {
  const ArchiveEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.body,
    required this.sourceTitle,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String category;
  final String body;
  final String sourceTitle;
  final String status;
  final String createdAt;

  factory ArchiveEntry.fromMap(Map<String, Object?> map) {
    return ArchiveEntry(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      category: map['category'] as String? ?? 'عمومی',
      body: map['body'] as String? ?? '',
      sourceTitle: map['source_title'] as String? ?? 'بدون منبع',
      status: map['status'] as String? ?? 'unverified',
      createdAt: map['created_at'] as String? ?? '',
    );
  }
}
