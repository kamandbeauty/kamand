import 'abjad_result.dart';

class JafrResult {
  const JafrResult({
    required this.systemTitle,
    required this.ruleKey,
    required this.ruleVersion,
    required this.steps,
    required this.total,
    required this.reducedValue,
    required this.unknownLetters,
    required this.formula,
    required this.description,
    required this.disclaimer,
    required this.status,
    required this.sourceTitle,
    required this.calculation,
    required this.isAvailable,
  });

  final String systemTitle;
  final String ruleKey;
  final String ruleVersion;
  final List<AbjadStep> steps;
  final int total;
  final int reducedValue;
  final List<String> unknownLetters;
  final String formula;
  final String description;
  final String disclaimer;
  final String status;
  final String sourceTitle;
  final String calculation;
  final bool isAvailable;

  bool get isComplete => unknownLetters.isEmpty;
}
