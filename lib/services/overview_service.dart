import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'api_cache.dart';

class OverviewService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<Map<String, dynamic>> getQuarterlyOverview() async {
    return ApiCache.read(
      key: 'overview_quarterly',
      fetcher: () async {
        final token = await _getToken();
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
      },
    );
  }

  static Future<Map<String, dynamic>> getAnnualOverview({int? year}) async {
    final y = year ?? DateTime.now().year;
    return ApiCache.read(
      key: 'overview_annual:$y',
      fetcher: () async {
        final token = await _getToken();
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
      },
    );
  }
  // ─────────────────────────────────────────────────────────────────────────────
// ADD THESE TWO METHODS TO YOUR EXISTING OverviewService CLASS
// ─────────────────────────────────────────────────────────────────────────────

  /// Fetches the invoices + expenses that make up a specific quarter.
  /// Your API endpoint should return:
  ///   { "success": true, "invoices": [...], "expenses": [...] }
  static Future<Map<String, dynamic>> getQuarterDetail({
    required int quarter,
    required int year,
  }) async {
    return ApiCache.read(
      key: 'quarter_detail:$year:$quarter',
      fetcher: () async {
        final token = await _getToken();
        final response = await http.get(
          Uri.parse(
              '${ApiConfig.baseUrl}/api/v1/reports/quarter-detail?quarter=$quarter&year=$year'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return {
            'success': true,
            'invoices': data['invoices'] ?? [],
            'expenses': data['expenses'] ?? []
          };
        }
        return {'success': false};
      },
    );
  }

  /// Triggers async generation of the annual PDF report on the server side.
  /// The server should generate and then push a notification when done.
  /// Fire-and-forget — no need to await a result in the UI.
  static Future<void> generateAnnualReport({
    required int year,
    required String lang,
  }) async {
    try {
      final token = await _getToken();
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/v1/reports/annual/generate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'year': year, 'lang': lang}),
      );
    } catch (_) {
      // Fire-and-forget — silently ignore errors
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
