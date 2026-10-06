class CompatibilityResult {
  const CompatibilityResult({
    required this.score,
    required this.label,
    required this.method,
    required this.disclaimer,
  });

  final int? score;
  final String label;
  final String method;
  final String disclaimer;
}
