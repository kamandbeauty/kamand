class AbjadSystem {
  const AbjadSystem({
    required this.key,
    required this.title,
    required this.description,
    required this.formula,
    required this.sourceTitle,
    required this.version,
    required this.status,
  });

  final String key;
  final String title;
  final String description;
  final String formula;
  final String sourceTitle;
  final String version;
  final String status;

  factory AbjadSystem.fromMap(Map<String, Object?> map) {
    return AbjadSystem(
      key: map['system_key'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      formula: map['formula'] as String? ?? 'نامشخص',
      sourceTitle: map['source_title'] as String? ?? 'بدون منبع',
      version: map['version'] as String? ?? '',
      status: map['status'] as String? ?? 'unverified',
    );
  }
}
