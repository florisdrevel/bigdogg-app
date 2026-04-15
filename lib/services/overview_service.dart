import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class OverviewService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<Map<String, dynamic>> getQuarterlyOverview() async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/overview/quarterly'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'overview': data};
      }
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  static Future<Map<String, dynamic>> getAnnualOverview({int? year}) async {
    final token = await _getToken();
    try {
      final yearParam = year != null ? '?year=$year' : '';
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/overview/annual$yearParam'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'overview': data};
      }
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  /// Pre-flight check before launching the annual report PDF URL.
  /// Uses HEAD so no PDF binary is downloaded — only the status code matters.
  /// Returns 'paid_tier_required' if blocked, 'ok' for everything else.
  static Future<String> checkAnnualReportAccess({required int year}) async {
    final token = await _getToken();
    try {
      final response = await http.head(
        Uri.parse('$baseUrl/api/v1/reports/annual/pdf?token=$token&year=$year&lang=en'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      // Only block on explicit 403 — treat 200 and any other status as allowed
      if (response.statusCode == 403) return 'paid_tier_required';
      return 'ok';
    } catch (e) {
      // On network error, let it through — launchUrl will handle it
      return 'ok';
    }
  }
}