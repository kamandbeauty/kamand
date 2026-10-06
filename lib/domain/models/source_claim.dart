class SourceClaim {
  const SourceClaim({
    required this.id,
    required this.claimType,
    required this.claimText,
    required this.status,
    required this.confidence,
    required this.evidenceNote,
    required this.sourceTitle,
    required this.sourceUrl,
  });

  final String id;
  final String claimType;
  final String claimText;
  final String status;
  final String confidence;
  final String evidenceNote;
  final String sourceTitle;
  final String sourceUrl;

  factory SourceClaim.fromMap(Map<String, Object?> map) {
    return SourceClaim(
      id: map['id'] as String,
      claimType: map['claim_type'] as String? ?? 'unknown',
      claimText: map['claim_text'] as String? ?? '',
      status: map['status'] as String? ?? 'unverified',
      confidence: map['confidence'] as String? ?? 'low',
      evidenceNote: map['evidence_note'] as String? ?? '',
      sourceTitle: map['source_title'] as String? ?? 'بدون منبع',
      sourceUrl: map['source_url'] as String? ?? '',
    );
  }
}
