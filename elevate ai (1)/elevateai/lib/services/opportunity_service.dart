import 'package:supabase_flutter/supabase_flutter.dart';

class OpportunityService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getRankedOpportunities({
    required String studentId,
    List<String>? typeFilter,
    int limit = 20,
  }) async {
    final response = await _supabase.functions.invoke(
      'rank-opportunities',
      body: {
        'student_id': studentId,
        if (typeFilter != null) 'type_filter': typeFilter,
        'limit': limit,
      },
    );

    if (response.status != 200) {
      throw Exception('Opportunity ranking failed');
    }
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> applyToOpportunity({
    required String opportunityId,
    String? coverNote,
    String? resumeUrl,
    Map<String, dynamic>? answers,
  }) async {
    final result = await _supabase.rpc('apply_to_opportunity', params: {
      'p_opportunity_id': opportunityId,
      'p_cover_note': coverNote,
      'p_resume_url': resumeUrl,
      'p_answers': answers ?? {},
    });

    return Map<String, dynamic>.from(result as Map);
  }

  Future<List<Map<String, dynamic>>> getMyApplications(String studentId) async {
    final data = await _supabase
        .from('opportunity_applications')
        .select('''
          id, status, submitted_at, cover_note,
          opportunities (
            title, type, organizer_name, apply_deadline,
            banner_url, apply_url, prize_amount
          )
        ''')
        .eq('student_id', studentId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<Map<String, dynamic>> scanForScam({
    required String title,
    String? description,
    String? url,
    String? organizer,
    int? prizeAmount,
  }) async {
    final response = await _supabase.functions.invoke(
      'scam-detect',
      body: {
        'title': title,
        if (description != null) 'description': description,
        if (url != null) 'url': url,
        if (organizer != null) 'organizer': organizer,
        if (prizeAmount != null) 'prize_amount': prizeAmount,
      },
    );

    if (response.status != 200) {
      throw Exception('Scam detection failed');
    }
    return response.data['data'] as Map<String, dynamic>;
  }
}
