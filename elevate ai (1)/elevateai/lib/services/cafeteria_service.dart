import 'package:supabase_flutter/supabase_flutter.dart';

class CafeteriaService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getSustainabilityImpact(String studentId) async {
    final result = await _supabase.rpc('get_student_sustainability_impact', params: {
      'p_student_id': studentId,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  Future<void> updateMealPreferences({
    required String studentId,
    required bool optInBreakfast,
    required bool optInLunch,
    required bool optInDinner,
    required List<String> optOutDates,
  }) async {
    await _supabase.from('meal_preferences').upsert({
      'student_id': studentId,
      'opt_in_breakfast': optInBreakfast,
      'opt_in_lunch': optInLunch,
      'opt_in_dinner': optInDinner,
      'opt_out_dates': optOutDates,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> getMealPreferences(String studentId) async {
    final data = await _supabase
        .from('meal_preferences')
        .select()
        .eq('student_id', studentId)
        .maybeSingle();
    return Map<String, dynamic>.from(data ?? {});
  }
}
