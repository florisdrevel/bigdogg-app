import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'auth_service.dart';

/// Non-consuming probe used before launching a PDF download URL in an
/// external browser. The actual PDF endpoint consumes a PAYG credit
/// when it serves bytes; this just decides whether we can safely
/// launch it.
class ReportAccessService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<String?> _getToken() async {
    await AuthService.refreshTokenIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Outcome of a check call.
  ///
  /// - access: 'allowed' | 'payment_required' | 'subscribe_required' | 'error'
  /// - checkoutUrl: present when access == 'payment_required'
  /// - amountCents: present when access == 'payment_required'
  static Future<Map<String, dynamic>> check({
    required String type,
    required int year,
    int? quarter,
  }) async {
    final token = await _getToken();
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/api/v1/subscription/check-report-access'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'type': type,
          'year': year,
          if (quarter != null) 'quarter': quarter,
        }),
      );
      if (resp.statusCode != 200) {
        return {'access': 'error', 'message': 'HTTP ${resp.statusCode}'};
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data;
    } catch (e) {
      return {'access': 'error', 'message': e.toString()};
    }
  }
}
