import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trust_score_models.dart';

class TrustScoreService {
  final _supabase = Supabase.instance.client;

  Future<TrustScore> getMyScore(String studentId) async {
    final response = await _supabase
        .from('trust_scores')
        .select()
        .eq('student_id', studentId)
        .single();

    return TrustScore.fromJson(response);
  }

  Future<List<TrustScoreEvent>> getScoreHistory(String studentId, {int days = 30}) async {
    final threshold = DateTime.now().subtract(Duration(days: days)).toIso8601String();

    final response = await _supabase
        .from('trust_score_events')
        .select()
        .eq('student_id', studentId)
        .gte('created_at', threshold)
        .order('created_at', ascending: false);

    final events = (response as List).map((json) => TrustScoreEvent.fromJson(json)).toList();

    // Enhancing with AI explanations if possible
    // In a real app, you might do this in one query or batch call
    return events;
  }

  Future<TrustScoreBreakdown> getScoreBreakdown(String studentId) async {
    // Calling the Edge function for human-readable explanations
    final response = await _supabase.functions.invoke('explain-trust-event', body: {
      'student_id': studentId,
      'action': 'get_full_breakdown'
    });

    if (response.status != 200) {
      return TrustScoreBreakdown(explanations: {
        'credibility': 'Your academic and certification record.',
        'reliability': 'Your attendance and task completion rate.',
        'social': 'Your peer ratings and collaboration history.',
        'competency': 'Your validated skills and project outcomes.',
        'integrity': 'Your adherence to campus rules and ethics.',
      });
    }

    final data = response.data as Map<String, dynamic>;
    return TrustScoreBreakdown(explanations: Map<String, String>.from(data['explanations']));
  }

  Future<List<Map<String, dynamic>>> getLeaderboard({
    String? collegeId,
    int limit = 50,
  }) async {
    var query = _supabase
        .from('mv_trust_leaderboard')
        .select('full_name, overall_score, tier, archetype, rank_overall, rank_college, college_short_name');

    if (collegeId != null) {
      query = query.eq('college_id', collegeId);
    }

    final data = await query
        .order('rank_overall', ascending: true)
        .limit(limit);

    return List<Map<String, dynamic>>.from(data as List);
  }

  Map<String, dynamic> analyzeReliability(double trustScore, double skillScore) {
    if (skillScore > 85 && trustScore < 50) {
      return {
        'status': 'Reliability Risk',
        'explanation': 'Highly skilled but shows inconsistency in commitments or peer collaboration.',
        'is_warning': true,
        'color': 'red',
      };
    }
    if (skillScore > 80 && trustScore > 80) {
      return {
        'status': 'Elite Contributor',
        'explanation': 'Exceptional skills combined with a proven track record of reliability.',
        'is_warning': false,
        'color': 'green',
      };
    }
    if (trustScore > 90) {
      return {
        'status': 'Highly Trusted',
        'explanation': 'Top-tier reliability and integrity as validated by college records and peers.',
        'is_warning': false,
        'color': 'blue',
      };
    }
    if (trustScore < 40) {
      return {
        'status': 'Reliability Improvement Needed',
        'explanation': 'Needs to build a more consistent record of task completion and participation.',
        'is_warning': true,
        'color': 'orange',
      };
    }
    return {
      'status': 'Standard Reliability',
      'explanation': 'Reliable team member with a balanced collaboration history.',
      'is_warning': false,
      'color': 'grey',
    };
  }
}
