import 'package:supabase_flutter/supabase_flutter.dart';

class SkillsService {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getStudentSkills(String studentId) async {
    final res = await _supabase
        .from('student_skills')
        .select()
        .eq('student_id', studentId)
        .order('skill_name');
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<void> upsertSkill({
    required String studentId,
    required String skillName,
    required int proficiency,
    String source = 'self',
  }) async {
    await _supabase.from('student_skills').upsert({
      'student_id': studentId,
      'skill_name': skillName,
      'proficiency': proficiency,
      'source': source,
      'is_verified': false,
    }, onConflict: 'student_id,skill_name');
  }

  Future<Map<String, dynamic>> awardBadge({
    required String studentId,
    required String badgeId,
    String? evidenceUrl,
    bool autoVerify = false,
  }) async {
    final result = await _supabase.rpc('award_badge', params: {
      'p_student_id': studentId,
      'p_badge_id': badgeId,
      'p_evidence_url': evidenceUrl,
      'p_evidence_meta': {},
      'p_auto_verify': autoVerify,
    });

    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> verifyBadgeByPeer({
    required String studentBadgeId,
    required bool approved,
    String? note,
  }) async {
    final result = await _supabase.rpc('verify_badge_by_peer', params: {
      'p_student_badge_id': studentBadgeId,
      'p_verdict': approved ? 'verified' : 'rejected',
      'p_note': note,
    });

    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> generatePortfolio() async {
    final response = await _supabase.functions.invoke(
      'generate-portfolio',
      body: {'format': 'json'},
    );
    if (response.status != 200) {
      throw Exception('Portfolio generation failed');
    }
    return response.data as Map<String, dynamic>;
  }
}
