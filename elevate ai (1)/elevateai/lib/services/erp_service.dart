import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class ERPService {
  final _supabase = Supabase.instance.client;

  // Static stream controller to notify all screens of a sync event
  static final StreamController<void> _syncController = StreamController<void>.broadcast();
  static Stream<void> get onSyncComplete => _syncController.stream;

  Future<Map<String, dynamic>> syncCollegeRecords(String studentId, String collegeId) async {
    // 1. Trigger ERP Sync
    final erpResponse = await _supabase.functions.invoke(
      'sync-erp',
      body: {
        'student_id': studentId,
        'college_id': collegeId,
      },
    );

    if (erpResponse.status != 200) {
      throw Exception('ERP Sync failed: ${erpResponse.data}');
    }

    // 2. Trigger Trust Score Update to recalculate based on new reliability/cgpa
    await _supabase.functions.invoke(
      'update-trust-score',
      body: {'student_id': studentId},
    );

    // 3. Trigger DNA Recalculation
    await _supabase.functions.invoke(
      'recalculate-dna',
      body: {'student_id': studentId},
    );

    // Notify listeners that sync is complete
    _syncController.add(null);

    return erpResponse.data as Map<String, dynamic>;
  }

  Future<DateTime?> getLastSyncTimestamp(String studentId) async {
    final res = await _supabase
        .from('student_profiles')
        .select('updated_at')
        .eq('id', studentId)
        .single();

    if (res['updated_at'] != null) {
      return DateTime.parse(res['updated_at']);
    }
    return null;
  }
}
