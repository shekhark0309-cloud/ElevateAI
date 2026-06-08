class College {
  final String id;
  final String name;
  final String shortName;
  final String? domain;
  final String? state;
  final bool isVerified;

  College({
    required this.id,
    required this.name,
    required this.shortName,
    this.domain,
    this.state,
    this.isVerified = false,
  });

  factory College.fromJson(Map<String, dynamic> json) {
    return College(
      id: json['id'] as String,
      name: json['name'] as String,
      shortName: json['short_name'] as String,
      domain: json['domain'] as String?,
      state: json['state'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }
}

class StudentProfile {
  final String id;
  final String? collegeId;
  final String fullName;
  final String email;
  final String? phone;
  final String? rollNumber;
  final String? course;
  final String? branch;
  final int? yearOfStudy;
  final int? graduationYear;
  final double? cgpa;
  final String? avatarUrl;
  final String? state;
  final String category;
  final double? familyIncome;
  final String? gender;
  final bool isActive;
  final String? currentStudySubject;
  final String? availabilityStatus;
  final bool isStudyBuddyMode;
  final double? latitude;
  final double? longitude;
  final List<String>? skills;
  final int? trustScore;
  final bool erpSynced;
  final int erpCreditsCompleted;
  final int erpBacklogs;
  final double erpCourseProgress;
  final List<double> erpSemesterGpa;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudentProfile({
    required this.id,
    this.collegeId,
    required this.fullName,
    required this.email,
    this.phone,
    this.rollNumber,
    this.course,
    this.branch,
    this.yearOfStudy,
    this.graduationYear,
    this.cgpa,
    this.avatarUrl,
    this.state,
    this.category = 'general',
    this.familyIncome,
    this.gender,
    this.isActive = true,
    this.currentStudySubject,
    this.availabilityStatus,
    this.isStudyBuddyMode = false,
    this.latitude,
    this.longitude,
    this.skills,
    this.trustScore,
    this.erpSynced = false,
    this.erpCreditsCompleted = 0,
    this.erpBacklogs = 0,
    this.erpCourseProgress = 0.0,
    this.erpSemesterGpa = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id'] as String,
      collegeId: json['college_id'] as String?,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      rollNumber: json['roll_number'] as String?,
      course: json['course'] as String?,
      branch: json['branch'] as String?,
      yearOfStudy: json['year_of_study'] as int?,
      graduationYear: json['graduation_year'] as int?,
      cgpa: (json['cgpa'] as num?)?.toDouble(),
      avatarUrl: json['avatar_url'] as String?,
      state: json['state'] as String?,
      category: json['category'] as String? ?? 'general',
      familyIncome: (json['family_income'] as num?)?.toDouble(),
      gender: json['gender'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      currentStudySubject: json['current_study_subject'] as String?,
      availabilityStatus: json['availability_status'] as String?,
      isStudyBuddyMode: json['is_study_buddy_mode'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      skills: (json['skills'] as List?)?.map((s) => s.toString()).toList(),
      trustScore: json['trust_score'] as int?,
      erpSynced: json['erp_synced'] as bool? ?? false,
      erpCreditsCompleted: json['erp_credits_completed'] as int? ?? 0,
      erpBacklogs: json['erp_backlogs'] as int? ?? 0,
      erpCourseProgress: (json['erp_course_progress'] as num?)?.toDouble() ?? 0.0,
      erpSemesterGpa: (json['erp_semester_gpa'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
