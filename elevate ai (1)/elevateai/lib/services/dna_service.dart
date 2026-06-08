import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dna_models.dart';

class DNAService {
  final _supabase = Supabase.instance.client;

  Future<StudentDNA> recalculateDNA(String studentId) async {
    final response = await _supabase.functions.invoke(
      'recalculate-dna',
      body: {'student_id': studentId},
    );

    if (response.status != 200) {
      throw Exception('DNA recalculation failed');
    }

    return StudentDNA.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Map<String, String>> getArchetype(String studentId) async {
    final response = await _supabase
        .from('student_dna')
        .select('archetype, ai_summary')
        .eq('student_id', studentId)
        .single();

    return {
      'archetype': response['archetype'] as String,
      'description': response['ai_summary'] as String? ?? 'Your behavioral profile.'
    };
  }

  Future<List<DNASnapshot>> getDNAHistory(String studentId) async {
    // Assuming a history view or table exists, or using versioning in student_dna
    final response = await _supabase
        .from('student_dna')
        .select('archetype, updated_at')
        .eq('student_id', studentId)
        .order('updated_at', ascending: false);

    return (response as List).map((json) => DNASnapshot.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> getPlacementScore(String studentId) async {
    final result = await _supabase.rpc('calculate_placement_score', params: {
      'p_student_id': studentId,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> getCareerGaps(String studentId) async {
    final response = await _supabase.functions.invoke(
      'get-career-gaps',
      body: {'student_id': studentId},
    );
    if (response.status != 200) throw Exception('Career gap analysis failed');
    return response.data['data'] as Map<String, dynamic>;
  }
}
