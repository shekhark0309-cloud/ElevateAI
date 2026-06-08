import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/idea_models.dart';

class InnovationService {
  final _supabase = Supabase.instance.client;

  Future<List<ProjectIdea>> getDiscoveryFeed({
    String? category,
    String? sortBy = 'newest',
    int limit = 20,
  }) async {
    var query = _supabase.from('project_ideas').select();

    if (category != null && category != 'All') {
      query = query.eq('category', category);
    }

    if (sortBy == 'newest') {
      query = query.order('created_at', ascending: false);
    } else if (sortBy == 'trending') {
       // Simple trending: most collaborators + newest
       query = query.order('created_at', ascending: false);
    }

    final response = await query.limit(limit);
    return (response as List).map((json) => ProjectIdea.fromJson(json)).toList();
  }

  Future<List<ProjectIdea>> getRecommendedIdeas(String studentId) async {
    // Reusing logic: Calling Edge Function 'match-ideas' (to be implemented)
    // For now, fetching ideas that match student skills from DNA
    final dna = await _supabase.from('student_dna').select('top_skills').eq('student_id', studentId).single();
    final List<String> skills = List<String>.from(dna['top_skills'] ?? []);

    if (skills.isEmpty) return getDiscoveryFeed(limit: 5);

    final response = await _supabase
        .from('project_ideas')
        .select()
        .contains('required_skills', skills)
        .limit(10);

    return (response as List).map((json) => ProjectIdea.fromJson(json)).toList();
  }

  Future<Map<String, dynamic>> validateIdea({
    required String title,
    required String description,
    String? problemStatement,
    String? solution,
  }) async {
    final response = await _supabase.functions.invoke(
      'analyze-idea',
      body: {
        'title': title,
        'description': description,
        'problem_statement': problemStatement,
        'solution': solution,
      },
    );

    if (response.status != 200) {
      throw Exception('Idea analysis failed');
    }
    return response.data as Map<String, dynamic>;
  }

  Future<ProjectIdea> createIdea(ProjectIdea idea) async {
    final response = await _supabase
        .from('project_ideas')
        .insert(idea.toJson())
        .select()
        .single();
    return ProjectIdea.fromJson(response);
  }

  Future<void> joinIdea(String ideaId, String studentId) async {
    await _supabase.rpc('join_project_idea', params: {
      'p_idea_id': ideaId,
      'p_student_id': studentId,
    });
  }

  Future<List<Map<String, dynamic>>> getOpenRoles(String ideaId) async {
    final response = await _supabase
        .from('role_postings')
        .select()
        .eq('idea_id', ideaId)
        .eq('status', 'open');
    return List<Map<String, dynamic>>.from(response as List);
  }

  RealtimeChannel subscribeToIdea(String ideaId, Function(ProjectIdea) onUpdate) {
    return _supabase
        .channel('idea-$ideaId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'project_ideas',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: ideaId,
          ),
          callback: (payload) => onUpdate(ProjectIdea.fromJson(payload.newRecord)),
        )
        .subscribe();
  }
}
