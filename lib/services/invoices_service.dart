import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class InvoicesService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<Map<String, dynamic>> getInvoices() async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/invoices/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'invoices': data['invoices']};
      }
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  static Future<Map<String, dynamic>> createInvoice({
    required String clientId,
    required List<Map<String, dynamic>> lines,
    String? notes,
  }) async {
    final token = await _getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/invoices/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'client_id': clientId,
          'lines': lines,
          'notes': notes,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'invoice': data['invoice']};
      }
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }
  static Future<Map<String, dynamic>> getInvoice(String invoiceId) async {
  final token = await _getToken();
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/invoices/$invoiceId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {'success': true, 'invoice': data['invoice'], 'lines': data['lines']};
    }
    return {'success': false, 'message': data['detail']};
  } catch (e) {
    return {'success': false, 'message': 'Connection error'};
  }
}
  static Future<Map<String, dynamic>> updateStatus(
    String invoiceId,
    String status,
  ) async {
    final token = await _getToken();
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/api/v1/invoices/$invoiceId/status'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': status}),
      );
      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }
  static Future<String?> getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('access_token');
}
  static Future<String?> getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('access_token');
}
  static Future<Map<String, dynamic>> deleteInvoice(String invoiceId) async {
  final token = await _getToken();
  try {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/v1/invoices/$invoiceId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return {'success': true};
    }
    return {'success': false};
  } catch (e) {
    return {'success': false, 'message': 'Connection error'};
  }
}
  static Future<Map<String, dynamic>> sendReminder(String invoiceId) async {
    final token = await _getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/invoices/$invoiceId/reminder'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }
}