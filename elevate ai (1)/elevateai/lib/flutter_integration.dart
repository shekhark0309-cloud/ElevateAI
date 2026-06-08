// =============================================================================
// ElevateAI — Flutter Integration Facade
// File: flutter_integration.dart
// =============================================================================

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:elevateai/config/app_config.dart';

// Exporting all services from the new modular structure
export 'services/auth_service.dart';
export 'services/dna_service.dart';
export 'services/trust_score_service.dart';
export 'services/team_service.dart';
export 'services/opportunity_service.dart';
export 'services/notification_service.dart';
export 'services/skills_service.dart';
export 'services/scheme_buddy_service.dart';
export 'services/storage_service.dart';
export 'services/dashboard_service.dart';
export 'services/tv_data_service.dart';
export 'services/tv_radio_service.dart';
export 'services/local_db_service.dart';
export 'services/task_service.dart';
export 'services/chat_service.dart';
export 'services/scam_service.dart';
export 'services/cafeteria_service.dart';

// ─── Initialization ───────────────────────────────────────────────────────────

/// Call this in main() before runApp()
Future<void> initSupabase() async {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
}

SupabaseClient get supabase => Supabase.instance.client;
