import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationService {
  static Future<void> initialize() async {
    debugPrint('Notifications placeholder initialized');
    // Bypass local notifications for build stability
  }

  static Future<void> registerAfterLogin() async {
    // Placeholder
  }
}
