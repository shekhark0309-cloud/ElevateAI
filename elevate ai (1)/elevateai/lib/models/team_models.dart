class Team {
  final String id;
  final String name;
  final String? tagline;
  final String leaderId;
  final String? collegeId;
  final String? opportunityId;
  final List<String> requiredSkills;
  final List<String> requiredArchetypes;
  final int maxMembers;
  final bool isOpen;
  final String status;
  final DateTime createdAt;
  final List<TeamMember>? members; // Joined data

  Team({
    required this.id,
    required this.name,
    this.tagline,
    required this.leaderId,
    this.collegeId,
    this.opportunityId,
    this.requiredSkills = const [],
    this.requiredArchetypes = const [],
    this.maxMembers = 5,
    this.isOpen = true,
    this.status = 'forming',
    required this.createdAt,
    this.members,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'] as String,
      name: json['name'] as String,
      tagline: json['tagline'] as String?,
      leaderId: json['leader_id'] as String,
      collegeId: json['college_id'] as String?,
      opportunityId: json['opportunity_id'] as String?,
      requiredSkills: List<String>.from(json['required_skills'] ?? []),
      requiredArchetypes: List<String>.from(json['required_archetypes'] ?? []),
      maxMembers: json['max_members'] as int? ?? 5,
      isOpen: json['is_open'] as bool? ?? true,
      status: json['status'] as String? ?? 'forming',
      createdAt: DateTime.parse(json['created_at'] as String),
      members: json['team_members'] != null
          ? (json['team_members'] as List).map((m) => TeamMember.fromJson(m)).toList()
          : null,
    );
  }
}

class TeamMember {
  final String id;
  final String teamId;
  final String studentId;
  final String role;
  final String status;
  final DateTime? joinedAt;
  final String? invitedBy;
  final DateTime? leftAt;
  final String? studentName; // Joined data
  final String? studentAvatarUrl; // Joined data

  TeamMember({
    required this.id,
    required this.teamId,
    required this.studentId,
    this.role = 'member',
    this.status = 'invited',
    this.joinedAt,
    this.invitedBy,
    this.leftAt,
    this.studentName,
    this.studentAvatarUrl,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) {
    return TeamMember(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      studentId: json['student_id'] as String,
      role: json['role'] as String? ?? 'member',
      status: json['status'] as String? ?? 'invited',
      joinedAt: json['joined_at'] != null ? DateTime.parse(json['joined_at'] as String) : null,
      invitedBy: json['invited_by'] as String?,
      leftAt: json['left_at'] != null ? DateTime.parse(json['left_at'] as String) : null,
      studentName: json['student_profiles'] != null ? json['student_profiles']['full_name'] : null,
      studentAvatarUrl: json['student_profiles'] != null ? json['student_profiles']['avatar_url'] : null,
    );
  }
}

class TeamEvent {
  final String id;
  final String teamId;
  final String? opportunityId;
  final String eventName;
  final DateTime endedAt;
  final DateTime debriefDeadline;
  final bool debriefCompleted;

  TeamEvent({
    required this.id,
    required this.teamId,
    this.opportunityId,
    required this.eventName,
    required this.endedAt,
    required this.debriefDeadline,
    this.debriefCompleted = false,
  });

  factory TeamEvent.fromJson(Map<String, dynamic> json) {
    return TeamEvent(
      id: json['id'] as String,
      teamId: json['team_id'] as String,
      opportunityId: json['opportunity_id'] as String?,
      eventName: json['event_name'] as String,
      endedAt: DateTime.parse(json['ended_at'] as String),
      debriefDeadline: DateTime.parse(json['debrief_deadline'] as String),
      debriefCompleted: json['debrief_completed'] as bool? ?? false,
    );
  }
}
