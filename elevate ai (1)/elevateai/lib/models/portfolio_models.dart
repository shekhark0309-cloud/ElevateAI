class StudentProject {
  final String id;
  final String studentId;
  final String title;
  final String? description;
  final List<String> techStack;
  final String? role;
  final String? outcome;
  final String? githubUrl;
  final String? liveUrl;
  final bool isFeatured;
  final DateTime createdAt;

  StudentProject({
    required this.id,
    required this.studentId,
    required this.title,
    this.description,
    this.techStack = const [],
    this.role,
    this.outcome,
    this.githubUrl,
    this.liveUrl,
    this.isFeatured = false,
    required this.createdAt,
  });

  factory StudentProject.fromJson(Map<String, dynamic> json) {
    return StudentProject(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      techStack: List<String>.from(json['tech_stack'] ?? []),
      role: json['role'] as String?,
      outcome: json['outcome'] as String?,
      githubUrl: json['github_url'] as String?,
      liveUrl: json['live_url'] as String?,
      isFeatured: json['is_featured'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class StudentAchievement {
  final String id;
  final String studentId;
  final String title;
  final String? achievementType;
  final String? issuedBy;
  final DateTime? issuedAt;
  final String? credentialUrl;
  final bool isVerified;

  StudentAchievement({
    required this.id,
    required this.studentId,
    required this.title,
    this.achievementType,
    this.issuedBy,
    this.issuedAt,
    this.credentialUrl,
    this.isVerified = false,
  });

  factory StudentAchievement.fromJson(Map<String, dynamic> json) {
    return StudentAchievement(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      title: json['title'] as String,
      achievementType: json['achievement_type'] as String?,
      issuedBy: json['issued_by'] as String?,
      issuedAt: json['issued_at'] != null ? DateTime.parse(json['issued_at'] as String) : null,
      credentialUrl: json['credential_url'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }
}
