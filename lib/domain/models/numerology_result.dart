class NumerologyResult {
  const NumerologyResult({
    required this.value,
    required this.title,
    required this.description,
    required this.systemTitle,
    required this.disclaimer,
    this.ruleKey = '',
    this.ruleVersion = '',
    this.calculation = '',
    this.status = 'unverified',
    this.sourceTitle = 'بدون منبع',
    this.isAvailable = true,
  });

  final int value;
  final String title;
  final String description;
  final String systemTitle;
  final String disclaimer;
  final String ruleKey;
  final String ruleVersion;
  final String calculation;
  final String status;
  final String sourceTitle;
  final bool isAvailable;
}
