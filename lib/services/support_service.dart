import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class SupportService {
  static Future<bool> submit({
    required String name,
    required String email,
    required String message,
    required String preferredContact, // 'email' or 'video'
  }) async {
    try {
      final r = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/v1/support'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'email': email,
              'message': message,
              'preferred_contact': preferredContact,
            }),
          )
          .timeout(const Duration(seconds: 15));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
