import '../../core/normalization/persian_normalizer.dart';
import '../models/abjad_result.dart';

class AbjadEngine {
  const AbjadEngine({
    required this.mapping,
    required this.sourceNote,
    this.systemKey = 'kabir',
    this.systemTitle = 'ابجد کبیر',
  });

  final Map<String, int> mapping;
  final String sourceNote;
  final String systemKey;
  final String systemTitle;

  AbjadResult calculate(String input) {
    final normalized = PersianNormalizer.normalize(input);
    final steps = <AbjadStep>[];
    final unknown = <String>[];
    var total = 0;

    for (final rune in normalized.runes) {
      final letter = String.fromCharCode(rune);
      if (letter.trim().isEmpty) continue;
      final value = mapping[letter];
      steps.add(AbjadStep(letter: letter, normalizedLetter: letter, value: value));
      if (value == null) {
        if (!unknown.contains(letter)) unknown.add(letter);
      } else {
        total += value;
      }
    }

    return AbjadResult(
      systemKey: systemKey,
      systemTitle: systemTitle,
      steps: steps,
      total: total,
      unknownLetters: unknown,
      sourceNote: sourceNote,
    );
  }
}
