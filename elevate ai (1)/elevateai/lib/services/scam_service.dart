import 'package:supabase_flutter/supabase_flutter.dart';

class ScamService {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getScamFeed({
    String? category,
    String? severity,
    String? searchTerm,
  }) async {
    var query = _supabase.from('v_scam_intelligence_feed').select();

    if (category != null && category != 'All') {
      query = query.eq('category', category);
    }
    if (severity != null && severity != 'All') {
      query = query.eq('severity', severity);
    }
    if (searchTerm != null && searchTerm.isNotEmpty) {
      query = query.ilike('title', '%$searchTerm%');
    }

    final data = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> reportScam({
    String? opportunityId,
    required String category,
    required String title,
    required String description,
    String? evidenceUrl,
    String severity = 'medium',
  }) async {
    await _supabase.rpc('submit_scam_report', params: {
      'p_opportunity_id': opportunityId,
      'p_scam_type': category,
      'p_title': title,
      'p_description': description,
      'p_evidence_url': evidenceUrl,
      'p_severity': severity,
    });
  }

  RealtimeChannel subscribeToScamAlerts(Function(Map<String, dynamic>) onAlert) {
    return _supabase
        .channel('scam_alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'scam_reports',
          callback: (payload) => onAlert(payload.newRecord),
        )
        .subscribe();
  }
}
