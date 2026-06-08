import 'package:supabase_flutter/supabase_flutter.dart';
import 'nudge_service.dart';

class DashboardService {
  final _supabase = Supabase.instance.client;
  final _nudgeService = NudgeService();

  Future<Map<String, dynamic>> getDashboard(String studentId) async {
    final result = await _supabase.rpc('get_student_dashboard', params: {
      'p_student_id': studentId,
    });

    final data = Map<String, dynamic>.from(result as Map);

    // Add smart nudges to dashboard data
    final nudges = await _nudgeService.generateSmartNudges(studentId);
    data['smart_nudges'] = nudges;

    return data;
  }
}
