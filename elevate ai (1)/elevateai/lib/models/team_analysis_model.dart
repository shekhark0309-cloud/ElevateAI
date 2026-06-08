class TeamAnalysis {
  final int healthScore;
  final List<String> missingRoles;
  final String teamStrengthSummary;
  final List<String> riskIndicators;
  final Map<String, int> strengths;
  final int compatibilityScore;
  final String reasoning;
  final List<Map<String, dynamic>> suggestedMembers;

  TeamAnalysis({
    required this.healthScore,
    required this.missingRoles,
    required this.teamStrengthSummary,
    required this.riskIndicators,
    required this.strengths,
    required this.compatibilityScore,
    required this.reasoning,
    this.suggestedMembers = const [],
  });

  factory TeamAnalysis.fromJson(Map<String, dynamic> json) {
    return TeamAnalysis(
      healthScore: json['health_score'] ?? 0,
      missingRoles: List<String>.from(json['missing_roles'] ?? []),
      teamStrengthSummary: json['team_strength_summary'] ?? '',
      riskIndicators: List<String>.from(json['risk_indicators'] ?? []),
      strengths: Map<String, int>.from(json['strengths'] ?? {}),
      compatibilityScore: json['compatibility_score'] ?? 0,
      reasoning: json['reasoning'] ?? '',
      suggestedMembers: List<Map<String, dynamic>>.from(json['suggested_members'] ?? []),
    );
  }
}
