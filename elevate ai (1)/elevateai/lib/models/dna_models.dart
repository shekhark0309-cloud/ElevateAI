class StudentDNA {
  final String id;
  final String archetype;
  final String description;
  final double confidence;
  final List<String> topSkills;
  final List<String> strengths;
  final List<String> growthAreas;
  final String? teamRoleHint;
  final List<String> goalsShortTerm;
  final List<String> goalsLongTerm;
  final List<String> targetRoles;
  final List<String> preferredIndustries;
  final Map<String, dynamic> availability;
  final bool prefersRemote;
  final String? teamSizePreference;
  final String? preferredStudyTime;
  final int studyStreak;
  final double focusScore;
  final double placementScore;
  final int? salaryRangeMin;
  final int? salaryRangeMax;
  final DateTime? careerReadinessAt;

  StudentDNA({
    required this.id,
    required this.archetype,
    required this.description,
    required this.confidence,
    required this.topSkills,
    required this.strengths,
    required this.growthAreas,
    this.teamRoleHint,
    this.goalsShortTerm = const [],
    this.goalsLongTerm = const [],
    this.targetRoles = const [],
    this.preferredIndustries = const [],
    this.availability = const {},
    this.prefersRemote = false,
    this.teamSizePreference,
    this.preferredStudyTime,
    this.studyStreak = 0,
    this.focusScore = 0.0,
    this.placementScore = 0.0,
    this.salaryRangeMin,
    this.salaryRangeMax,
    this.careerReadinessAt,
  });

  factory StudentDNA.fromJson(Map<String, dynamic> json) {
    return StudentDNA(
      id: json['id'] as String,
      archetype: json['archetype'] as String,
      description: json['ai_summary'] ?? 'Your unique behavioral archetype.',
      confidence: (json['archetype_confidence'] as num?)?.toDouble() ?? 0.0,
      topSkills: List<String>.from(json['top_skills'] ?? []),
      strengths: List<String>.from(json['ai_strengths'] ?? []),
      growthAreas: List<String>.from(json['ai_growth_areas'] ?? []),
      teamRoleHint: json['ai_team_role_hint'] as String?,
      goalsShortTerm: List<String>.from(json['goals_short_term'] ?? []),
      goalsLongTerm: List<String>.from(json['goals_long_term'] ?? []),
      targetRoles: List<String>.from(json['target_roles'] ?? []),
      preferredIndustries: List<String>.from(json['preferred_industries'] ?? []),
      availability: json['availability'] as Map<String, dynamic>? ?? {},
      prefersRemote: json['prefers_remote'] as bool? ?? false,
      teamSizePreference: json['team_size_preference'] as String?,
      preferredStudyTime: json['preferred_study_time'] as String?,
      studyStreak: json['study_streak'] as int? ?? 0,
      focusScore: (json['focus_score'] as num?)?.toDouble() ?? 0.0,
      placementScore: (json['placement_score'] as num?)?.toDouble() ?? 0.0,
      salaryRangeMin: json['salary_range_min'] as int?,
      salaryRangeMax: json['salary_range_max'] as int?,
      careerReadinessAt: json['career_readiness_at'] != null
          ? DateTime.parse(json['career_readiness_at'] as String)
          : null,
    );
  }
}

class DNASnapshot {
  final String archetype;
  final DateTime recordedAt;

  DNASnapshot({required this.archetype, required this.recordedAt});

  factory DNASnapshot.fromJson(Map<String, dynamic> json) {
    return DNASnapshot(
      archetype: json['archetype'] as String,
      recordedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
