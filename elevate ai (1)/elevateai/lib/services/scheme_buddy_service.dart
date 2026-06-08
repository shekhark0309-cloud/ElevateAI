import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/scheme_models.dart';

class SchemeBuddyService {
  final _supabase = Supabase.instance.client;
  final List<Map<String, String>> _conversationHistory = [];

  Future<List<Scheme>> searchSchemes(String query, {Map<String, dynamic>? filters}) async {
    var request = _supabase.from('schemes').select();

    if (query.isNotEmpty) {
      request = request.ilike('name', '%$query%');
    }

    if (filters != null) {
      filters.forEach((key, value) {
        request = request.eq(key, value);
      });
    }

    final response = await request.eq('is_active', true);
    return (response as List).map((json) => Scheme.fromJson(json)).toList();
  }

  Future<EligibilityResult> checkEligibility(String studentId, String schemeId) async {
    final response = await _supabase.functions.invoke('check-scheme-eligibility', body: {
      'student_id': studentId,
      'scheme_id': schemeId,
    });

    if (response.status != 200) {
      return EligibilityResult(eligible: false, missingCriteria: ['System error checking eligibility.']);
    }

    final data = response.data as Map<String, dynamic>;
    return EligibilityResult(
      eligible: data['eligible'] as bool,
      missingCriteria: List<String>.from(data['missing_criteria'] ?? []),
    );
  }

  Future<List<Scheme>> getRecommendedSchemes(String studentId) async {
    final response = await _supabase.functions.invoke('rank-schemes', body: {
      'student_id': studentId,
    });

    if (response.status != 200) return [];

    final data = response.data as List;
    return data.map((json) => Scheme.fromJson(json)).toList();
  }

  Future<String> chat({
    required String studentId,
    required String message,
    String language = 'hindi',
  }) async {
    final response = await _supabase.functions.invoke(
      'scheme-buddy-chat',
      body: {
        'student_id': studentId,
        'message': message,
        'language': language,
        'conversation_history': _conversationHistory,
      },
    );
    if (response.status != 200) {
      throw Exception('Chatbot error: ${response.data}');
    }
    final data = response.data as Map<String, dynamic>;
    final reply = data['reply'] as String;
    _conversationHistory.add({'role': 'user', 'content': message});
    _conversationHistory.add({'role': 'assistant', 'content': reply});
    return reply;
  }

  void clearHistory() => _conversationHistory.clear();
}
