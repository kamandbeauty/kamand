class CompatibilityResult {
  const CompatibilityResult({
    required this.score,
    required this.label,
    required this.method,
    required this.disclaimer,
    this.ruleKey = '',
    this.ruleVersion = '',
    this.calculation = '',
    this.status = 'unverified',
    this.sourceTitle = 'بدون منبع',
    this.isAvailable = true,
  });

  final int? score;
  final String label;
  final String method;
  final String disclaimer;
  final String ruleKey;
  final String ruleVersion;
  final String calculation;
  final String status;
  final String sourceTitle;
  final bool isAvailable;
}
