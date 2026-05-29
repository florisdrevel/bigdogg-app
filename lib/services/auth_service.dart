import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'api_cache.dart';
import 'mem_cache.dart';
import 'local_storage_service.dart';

class AuthService {
  static const String baseUrl = ApiConfig.baseUrl;

  // Single-flight guard for refreshToken(). Supabase rotates refresh
  // tokens on each use, so concurrent refreshes race — one rotation
  // invalidates the others and the user ends up silently logged out.
  // Every caller awaits the same in-flight Completer.
  static Completer<bool>? _refreshInFlight;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<Map<String, dynamic>> register(
    String email,
    String password,
    String fullName,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ref = prefs.getString('pending_referral_code');

      final body = <String, dynamic>{
        'email': email,
        'password': password,
        'full_name': fullName,
      };
      if (ref != null && ref.trim().isNotEmpty) {
        body['ref'] = ref.trim();
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // Clear the pending referral code so it isn't reused next signup
        await prefs.remove('pending_referral_code');
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': data['detail'] ?? 'Registration failed'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error. Please try again.'};
    }
  }

  static Future<Map<String, dynamic>> login(
    String email,
    String password, {
    bool rememberMe = true,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access_token']);
        await prefs.setString('refresh_token', data['refresh_token']);
        await prefs.setString('user_id', data['user']['id']);
        await prefs.setString('full_name', data['user']['full_name']);
        await prefs.setString('user_email', data['user']['email']);
        // Remember-me drives the auto-redirect on app start. When false,
        // the user will land on /login again next visit even though the
        // token is still in storage — same as a session-only login.
        await prefs.setBool('remember_me', rememberMe);
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': data['detail'] ?? 'Invalid email or password'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error. Please try again.'};
    }
  }

  /// Force-refresh the Supabase session. Concurrent callers share one
  /// in-flight refresh — see [_refreshInFlight].
  static Future<bool> refreshToken() async {
    final pending = _refreshInFlight;
    if (pending != null) return pending.future;
    final completer = Completer<bool>();
    _refreshInFlight = completer;
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken == null || refreshToken.isEmpty) {
        completer.complete(false);
        return false;
      }
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await prefs.setString('access_token', data['access_token']);
        await prefs.setString('refresh_token', data['refresh_token']);
        completer.complete(true);
        return true;
      }
      completer.complete(false);
      return false;
    } catch (_) {
      completer.complete(false);
      return false;
    } finally {
      _refreshInFlight = null;
    }
  }

  /// Refresh only if the cached access_token is missing or within five
  /// minutes of expiry. Cheaper than [refreshToken] — avoids burning a
  /// rotation every time the dashboard mounts/resumes.
  static Future<bool> refreshTokenIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null || token.isEmpty) return refreshToken();
    try {
      final parts = token.split('.');
      if (parts.length != 3) return refreshToken();
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! int) return refreshToken();
      final expiresAt =
          DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      final remaining =
          expiresAt.difference(DateTime.now().toUtc()).inSeconds;
      if (remaining < 300) return refreshToken();
      return true;
    } catch (_) {
      return refreshToken();
    }
  }

  static Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'message': data['detail'] ?? 'Error sending reset email'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error. Please try again.'};
    }
  }

  static Future<Map<String, dynamic>> changePassword(String newPassword) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/auth/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'new_password': newPassword}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'message': data['detail'] ?? 'Failed to change password'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error. Please try again.'};
    }
  }

  static Future<Map<String, dynamic>> deleteAccount() async {
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/v1/auth/delete-account'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        return {'success': true};
      }
      return {'success': false, 'message': data['detail'] ?? 'Failed to delete account'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error. Please try again.'};
    }
  }

  // Device-level preferences that must survive a logout. These aren't
  // tied to the account/session — wiping them on logout is what made the
  // welcome tour re-appear after every re-login (has_seen_walkthrough got
  // cleared) and reset the user's theme/language.
  static const List<String> _devicePrefKeys = [
    'theme',
    'language',
    'walkthrough_seen_version',
    'has_seen_walkthrough', // legacy key, preserved for migration
    'accountant_portal_lang',
  ];

  static Future<void> logout() async {
    await ApiCache.clearAll();
    MemCache.clearAll();
    // Persistent Hive cache too — never leave one user's financial
    // data accessible to the next person who opens the app.
    await LocalStorageService.clearAll();
    final prefs = await SharedPreferences.getInstance();
    // Snapshot the device-level prefs, clear everything (tokens, user
    // info, cached per-account flags), then restore the device prefs.
    final preserved = <String, Object>{};
    for (final key in _devicePrefKeys) {
      final value = prefs.get(key);
      if (value != null) preserved[key] = value;
    }
    await prefs.clear();
    for (final entry in preserved.entries) {
      final v = entry.value;
      if (v is String) {
        await prefs.setString(entry.key, v);
      } else if (v is bool) {
        await prefs.setBool(entry.key, v);
      } else if (v is int) {
        await prefs.setInt(entry.key, v);
      } else if (v is double) {
        await prefs.setDouble(entry.key, v);
      }
    }
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') != null;
  }
}
