import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class ReferralService {
  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Returns the user's referral code, generating one if needed. Null on error.
  static Future<String?> generateCode() async {
    try {
      final t = await _token();
      if (t == null) return null;
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
        return data['code'] as String?;
      }
    } catch (_) {}
    return null;
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
