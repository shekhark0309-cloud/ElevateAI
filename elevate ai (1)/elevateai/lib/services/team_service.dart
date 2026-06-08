import 'package:supabase_flutter/supabase_flutter.dart';

class TeamService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getTeamMatches({
    required String studentId,
    Map<String, dynamic>? filters,
    int limit = 8,
  }) async {
    final response = await _supabase.functions.invoke(
      'match-teams',
      body: {
        'student_id': studentId,
        'filters': filters ?? {},
        'limit': limit,
      },
    );

    if (response.status != 200) {
      throw Exception('Team matching failed');
    }
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createTeam({
    required String name,
    String? tagline,
    List<String>? requiredSkills,
    List<String>? requiredArchetypes,
    int maxMembers = 5,
    bool isOpen = true,
    List<String>? initialMemberIds,
  }) async {
    final result = await _supabase.rpc('create_team_with_members', params: {
      'p_name': name,
      'p_tagline': tagline,
      'p_required_skills': requiredSkills ?? [],
      'p_required_archetypes': requiredArchetypes ?? [],
      'p_max_members': maxMembers,
      'p_is_open': isOpen,
      'p_initial_members': initialMemberIds ?? [],
    });

    return Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> acceptTeamInvite(String teamId) async {
    final result = await _supabase.rpc('accept_team_invite', params: {
      'p_team_id': teamId,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> getTeamMembers(String teamId) async {
    final data = await _supabase
        .from('team_members')
        .select('''
          student_id, role, status, joined_at,
          student_profiles (
            full_name, avatar_url, course, year_of_study,
            student_dna ( archetype, top_skills )
          ),
          trust_scores: student_profiles!inner (
            trust_scores ( overall_score, tier )
          )
        ''')
        .eq('team_id', teamId)
        .eq('status', 'active');

    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<Map<String, dynamic>> analyzeTeam(String teamId) async {
    final response = await _supabase.functions.invoke(
      'analyze-team',
      body: {'team_id': teamId},
    );

    if (response.status != 200) {
      throw Exception('Team analysis failed');
    }
    return response.data as Map<String, dynamic>;
  }

  RealtimeChannel subscribeToTeam({
    required String teamId,
    required Function(Map<String, dynamic>) onMemberChange,
  }) {
    return _supabase
        .channel('team-$teamId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'team_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'team_id',
            value: teamId,
          ),
          callback: (payload) => onMemberChange(payload.newRecord),
        )
        .subscribe();
  }
}
