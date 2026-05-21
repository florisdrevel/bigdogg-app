import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'api_cache.dart';
import 'auth_service.dart';

class SubscriptionService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<String?> _getToken() async {
    await AuthService.refreshTokenIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  static Future<Map<String, dynamic>> getStatus() async {
    return ApiCache.read(
      key: 'subscription_status',
      fetcher: () async {
        var headers = await _authHeaders();
        var response = await http.get(
          Uri.parse('$baseUrl/api/v1/subscription/status'),
          headers: headers,
        );

        if (response.statusCode == 401) {
          final refreshed = await AuthService.refreshToken();
          if (refreshed) {
            headers = await _authHeaders();
            response = await http.get(
              Uri.parse('$baseUrl/api/v1/subscription/status'),
              headers: headers,
            );
          }
        }

        final data = jsonDecode(response.body);
        if (response.statusCode == 200) {
          return {'success': true, 'subscription': data};
        }
        return {'success': false, 'message': data['detail']};
      },
    );
  }

  static Future<Map<String, dynamic>> createCheckout() async {
    try {
      var headers = await _authHeaders();
      var response = await http.post(
        Uri.parse('$baseUrl/api/v1/subscription/checkout'),
        headers: headers,
      );

      if (response.statusCode == 401) {
        final refreshed = await AuthService.refreshToken();
        if (refreshed) {
          headers = await _authHeaders();
          response = await http.post(
            Uri.parse('$baseUrl/api/v1/subscription/checkout'),
            headers: headers,
          );
        }
      }

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'checkout_url': data['checkout_url']};
      }
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }
}