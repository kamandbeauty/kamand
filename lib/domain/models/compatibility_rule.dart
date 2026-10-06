class CompatibilityRule {
  const CompatibilityRule({
    required this.systemKey,
    required this.systemTitle,
    required this.ruleKey,
    required this.operation,
    this.configurationJson = '{}',
    required this.version,
    required this.status,
    required this.disclaimer,
    required this.sourceTitle,
  });

  final String systemKey;
  final String systemTitle;
  final String ruleKey;
  final String operation;
  final String configurationJson;
  final String version;
  final String status;
  final String disclaimer;
  final String sourceTitle;

  factory CompatibilityRule.fromMap(Map<String, Object?> map) {
    return CompatibilityRule(
      systemKey: map['system_key'] as String? ?? '',
      systemTitle: map['system_title'] as String? ?? '',
      ruleKey: map['rule_key'] as String? ?? '',
      operation: map['operation'] as String? ?? '',
      configurationJson: map['configuration_json'] as String? ?? '{}',
      version: map['version'] as String? ?? '',
      status: map['status'] as String? ?? 'unverified',
      disclaimer: map['disclaimer'] as String? ?? 'این شاخص علمی یا پیش‌بینی‌کننده رابطه نیست.',
      sourceTitle: map['source_title'] as String? ?? 'بدون منبع',
    );
  }
}
