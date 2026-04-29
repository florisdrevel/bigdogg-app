import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class ReferralResult {
  final String? code;
  final String? error;
  const ReferralResult({this.code, this.error});
  bool get ok => code != null;
}

class ReferralService {
  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static String _detailFromBody(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) {
        return decoded['detail'].toString();
      }
    } catch (_) {}
    return 'Server error $statusCode';
  }

  /// Returns {code, error}. On success, code is set; on failure, error is set
  /// with the backend's detail message so the UI can surface it.
  static Future<ReferralResult> generateCode() async {
    try {
      final t = await _token();
      if (t == null) return const ReferralResult(error: 'Not signed in');
      final r = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/v1/referrals/generate'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $t',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        return ReferralResult(code: data['code'] as String?);
      }
      return ReferralResult(
          error: _detailFromBody(r.body, r.statusCode));
    } catch (e) {
      return ReferralResult(error: 'Connection error: $e');
    }
  }

  /// Returns {code, signups, converted}. Falls back to zeros on error.
  static Future<Map<String, dynamic>> getStats() async {
    try {
      final t = await _token();
      if (t == null) return {'code': null, 'signups': 0, 'converted': 0};
      final r = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/v1/referrals/stats'),
            headers: {'Authorization': 'Bearer $t'},
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        return {
          'code': data['code'],
          'signups': data['signups'] ?? 0,
          'converted': data['converted'] ?? 0,
        };
      }
    } catch (_) {}
    return {'code': null, 'signups': 0, 'converted': 0};
  }
}
