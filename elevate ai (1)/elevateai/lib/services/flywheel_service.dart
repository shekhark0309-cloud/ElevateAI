import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class FlywheelService {
  final _supabase = Supabase.instance.client;

  /// Listens for a unified 'flywheel_update' event from the database.
  /// When any key metric (Trust, DNA, Notifs) changes, [onUpdate] is triggered.
  void subscribeToGrowthSignals(String studentId, VoidCallback onUpdate) {
    _supabase
        .channel('flywheel-room')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trust_scores',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'student_id',
            value: studentId,
          ),
          callback: (payload) => onUpdate(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'student_dna',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'student_id',
            value: studentId,
          ),
          callback: (payload) => onUpdate(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'student_id',
            value: studentId,
          ),
          callback: (payload) => onUpdate(),
        )
        .subscribe();
  }

  /// Disconnects from the flywheel channel.
  void unsubscribeFromSignals() {
    _supabase.removeChannel(_supabase.channel('flywheel-room'));
  }
}
