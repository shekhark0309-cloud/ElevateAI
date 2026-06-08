import 'package:supabase_flutter/supabase_flutter.dart';

class TaskService {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getMyTasks() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final data = await _supabase
        .from('student_tasks')
        .select()
        .eq('student_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> addTask(String title, {String category = 'task', DateTime? dueAt}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('student_tasks').insert({
      'student_id': user.id,
      'title': title,
      'category': category,
      'due_at': dueAt?.toIso8601String(),
    });
  }

  Future<void> toggleTask(String taskId, bool isCompleted) async {
    await _supabase
        .from('student_tasks')
        .update({'is_completed': isCompleted})
        .eq('id', taskId);
  }
}
