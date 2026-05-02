import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

/// Frontend client for the Tink-backed /api/v1/banking router.
class BankingService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Returns whether the user has a connected bank, plus connection metadata.
  /// Shape: { connected: bool, credentials_id, connected_at, token_expires_at, ... }
  static Future<Map<String, dynamic>> getStatus() async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/banking/status'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, ...data};
      }
      return {'success': false, 'connected': false};
    } catch (_) {
      return {'success': false, 'connected': false};
    }
  }

  /// Asks the backend to mint a Tink Link URL for this user. The caller
  /// should open this URL in an external browser; Tink will redirect back
  /// through the registered callback once the user finishes.
  static Future<Map<String, dynamic>> connect() async {
    final token = await _getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/banking/connect'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'link_url': data['link_url']};
      }
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  static Future<Map<String, dynamic>> disconnect() async {
    final token = await _getToken();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/v1/banking/disconnect'),
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

  /// Last 90 days of transactions from the connected bank.
  static Future<Map<String, dynamic>> getTransactions({int pageSize = 100}) async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse(
            '$baseUrl/api/v1/banking/transactions?page_size=$pageSize'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }
}
