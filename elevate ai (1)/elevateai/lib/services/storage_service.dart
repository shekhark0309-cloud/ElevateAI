import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final _supabase = Supabase.instance.client;

  Future<String> uploadAvatar({
    required String userId,
    required List<int> imageBytes,
    String mimeType = 'image/jpeg',
  }) async {
    final path = '$userId/avatar.jpg';
    await _supabase.storage
        .from('student-assets')
        .uploadBinary(path, Uint8List.fromList(imageBytes),
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ));

    return _supabase.storage
        .from('student-assets')
        .createSignedUrl(path, 3600);
  }

  Future<String> uploadResume({
    required String userId,
    required List<int> pdfBytes,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '$userId/resume_$timestamp.pdf';

    await _supabase.storage
        .from('student-assets')
        .uploadBinary(path, Uint8List.fromList(pdfBytes),
            fileOptions: const FileOptions(contentType: 'application/pdf'));

    return _supabase.storage
        .from('student-assets')
        .createSignedUrl(path, 3600 * 24 * 7);
  }
}
