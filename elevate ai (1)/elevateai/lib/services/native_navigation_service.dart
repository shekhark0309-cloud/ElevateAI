import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class NativeNavigationService {
  static const _channel = MethodChannel('com.elevateai.app/native_nav');

  /// Opens a native Android screen (Compose)
  /// [route] - The native route (e.g., 'focus_mode', 'dashboard')
  /// [arguments] - Optional map of arguments to pass to the native screen
  static Future<Map<String, dynamic>?> openNativeScreen(String route, {Map<String, dynamic>? arguments}) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;

      final Map<String, dynamic> args = {
        'route': route,
        'arguments': arguments ?? {},
        'session': session?.toJson(),
      };

      final result = await _channel.invokeMethod('openScreen', args);
      return result != null ? Map<String, dynamic>.from(result) : null;
    } on PlatformException catch (e) {
      debugPrint("Native navigation failed: '${e.message}'.");
      return {'error': e.message};
    }
  }

  // Helper methods for specific screens
  static Future<void> openFocusMode() => openNativeScreen('focus_mode');
  static Future<void> openPeerNetwork() => openNativeScreen('peer_network');
  static Future<void> openOSDashboard() => openNativeScreen('dashboard');
  static Future<void> openSchemeBuddy() => openNativeScreen('scheme_buddy');
  static Future<void> openCareerPredictor() => openNativeScreen('career_predictor');
  static Future<void> openTeamFinder() => openNativeScreen('team_finder');
}
