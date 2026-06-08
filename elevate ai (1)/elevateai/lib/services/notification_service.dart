import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  final _supabase = Supabase.instance.client;

  Future<void> registerDevice({
    required String fcmToken,
    String? deviceName,
    String? deviceOs,
  }) async {
    await _supabase.rpc('register_device_token', params: {
      'p_fcm_token': fcmToken,
      'p_device_name': deviceName,
      'p_device_os': deviceOs,
    });
  }

  Future<List<Map<String, dynamic>>> getNotifications({
    required String studentId,
    bool unreadOnly = false,
    int limit = 20,
  }) async {
    var query = _supabase
        .from('notifications')
        .select()
        .eq('student_id', studentId);

    if (unreadOnly) {
      query = query.eq('is_read', false);
    }

    final data = await query
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead(String studentId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('student_id', studentId)
        .eq('is_read', false);
  }

  Future<void> createSmartNudgeNotification({
    required String studentId,
    required String title,
    required String body,
    String? type,
    Map<String, dynamic>? metadata,
  }) async {
    await _supabase.from('notifications').insert({
      'student_id': studentId,
      'title': title,
      'body': body,
      'type': type ?? 'smart_nudge',
      'metadata': metadata ?? {},
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  RealtimeChannel subscribeToNotifications({
    required String studentId,
    required Function(Map<String, dynamic>) onNewNotification,
  }) {
    return _supabase
        .channel('notifications-$studentId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'student_id',
            value: studentId,
          ),
          callback: (payload) => onNewNotification(payload.newRecord),
        )
        .subscribe();
  }
}
