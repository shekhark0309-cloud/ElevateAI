class ProjectIdea {
  final String id;
  final String creatorId;
  final String title;
  final String? description;
  final String? problemStatement;
  final String? solution;
  final String? targetUsers;
  final List<String> requiredSkills;
  final String stage;
  final List<String> collaborators;
  final double? innovationScore;
  final double? feasibilityScore;
  final String? marketPotential;
  final String? technicalComplexity;
  final List<String> suggestedImprovements;
  final List<String> potentialRisks;
  final String? category;
  final List<String> tags;
  final DateTime createdAt;

  ProjectIdea({
    required this.id,
    required this.creatorId,
    required this.title,
    this.description,
    this.problemStatement,
    this.solution,
    this.targetUsers,
    this.requiredSkills = const [],
    this.stage = 'idea',
    this.collaborators = const [],
    this.innovationScore,
    this.feasibilityScore,
    this.marketPotential,
    this.technicalComplexity,
    this.suggestedImprovements = const [],
    this.potentialRisks = const [],
    this.category,
    this.tags = const [],
    required this.createdAt,
  });

  factory ProjectIdea.fromJson(Map<String, dynamic> json) {
    return ProjectIdea(
      id: json['id'] as String,
      creatorId: json['creator_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      problemStatement: json['problem_statement'] as String?,
      solution: json['solution'] as String?,
      targetUsers: json['target_users'] as String?,
      requiredSkills: List<String>.from(json['required_skills'] ?? []),
      stage: json['stage'] as String? ?? 'idea',
      collaborators: List<String>.from(json['collaborators'] ?? []),
      innovationScore: (json['innovation_score'] as num?)?.toDouble(),
      feasibilityScore: (json['feasibility_score'] as num?)?.toDouble(),
      marketPotential: json['market_potential'] as String?,
      technicalComplexity: json['technical_complexity'] as String?,
      suggestedImprovements: List<String>.from(json['suggested_improvements'] ?? []),
      potentialRisks: List<String>.from(json['potential_risks'] ?? []),
      category: json['category'] as String?,
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'creator_id': creatorId,
      'title': title,
      'description': description,
      'problem_statement': problemStatement,
      'solution': solution,
      'target_users': targetUsers,
      'required_skills': requiredSkills,
      'stage': stage,
      'collaborators': collaborators,
      'innovation_score': innovationScore,
      'feasibility_score': feasibilityScore,
      'market_potential': marketPotential,
      'technical_complexity': technicalComplexity,
      'suggested_improvements': suggestedImprovements,
      'potential_risks': potentialRisks,
      'category': category,
      'tags': tags,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
