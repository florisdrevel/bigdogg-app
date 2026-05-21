import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

/// Owns the Firebase + FCM lifecycle for the app:
///   - initFirebase()          — call once during main()
///   - registerWithBackend()   — call after sign-in to upload the
///                               device's FCM token to /api/v1/devices
///   - unregisterFromBackend() — call on sign-out
///   - listen()                — start foreground/onTap handlers
///
/// Failures are quiet — push is a best-effort enhancement, never a
/// hard requirement for the app to function.
class PushService {
  static bool _initialized = false;

  /// `'android'` / `'ios'` / `'web'` for FCM routing on the backend.
  /// Was hardcoded to `'android'`, which meant iOS devices never got
  /// pushes from any code path that conditions on the platform field.
  static String _platformLabel() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
    } catch (_) {
      // dart:io not available — treat as web.
    }
    return 'web';
  }

  static Future<void> initFirebase() async {
    if (_initialized || kIsWeb) return;
    try {
      await Firebase.initializeApp();
      _initialized = true;
    } catch (e) {
      // Likely missing google-services.json or running on a platform
      // without Firebase support. The rest of the app continues fine.
      // ignore: avoid_print
      print('[push] Firebase init failed: $e');
    }
  }

  /// Asks for notification permission, fetches the FCM token, posts
  /// it to /api/v1/devices/register-fcm-token. Safe to call repeatedly
  /// — the backend upserts on (user_id, fcm_token).
  static Future<void> registerWithBackend() async {
    if (!_initialized) return;
    try {
      final messaging = FirebaseMessaging.instance;

      // Android 13+ needs explicit POST_NOTIFICATIONS permission.
      // requestPermission() handles iOS too; on older Android it's a no-op.
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken == null) return;

      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/devices/register-fcm-token'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': token,
          'platform': _platformLabel(),
        }),
      );

      // If Firebase rotates the token mid-session, re-register
      // automatically so the device keeps receiving pushes.
      messaging.onTokenRefresh.listen((newToken) async {
        try {
          await http.post(
            Uri.parse('${ApiConfig.baseUrl}/api/v1/devices/register-fcm-token'),
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'token': newToken, 'platform': _platformLabel()}),
          );
        } catch (_) {/* silent */}
      });
    } catch (e) {
      // ignore: avoid_print
      print('[push] register failed: $e');
    }
  }

  static Future<void> unregisterFromBackend() async {
    if (!_initialized) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token == null) return;

      final prefs = await SharedPreferences.getInstance();
      final accessToken = prefs.getString('access_token');
      if (accessToken == null) return;

      await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/devices/fcm-token'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'token': token}),
      );

      // Drop the local token entirely so the next login on this device
      // gets a fresh one and doesn't see the previous user's pushes.
      await messaging.deleteToken();
    } catch (e) {
      // ignore: avoid_print
      print('[push] unregister failed: $e');
    }
  }

  /// Wires up the lifecycle listeners. Foreground messages are surfaced
  /// via the bell-icon system (the in-app notification was already
  /// inserted into Supabase by the backend, so the bell will pick it up
  /// on its next 15-second poll). Tap-from-background routing is
  /// delegated to the caller via [onMessageOpened] — we pass a plain
  /// Map<String,String> so callers do not need to import firebase_messaging.
  static void listen({
    void Function(Map<String, String> data)? onMessageOpened,
  }) {
    if (!_initialized) return;
    // Foreground: do nothing extra — the in-app notification system
    // (bell icon polling /unread-count) already covers this.
    FirebaseMessaging.onMessage.listen((_) {});

    // Tapped from background or terminated state.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (onMessageOpened != null) {
        onMessageOpened(Map<String, String>.from(message.data));
      }
    });
  }
}
