import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

/// Frontend client for the /api/v1/banking router (now backed by
/// GoCardless Bank Account Data — formerly Nordigen).
class BankingService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Returns whether the user has a connected bank, plus connection metadata.
  /// Shape: { connected: bool, requisition_id, institution_id, account_count,
  ///          connected_at }
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

  /// List of banks available for the user's country (NL by default).
  /// Shape: { success: bool, institutions: [{id, name, bic, logo, ...}] }
  static Future<Map<String, dynamic>> getInstitutions({String country = 'nl'}) async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/banking/institutions?country=$country'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {'success': true, 'institutions': data['institutions'] ?? []};
      }
      try {
        final err = jsonDecode(response.body);
        return {'success': false, 'message': err['detail']?.toString()};
      } catch (_) {
        return {'success': false};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  /// Asks the backend to mint a GoCardless requisition link for the chosen
  /// institution. The caller should open the returned link_url in an
  /// external browser; GoCardless will redirect through our /callback when
  /// the user finishes consenting.
  static Future<Map<String, dynamic>> connect({required String institutionId}) async {
    final token = await _getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/banking/connect'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'institution_id': institutionId}),
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

  /// Recent booked transactions across the user's connected accounts.
  static Future<Map<String, dynamic>> getTransactions({int pageSize = 200}) async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/banking/transactions?page_size=$pageSize'),
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
