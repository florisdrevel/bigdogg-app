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

  /// Confirm or change a transaction link.
  /// linkType: 'invoice' | 'expense' | 'private' | null (null unlinks)
  static Future<Map<String, dynamic>> setTransactionLink({
    required String txId,
    String? linkType,
    String? linkedId,
  }) async {
    final token = await _getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/banking/transactions/$txId/link'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'link_type': linkType,
          'linked_id': linkedId,
        }),
      );
      if (response.statusCode == 200) {
        return {'success': true, ...jsonDecode(response.body)};
      }
      try {
        final err = jsonDecode(response.body);
        return {'success': false, 'message': err['detail']?.toString()};
      } catch (_) {
        return {'success': false};
      }
    } catch (_) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  /// Create an expense from this transaction and auto-link it.
  static Future<Map<String, dynamic>> createExpenseFromTransaction({
    required String txId,
    required String description,
    required double amountExBtw,
    required double btwRate,
    required String expenseDate,
    String category = 'general',
  }) async {
    final token = await _getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/banking/transactions/$txId/create-expense'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'description': description,
          'amount_ex_btw': amountExBtw,
          'btw_rate': btwRate,
          'expense_date': expenseDate,
          'category': category,
        }),
      );
      if (response.statusCode == 200) {
        return {'success': true, ...jsonDecode(response.body)};
      }
      try {
        final err = jsonDecode(response.body);
        return {'success': false, 'message': err['detail']?.toString()};
      } catch (_) {
        return {'success': false};
      }
    } catch (_) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  /// Last 90 days of transactions from the connected bank.
  static Future<Map<String, dynamic>> getTransactions({int pageSize = 100}) async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/banking/transactions?page_size=$pageSize'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      try {
        final err = jsonDecode(response.body);
        return {
          'success': false,
          'status': response.statusCode,
          'message': err['detail']?.toString(),
        };
      } catch (_) {
        return {'success': false, 'status': response.statusCode};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }
}
