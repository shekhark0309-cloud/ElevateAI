class CampusResource {
  final String id;
  final String? collegeId;
  final String resourceType;
  final String name;
  final int capacity;
  final bool isAvailable;
  final DateTime? availableFrom;
  final DateTime? availableUntil;
  final String? locationLabel;

  CampusResource({
    required this.id,
    this.collegeId,
    required this.resourceType,
    required this.name,
    this.capacity = 1,
    this.isAvailable = true,
    this.availableFrom,
    this.availableUntil,
    this.locationLabel,
  });

  factory CampusResource.fromJson(Map<String, dynamic> json) {
    return CampusResource(
      id: json['id'] as String,
      collegeId: json['college_id'] as String?,
      resourceType: json['resource_type'] as String,
      name: json['name'] as String,
      capacity: json['capacity'] as int? ?? 1,
      isAvailable: json['is_available'] as bool? ?? true,
      availableFrom: json['available_from'] != null ? DateTime.parse(json['available_from'] as String) : null,
      availableUntil: json['available_until'] != null ? DateTime.parse(json['available_until'] as String) : null,
      locationLabel: json['location_label'] as String?,
    );
  }
}

class ResourceBooking {
  final String id;
  final String studentId;
  final String resourceId;
  final DateTime bookedFrom;
  final DateTime bookedUntil;
  final String status;

  ResourceBooking({
    required this.id,
    required this.studentId,
    required this.resourceId,
    required this.bookedFrom,
    required this.bookedUntil,
    this.status = 'active',
  });

  factory ResourceBooking.fromJson(Map<String, dynamic> json) {
    return ResourceBooking(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      resourceId: json['resource_id'] as String,
      bookedFrom: DateTime.parse(json['booked_from'] as String),
      bookedUntil: DateTime.parse(json['booked_until'] as String),
      status: json['status'] as String? ?? 'active',
    );
  }
}

class MealPreference {
  final String studentId;
  final bool optInBreakfast;
  final bool optInLunch;
  final bool optInDinner;
  final List<DateTime> optOutDates;

  MealPreference({
    required this.studentId,
    this.optInBreakfast = true,
    this.optInLunch = true,
    this.optInDinner = true,
    this.optOutDates = const [],
  });

  factory MealPreference.fromJson(Map<String, dynamic> json) {
    return MealPreference(
      studentId: json['student_id'] as String,
      optInBreakfast: json['opt_in_breakfast'] as bool? ?? true,
      optInLunch: json['opt_in_lunch'] as bool? ?? true,
      optInDinner: json['opt_in_dinner'] as bool? ?? true,
      optOutDates: (json['opt_out_dates'] as List?)?.map((d) => DateTime.parse(d as String)).toList() ?? [],
    );
  }
}
