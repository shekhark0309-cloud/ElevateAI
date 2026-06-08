class ProjectIdea {
  final String id;
  final String? creatorId;
  final String title;
  final String? description;
  final List<String> requiredSkills;
  final String stage;
  final List<String> collaborators;
  final DateTime createdAt;

  ProjectIdea({
    required this.id,
    this.creatorId,
    required this.title,
    this.description,
    this.requiredSkills = const [],
    this.stage = 'idea',
    this.collaborators = const [],
    required this.createdAt,
  });

  factory ProjectIdea.fromJson(Map<String, dynamic> json) {
    return ProjectIdea(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      requiredSkills: List<String>.from(json['required_skills'] ?? []),
      stage: json['stage'] as String? ?? 'idea',
      collaborators: List<String>.from(json['collaborators'] ?? []),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class CampusConnection {
  final String id;
  final String? studentAId;
  final String? studentBId;
  final String connectionType;
  final String? subject;
  final String status;
  final DateTime createdAt;

  CampusConnection({
    required this.id,
    this.studentAId,
    this.studentBId,
    required this.connectionType,
    this.subject,
    this.status = 'pending',
    required this.createdAt,
  });

  factory CampusConnection.fromJson(Map<String, dynamic> json) {
    return CampusConnection(
      id: json['id'] as String,
      studentAId: json['student_a_id'] as String?,
      studentBId: json['student_b_id'] as String?,
      connectionType: json['connection_type'] as String,
      subject: json['subject'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ScamReport {
  final String id;
  final String? reportedBy;
  final String? opportunityId;
  final String category;
  final String status;
  final String? title;
  final String? description;
  final List<String> evidenceUrls;
  final DateTime createdAt;

  ScamReport({
    required this.id,
    this.reportedBy,
    this.opportunityId,
    required this.category,
    this.status = 'pending',
    this.title,
    this.description,
    this.evidenceUrls = const [],
    required this.createdAt,
  });

  factory ScamReport.fromJson(Map<String, dynamic> json) {
    return ScamReport(
      id: json['id'] as String,
      reportedBy: json['reported_by'] as String?,
      opportunityId: json['opportunity_id'] as String?,
      category: json['category'] as String,
      status: json['status'] as String? ?? 'pending',
      title: json['title'] as String?,
      description: json['description'] as String?,
      evidenceUrls: List<String>.from(json['evidence_urls'] ?? []),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class NotificationModel {
  final String id;
  final String studentId;
  final String type;
  final String title;
  final String? body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;
  final bool isBatched;

  NotificationModel({
    required this.id,
    required this.studentId,
    required this.type,
    required this.title,
    this.body,
    this.data = const {},
    this.isRead = false,
    required this.createdAt,
    this.isBatched = false,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      data: json['data'] as Map<String, dynamic>? ?? {},
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      isBatched: json['is_batched'] as bool? ?? false,
    );
  }
}
