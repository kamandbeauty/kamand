/// Deterministic hashing + PRNG used by every horoscope engine.
///
/// All algorithms here are pure integer math with identical semantics in
/// every port (Dart / TypeScript share the exact same vectors) so the
/// generated content is stable across platforms and releases.
library;

/// FNV-1a 32-bit hash of a UTF-8-ish string (rune-wise, ASCII seeds in
/// practice). Stable across platforms.
int fnv1a32(String input) {
  var hash = 0x811c9dc5;
  for (final rune in input.runes) {
    hash ^= rune;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// Linear congruential generator — deterministic, no dart:math Random.
class DetRandom {
  DetRandom(int seed)
      : _state = (seed == 0 ? 0x6d2b79f5 : (seed & 0xFFFFFFFF));

  int _state;

  /// Next raw uint32.
  int nextUint32() {
    _state = (1664525 * _state + 1013904223) & 0xFFFFFFFF;
    return _state;
  }

  /// Uniform in [0, max).
  int nextInt(int max) {
    assert(max > 0, 'max must be positive');
    return nextUint32() % max;
  }

  /// Deterministic pick from a list.
  T pick<T>(List<T> items) => items[nextUint32() % items.length];

  /// Deterministic pick, then remove from list (for without-replacement use).
  T take<T>(List<T> items) {
    final i = nextUint32() % items.length;
    return items.removeAt(i);
  }
}

/// Clamps [value] into [min, max].
int clampInt(int value, int min, int max) =>
    value < min ? min : (value > max ? max : value);

/// Known answer vectors shared with the TypeScript port of the engine
/// (see web_preview/src/engine) — cross-platform determinism contract.
const Map<String, int> kFnv1aVectors = {
  '': 0x811C9DC5,
  'aries': 0x346BCCB5,
  'scorpio|1405-7-14': 0xB07CA3E6,
  'scores|capricorn|1404-12-30': 0xB2633D4A,
  'week|pisces|1405-1-1': 0xDF11C720,
  'compat|aries|pisces': 0xA25B06AA,
  'lucky|leo|1405-10-5': 0x0624DF55,
  'month|taurus|1405-5': 0x46C45269,
};

/// First LCG outputs for seed 12345 (cross-platform contract).
const List<int> kLcgVectorSeed12345 = [
  0x05391C44,
  0x043C7AD3,
  0x8B0C4216,
  0xA289127D,
  0xE8F7B1B8,
];
