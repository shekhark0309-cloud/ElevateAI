import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/campus_models.dart';
import '../models/profile_models.dart';

class CampusService {
  final _supabase = Supabase.instance.client;

  Future<List<CampusResource>> getCampusResources(String collegeId) async {
    final response = await _supabase
        .from('campus_resources')
        .select()
        .eq('college_id', collegeId);

    return (response as List).map((json) => CampusResource.fromJson(json)).toList();
  }

  Future<List<StudentProfile>> getStudyBuddies({
    required String collegeId,
    String? subject,
    String? availability,
  }) async {
    var query = _supabase
        .from('student_profiles')
        .select()
        .eq('college_id', collegeId)
        .eq('is_study_buddy_mode', true)
        .neq('id', _supabase.auth.currentUser?.id ?? '');

    if (subject != null && subject != 'Other') {
      query = query.eq('current_study_subject', subject);
    }

    if (availability != null) {
      query = query.eq('availability_status', availability);
    }

    final response = await query;
    return (response as List).map((json) => StudentProfile.fromJson(json)).toList();
  }

  Future<void> updateStudyBuddyMode({
    required bool enabled,
    String? subject,
    String? availability,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('student_profiles').update({
      'is_study_buddy_mode': enabled,
      if (subject != null) 'current_study_subject': subject,
      if (availability != null) 'availability_status': availability,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  Future<List<ResourceBooking>> getMyBookings(String studentId) async {
    final response = await _supabase
        .from('resource_bookings')
        .select()
        .eq('student_id', studentId);

    return (response as List).map((json) => ResourceBooking.fromJson(json)).toList();
  }

  Future<void> bookResource({
    required String studentId,
    required String resourceId,
    required DateTime from,
    required DateTime until,
  }) async {
    await _supabase.from('resource_bookings').insert({
      'student_id': studentId,
      'resource_id': resourceId,
      'booked_from': from.toIso8601String(),
      'booked_until': until.toIso8601String(),
    });
  }

  Future<MealPreference?> getMealPreference(String studentId) async {
    final response = await _supabase
        .from('meal_preferences')
        .select()
        .eq('student_id', studentId)
        .maybeSingle();

    if (response == null) return null;
    return MealPreference.fromJson(response);
  }

  Future<void> updateMealPreference(MealPreference pref) async {
    await _supabase.from('meal_preferences').upsert({
      'student_id': pref.studentId,
      'opt_in_breakfast': pref.optInBreakfast,
      'opt_in_lunch': pref.optInLunch,
      'opt_in_dinner': pref.optInDinner,
      'opt_out_dates': pref.optOutDates.map((d) => d.toIso8601String().split('T')[0]).toList(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
