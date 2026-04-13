import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class PaymentsService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<Map<String, dynamic>> getConnectStatus() async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/payments/connect/status'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return {'success': true, ...data};
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  static Future<Map<String, dynamic>> createConnectLink() async {
    final token = await _getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/payments/connect'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return {'success': true, ...data};
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  static Future<Map<String, dynamic>> createPaymentLink(String invoiceId) async {
    final token = await _getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/payments/invoice/$invoiceId/payment-link'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return {'success': true, ...data};
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }
}