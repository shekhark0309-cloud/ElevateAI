import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/portfolio_models.dart';

class PortfolioService {
  final _supabase = Supabase.instance.client;

  Future<List<StudentProject>> getProjects(String studentId) async {
    final response = await _supabase
        .from('student_projects')
        .select()
        .eq('student_id', studentId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => StudentProject.fromJson(json)).toList();
  }

  Future<List<StudentAchievement>> getAchievements(String studentId) async {
    final response = await _supabase
        .from('student_achievements')
        .select()
        .eq('student_id', studentId)
        .order('created_at', ascending: false);

    return (response as List).map((json) => StudentAchievement.fromJson(json)).toList();
  }

  Future<void> addProject(StudentProject project) async {
    await _supabase.from('student_projects').insert({
      'student_id': project.studentId,
      'title': project.title,
      'description': project.description,
      'tech_stack': project.techStack,
      'role': project.role,
      'outcome': project.outcome,
      'github_url': project.githubUrl,
      'live_url': project.liveUrl,
      'is_featured': project.isFeatured,
    });
  }

  Future<String> uploadResume(String studentId, File file, Map<String, dynamic> resumeData) async {
    final fileName = 'resumes/${studentId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final path = await _supabase.storage.from('student-assets').upload(
      fileName,
      file,
      fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
    );

    final publicUrl = _supabase.storage.from('student-assets').getPublicUrl(fileName);

    await _supabase.from('resume_history').insert({
      'student_id': studentId,
      'pdf_url': publicUrl,
      'resume_data': resumeData,
    });

    return publicUrl;
  }

  Future<List<Map<String, dynamic>>> getResumeHistory(String studentId) async {
    final response = await _supabase
        .from('resume_history')
        .select()
        .eq('student_id', studentId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }
}
