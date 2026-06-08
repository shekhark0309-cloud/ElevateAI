import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

class NativeNavigationService {
  static const _channel = MethodChannel('com.elevateai.app/native_nav');

  /// Opens a native Android screen (Compose)
  /// [route] - The native route (e.g., 'focus_mode', 'dashboard')
  /// [arguments] - Optional map of arguments to pass to the native screen
  static Future<void> openNativeScreen(BuildContext context, String route, {Map<String, dynamic>? arguments}) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;

      final Map<String, dynamic> args = {
        'route': route,
        'arguments': arguments ?? {},
        'session': session?.toJson(),
      };

      final result = await _channel.invokeMethod('openScreen', args);

      if (result != null && result is Map) {
        final target = result['target'] as String?;
        if (target != null && context.mounted) {
          // Unify route naming: If it starts with /, use context.push
          // If it's a native key, recursively call openNativeScreen (if appropriate)
          if (target.startsWith('/')) {
            context.push(target);
          } else {
            // Handle native-to-native internal jumps that return to Flutter
            _handleSpecialTarget(context, target);
          }
        }
      }
    } on PlatformException catch (e) {
      debugPrint("Native navigation failed: '${e.message}'.");
    }
  }

  static void _handleSpecialTarget(BuildContext context, String target) {
    // Check if target is a native key or needs special handling
    final cleanTarget = target.startsWith('/') ? target.substring(1) : target;

    switch (cleanTarget) {
      case 'dashboard': openOSDashboard(context); break;
      case 'focus':
      case 'focus_mode': openFocusMode(context); break;
      case 'scheme_buddy':
      case 'scholarships': openSchemeBuddy(context); break;
      case 'peer_network': openPeerNetwork(context); break;
      case 'career':
      case 'career_predictor': openCareerPredictor(context); break;
      case 'teams':
      case 'team_finder': openTeamFinder(context); break;
      case 'cafeteria':
      case 'meals': openCafeteria(context); break;
      default:
        // If we reach here and it's not a known native route,
        // and it was meant to be a flutter route, it's already handled in openNativeScreen
        break;
    }
  }

  // Helper methods for specific screens
  static Future<void> openFocusMode(BuildContext context) => openNativeScreen(context, 'focus_mode');
  static Future<void> openPeerNetwork(BuildContext context) => openNativeScreen(context, 'peer_network');
  static Future<void> openOSDashboard(BuildContext context) => openNativeScreen(context, 'dashboard');
  static Future<void> openSchemeBuddy(BuildContext context) => openNativeScreen(context, 'scheme_buddy');
  static Future<void> openCareerPredictor(BuildContext context) => openNativeScreen(context, 'career_predictor');
  static Future<void> openTeamFinder(BuildContext context) => openNativeScreen(context, 'team_finder');
  static Future<void> openCafeteria(BuildContext context) => openNativeScreen(context, 'cafeteria');
}
