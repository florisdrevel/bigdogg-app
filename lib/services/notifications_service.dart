import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

/// In-app notifications. The backend inserts rows server-side
/// (invoice paid / quote accepted / client onboarded); the app polls
/// the unread count and renders the list in a bell-icon sheet on the
/// dashboard.
class NotificationsService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<List<dynamic>> list({int limit = 50}) async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/notifications/?limit=$limit'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['notifications'] as List?) ?? [];
      }
    } catch (_) {}
    return [];
  }

  static Future<int> unreadCount() async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/notifications/unread-count'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['count'] as int?) ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  static Future<void> markRead(String id) async {
    final token = await _getToken();
    try {
      await http.post(
        Uri.parse('$baseUrl/api/v1/notifications/$id/read'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {}
  }

  static Future<void> markAllRead() async {
    final token = await _getToken();
    try {
      await http.post(
        Uri.parse('$baseUrl/api/v1/notifications/read-all'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {}
  }

  static Future<void> deleteNotification(String id) async {
    final token = await _getToken();
    try {
      await http.delete(
        Uri.parse('$baseUrl/api/v1/notifications/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {}
  }
}
