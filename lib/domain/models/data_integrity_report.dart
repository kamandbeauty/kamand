class DataIntegrityReport {
  const DataIntegrityReport({
    required this.nameCount,
    required this.sourceCount,
    required this.claimCount,
    required this.namesWithoutSource,
    required this.namesWithoutMeaning,
    required this.claimsWithoutSource,
    required this.claimsWithoutSubject,
    required this.orphanVariants,
    required this.orphanMeanings,
    required this.orphanEtymologies,
    required this.orphanPronunciations,
    required this.duplicateNormalizedNames,
  });

  final int nameCount;
  final int sourceCount;
  final int claimCount;
  final int namesWithoutSource;
  final int namesWithoutMeaning;
  final int claimsWithoutSource;
  final int claimsWithoutSubject;
  final int orphanVariants;
  final int orphanMeanings;
  final int orphanEtymologies;
  final int orphanPronunciations;
  final int duplicateNormalizedNames;

  bool get isHealthy =>
      namesWithoutSource == 0 &&
      claimsWithoutSource == 0 &&
      claimsWithoutSubject == 0 &&
      orphanVariants == 0 &&
      orphanMeanings == 0 &&
      orphanEtymologies == 0 &&
      orphanPronunciations == 0 &&
      duplicateNormalizedNames == 0;

  int get issueCount => [
        namesWithoutSource,
        namesWithoutMeaning,
        claimsWithoutSource,
        claimsWithoutSubject,
        orphanVariants,
        orphanMeanings,
        orphanEtymologies,
        orphanPronunciations,
        duplicateNormalizedNames,
      ].fold(0, (sum, value) => sum + value);
}
