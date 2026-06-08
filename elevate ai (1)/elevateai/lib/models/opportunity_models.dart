class Opportunity {
  final String id;
  final String title;
  final String type;
  final String organizerName;
  final String? organizerId;
  final double? organizerTrustScore;
  final String? description;
  final double? prizeAmount;
  final double? stipendAmount;
  final DateTime applyDeadline;
  final DateTime? eventStart;
  final DateTime? eventEnd;
  final String? bannerUrl;
  final String? applyUrl;
  final List<String> requiredSkills;
  final List<String> eligibleStates;
  final List<String> eligibleCategories;
  final List<String> eligibleCourses;
  final int? minYear;
  final int? maxYear;
  final double? minCgpa;
  final double? maxFamilyIncome;
  final double minTrustScore;
  final bool isFeatured;
  final bool isVerified;
  final String status;
  final Map<String, dynamic> meta;
  final String? postedBy;

  Opportunity({
    required this.id,
    required this.title,
    required this.type,
    required this.organizerName,
    this.organizerId,
    this.organizerTrustScore,
    this.description,
    this.prizeAmount,
    this.stipendAmount,
    required this.applyDeadline,
    this.eventStart,
    this.eventEnd,
    this.bannerUrl,
    this.applyUrl,
    this.requiredSkills = const [],
    this.eligibleStates = const [],
    this.eligibleCategories = const [],
    this.eligibleCourses = const [],
    this.minYear,
    this.maxYear,
    this.minCgpa,
    this.maxFamilyIncome,
    this.minTrustScore = 0.0,
    this.isFeatured = false,
    this.isVerified = false,
    this.status = 'active',
    this.meta = const {},
    this.postedBy,
  });

  factory Opportunity.fromJson(Map<String, dynamic> json) {
    return Opportunity(
      id: json['id'] as String,
      title: json['title'] as String,
      type: json['type'] as String,
      organizerName: json['organizer_name'] as String,
      organizerId: json['organizer_id'] as String?,
      organizerTrustScore: (json['organizer_trust_score'] as num?)?.toDouble(),
      description: json['description'] as String?,
      prizeAmount: (json['prize_amount'] as num?)?.toDouble(),
      stipendAmount: (json['stipend_amount'] as num?)?.toDouble(),
      applyDeadline: DateTime.parse(json['apply_deadline'] as String),
      eventStart: json['event_start'] != null ? DateTime.parse(json['event_start'] as String) : null,
      eventEnd: json['event_end'] != null ? DateTime.parse(json['event_end'] as String) : null,
      bannerUrl: json['banner_url'] as String?,
      applyUrl: json['apply_url'] as String?,
      requiredSkills: List<String>.from(json['required_skills'] ?? []),
      eligibleStates: List<String>.from(json['eligible_states'] ?? []),
      eligibleCategories: List<String>.from(json['eligible_categories'] ?? []),
      eligibleCourses: List<String>.from(json['eligible_courses'] ?? []),
      minYear: json['min_year'] as int?,
      maxYear: json['max_year'] as int?,
      minCgpa: (json['min_cgpa'] as num?)?.toDouble(),
      maxFamilyIncome: (json['max_family_income'] as num?)?.toDouble(),
      minTrustScore: (json['min_trust_score'] as num?)?.toDouble() ?? 0.0,
      isFeatured: json['is_featured'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
      meta: json['meta'] as Map<String, dynamic>? ?? {},
      postedBy: json['posted_by'] as String?,
    );
  }
}

class OpportunityApplication {
  final String id;
  final String opportunityId;
  final String studentId;
  final String status;
  final String? coverNote;
  final String? resumeUrl;
  final Map<String, dynamic> answers;
  final DateTime? submittedAt;
  final Opportunity? opportunity; // Joined data

  OpportunityApplication({
    required this.id,
    required this.opportunityId,
    required this.studentId,
    this.status = 'draft',
    this.coverNote,
    this.resumeUrl,
    this.answers = const {},
    this.submittedAt,
    this.opportunity,
  });

  factory OpportunityApplication.fromJson(Map<String, dynamic> json) {
    return OpportunityApplication(
      id: json['id'] as String,
      opportunityId: json['opportunity_id'] as String,
      studentId: json['student_id'] as String,
      status: json['status'] as String? ?? 'draft',
      coverNote: json['cover_note'] as String?,
      resumeUrl: json['resume_url'] as String?,
      answers: json['answers'] as Map<String, dynamic>? ?? {},
      submittedAt: json['submitted_at'] != null ? DateTime.parse(json['submitted_at'] as String) : null,
      opportunity: json['opportunities'] != null ? Opportunity.fromJson(json['opportunities']) : null,
    );
  }
}
