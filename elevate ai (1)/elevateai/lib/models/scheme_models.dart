class Scheme {
  final String id;
  final String name;
  final String description;
  final Map<String, dynamic> eligibilityCriteria;
  final int? amountMin;
  final int? amountMax;
  final DateTime? deadline;
  final String? category;
  final String? state;
  final String? sourceUrl;

  Scheme({
    required this.id,
    required this.name,
    required this.description,
    required this.eligibilityCriteria,
    this.amountMin,
    this.amountMax,
    this.deadline,
    this.category,
    this.state,
    this.sourceUrl,
  });

  factory Scheme.fromJson(Map<String, dynamic> json) {
    return Scheme(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      eligibilityCriteria: json['eligibility_criteria'] as Map<String, dynamic>,
      amountMin: json['amount_min'] as int?,
      amountMax: json['amount_max'] as int?,
      deadline: json['deadline'] != null ? DateTime.parse(json['deadline'] as String) : null,
      category: json['category'] as String?,
      state: json['state'] as String?,
      sourceUrl: json['source_url'] as String?,
    );
  }
}

class EligibilityResult {
  final bool eligible;
  final List<String> missingCriteria;

  EligibilityResult({required this.eligible, required this.missingCriteria});
}
