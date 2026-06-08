class SkillBadge {
  final String id;
  final String name;
  final String slug;
  final String category;
  final int level;
  final int xpValue;
  final String? iconUrl;
  final String? description;
  final bool isActive;

  SkillBadge({
    required this.id,
    required this.name,
    required this.slug,
    required this.category,
    this.level = 1,
    this.xpValue = 100,
    this.iconUrl,
    this.description,
    this.isActive = true,
  });

  factory SkillBadge.fromJson(Map<String, dynamic> json) {
    return SkillBadge(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      category: json['category'] as String,
      level: json['level'] as int? ?? 1,
      xpValue: json['xp_value'] as int? ?? 100,
      iconUrl: json['icon_url'] as String?,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class StudentBadge {
  final String id;
  final String studentId;
  final String badgeId;
  final String verifyStatus;
  final String? evidenceUrl;
  final Map<String, dynamic> evidenceMeta;
  final DateTime earnedAt;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final SkillBadge? badge; // Joined data

  StudentBadge({
    required this.id,
    required this.studentId,
    required this.badgeId,
    this.verifyStatus = 'pending',
    this.evidenceUrl,
    this.evidenceMeta = const {},
    required this.earnedAt,
    this.verifiedAt,
    this.verifiedBy,
    this.badge,
  });

  factory StudentBadge.fromJson(Map<String, dynamic> json) {
    return StudentBadge(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      badgeId: json['badge_id'] as String,
      verifyStatus: json['verify_status'] as String? ?? 'pending',
      evidenceUrl: json['evidence_url'] as String?,
      evidenceMeta: json['evidence_meta'] as Map<String, dynamic>? ?? {},
      earnedAt: DateTime.parse(json['earned_at'] as String),
      verifiedAt: json['verified_at'] != null ? DateTime.parse(json['verified_at'] as String) : null,
      verifiedBy: json['verified_by'] as String?,
      badge: json['skill_badges'] != null ? SkillBadge.fromJson(json['skill_badges']) : null,
    );
  }
}

class StudentSkill {
  final String studentId;
  final String skillName;
  final int proficiency;
  final bool isVerified;
  final String? source;
  final DateTime updatedAt;

  StudentSkill({
    required this.studentId,
    required this.skillName,
    required this.proficiency,
    this.isVerified = false,
    this.source,
    required this.updatedAt,
  });

  factory StudentSkill.fromJson(Map<String, dynamic> json) {
    return StudentSkill(
      studentId: json['student_id'] as String,
      skillName: json['skill_name'] as String,
      proficiency: json['proficiency'] as int,
      isVerified: json['is_verified'] as bool? ?? false,
      source: json['source'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class SkillChallenge {
  final String id;
  final String? badgeId;
  final String title;
  final String problemStatement;
  final String? starterCode;
  final String? expectedOutput;
  final String challengeType;
  final String difficulty;
  final int timeLimitMinutes;
  final Map<String, dynamic> evaluationCriteria;

  SkillChallenge({
    required this.id,
    this.badgeId,
    required this.title,
    required this.problemStatement,
    this.starterCode,
    this.expectedOutput,
    this.challengeType = 'code_write',
    this.difficulty = 'beginner',
    this.timeLimitMinutes = 30,
    this.evaluationCriteria = const {},
  });

  factory SkillChallenge.fromJson(Map<String, dynamic> json) {
    return SkillChallenge(
      id: json['id'] as String,
      badgeId: json['badge_id'] as String?,
      title: json['title'] as String,
      problemStatement: json['problem_statement'] as String,
      starterCode: json['starter_code'] as String?,
      expectedOutput: json['expected_output'] as String?,
      challengeType: json['challenge_type'] as String? ?? 'code_write',
      difficulty: json['difficulty'] as String? ?? 'beginner',
      timeLimitMinutes: json['time_limit_minutes'] as int? ?? 30,
      evaluationCriteria: json['evaluation_criteria'] as Map<String, dynamic>? ?? {},
    );
  }
}
