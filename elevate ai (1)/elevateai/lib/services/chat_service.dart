import 'package:supabase_flutter/supabase_flutter.dart';
import '../flutter_integration.dart';

class ChatService {
  final _supabase = Supabase.instance.client;

  /// Fetches all conversations for the current user
  Future<List<Map<String, dynamic>>> getConversations() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('conversations')
        .select('''
          *,
          student_a:student_profiles!student_a_id(id, full_name, avatar_url),
          student_b:student_profiles!student_b_id(id, full_name, avatar_url)
        ''')
        .or('student_a_id.eq.$userId,student_b_id.eq.$userId')
        .order('last_message_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Fetches messages for a specific conversation
  Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    final response = await _supabase
        .from('messages')
        .select('*')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Streams messages for a specific conversation in realtime
  Stream<List<Map<String, dynamic>>> streamMessages(String conversationId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
  }

  /// Sends a message to a conversation
  Future<void> sendMessage(String conversationId, String content) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'content': content,
    });
  }

  /// Gets an existing conversation or creates a new one between two students
  Future<String> getOrCreateConversation(String receiverId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('Authentication required');

    final studentAId = userId.compareTo(receiverId) < 0 ? userId : receiverId;
    final studentBId = userId.compareTo(receiverId) < 0 ? receiverId : userId;

    final existing = await _supabase
        .from('conversations')
        .select('id')
        .eq('student_a_id', studentAId)
        .eq('student_b_id', studentBId)
        .maybeSingle();

    if (existing != null) {
      return existing['id'] as String;
    }

    final response = await _supabase.from('conversations').insert({
      'student_a_id': studentAId,
      'student_b_id': studentBId,
    }).select('id').single();

    return response['id'] as String;
  }

  /// Marks all messages in a conversation as read
  Future<void> markAsRead(String conversationId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('messages')
        .update({'is_read': true})
        .eq('conversation_id', conversationId)
        .neq('sender_id', userId)
        .eq('is_read', false);
  }
}
