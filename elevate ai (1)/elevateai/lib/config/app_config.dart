class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://buwiiyklldzfiryjqfyv.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ1d2lpeWtsbGR6ZmlyeWpxZnl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA1ODkxOTYsImV4cCI6MjA5NjE2NTE5Nn0.dakH3RuXtJ-hz7e-XSfwBo6T2VfIguANML4zzuXajlw',
  );

  static const anthropicApiKey = String.fromEnvironment(
    'ANTHROPIC_API_KEY',
    defaultValue: '',
  );

  static const geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const fcmSenderId = String.fromEnvironment(
    'FCM_SENDER_ID',
    defaultValue: '231916737463',
  );

  static void validate() {
    if (supabaseUrl.contains('FILL_IN') || supabaseUrl.isEmpty) {
      throw Exception('CRITICAL: SUPABASE_URL is not configured.');
    }
    if (supabaseAnonKey.contains('FILL_IN') || supabaseAnonKey.isEmpty) {
      throw Exception('CRITICAL: SUPABASE_ANON_KEY is not configured.');
    }
  }
}
