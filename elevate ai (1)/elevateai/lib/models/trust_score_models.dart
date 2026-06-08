class TrustScore {
  final double overallScore;
  final String tier;
  final double reliability;
  final double collaboration;
  final double integrity;
  final double skillValidation;
  final double community;
  final double academicReliability;
  final double academicConsistency;
  final DateTime? erpSyncedAt;

  // Aliases for UI consistency if needed
  double get credibility => community;
  double get social => collaboration;
  double get competency => skillValidation;

  TrustScore({
    required this.overallScore,
    required this.tier,
    required this.reliability,
    required this.collaboration,
    required this.integrity,
    required this.skillValidation,
    required this.community,
    this.academicReliability = 0.0,
    this.academicConsistency = 0.0,
    this.erpSyncedAt,
  });

  factory TrustScore.fromJson(Map<String, dynamic> json) {
    return TrustScore(
      overallScore: (json['overall_score'] as num?)?.toDouble() ?? 0.0,
      tier: json['tier'] as String? ?? 'Unverified',
      reliability: (json['reliability_score'] ?? 0.0 as num).toDouble(),
      collaboration: (json['collaboration_score'] ?? 0.0 as num).toDouble(),
      integrity: (json['integrity_score'] ?? 0.0 as num).toDouble(),
      skillValidation: (json['skill_validation_score'] ?? 0.0 as num).toDouble(),
      community: (json['community_score'] ?? 0.0 as num).toDouble(),
      academicReliability: (json['academic_reliability_score'] as num?)?.toDouble() ?? 0.0,
      academicConsistency: (json['academic_consistency_score'] as num?)?.toDouble() ?? 0.0,
      erpSyncedAt: json['erp_synced_at'] != null ? DateTime.parse(json['erp_synced_at'] as String) : null,
    );
  }
}

class TrustScoreEvent {
  final String id;
  final String eventType;
  final String dimension;
  final double delta;
  final String reasonKey;
  final DateTime createdAt;
  final String? explanation;

  TrustScoreEvent({
    required this.id,
    required this.eventType,
    required this.dimension,
    required this.delta,
    required this.reasonKey,
    required this.createdAt,
    this.explanation,
  });

  factory TrustScoreEvent.fromJson(Map<String, dynamic> json) {
    return TrustScoreEvent(
      id: json['id'] as String,
      eventType: json['event_type'] as String,
      dimension: json['dimension'] as String,
      delta: (json['delta'] as num).toDouble(),
      reasonKey: json['reason_key'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      explanation: json['explanation'] as String?,
    );
  }
}

class TrustScoreBreakdown {
  final Map<String, String> explanations;

  TrustScoreBreakdown({required this.explanations});
}
