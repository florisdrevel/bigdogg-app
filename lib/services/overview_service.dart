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

  static Future<Map<String, dynamic>> getQuarterlyOverview({int? year, int? quarter}) async {
    final token = await _getToken();
    try {
      String url = '$baseUrl/api/v1/overview/quarterly';
      if (year != null || quarter != null) {
        final params = <String>[];
        if (year != null) params.add('year=$year');
        if (quarter != null) params.add('quarter=$quarter');
        url += '?${params.join('&')}';
      }
      final response = await http.get(
        Uri.parse(url),
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
      String url = '$baseUrl/api/v1/overview/annual';
      if (year != null) url += '?year=$year';
      final response = await http.get(
        Uri.parse(url),
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
}