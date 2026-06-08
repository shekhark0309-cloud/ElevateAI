class RolePosting {
  final String id;
  final String? creatorId;
  final String? teamId;
  final String roleTitle;
  final List<String> requiredSkills;
  final String? description;
  final int commitmentWeeks;
  final String? domain;
  final String status;
  final DateTime createdAt;

  RolePosting({
    required this.id,
    this.creatorId,
    this.teamId,
    required this.roleTitle,
    required this.requiredSkills,
    this.description,
    this.commitmentWeeks = 3,
    this.domain,
    this.status = 'open',
    required this.createdAt,
  });

  factory RolePosting.fromJson(Map<String, dynamic> json) {
    return RolePosting(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String?,
      teamId: json['team_id'] as String?,
      roleTitle: json['role_title'] as String,
      requiredSkills: List<String>.from(json['required_skills'] ?? []),
      description: json['description'] as String?,
      commitmentWeeks: json['commitment_weeks'] as int? ?? 3,
      domain: json['domain'] as String?,
      status: json['status'] as String? ?? 'open',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class RoleApplication {
  final String id;
  final String postingId;
  final String applicantId;
  final String? message;
  final String status;
  final DateTime createdAt;

  RoleApplication({
    required this.id,
    required this.postingId,
    required this.applicantId,
    this.message,
    this.status = 'pending',
    required this.createdAt,
  });

  factory RoleApplication.fromJson(Map<String, dynamic> json) {
    return RoleApplication(
      id: json['id'] as String,
      postingId: json['posting_id'] as String,
      applicantId: json['applicant_id'] as String,
      message: json['message'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
