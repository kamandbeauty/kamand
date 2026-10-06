class AbjadStep {
  const AbjadStep({
    required this.letter,
    required this.normalizedLetter,
    required this.value,
  });

  final String letter;
  final String normalizedLetter;
  final int? value;
}

class AbjadResult {
  const AbjadResult({
    required this.systemKey,
    required this.systemTitle,
    required this.steps,
    required this.total,
    required this.unknownLetters,
    required this.sourceNote,
  });

  final String systemKey;
  final String systemTitle;
  final List<AbjadStep> steps;
  final int total;
  final List<String> unknownLetters;
  final String sourceNote;

  bool get isComplete => unknownLetters.isEmpty;
}
