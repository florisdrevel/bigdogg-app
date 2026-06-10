import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'auth_service.dart';

/// Frontend client for the TrueLayer-backed /api/v1/banking router.
/// The connect flow is: POST /connect returns a TrueLayer hosted-auth
/// URL → app opens it externally → user picks bank inside TrueLayer's
/// UI → TrueLayer redirects to /callback → backend exchanges code for
/// tokens → user lands back in app with ?bank=success.
class BankingService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<String?> _getToken() async {
    await AuthService.refreshTokenIfNeeded();
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

  /// Asks the backend to mint a TrueLayer hosted-auth URL for this user.
  /// The caller should open this URL in an external browser; TrueLayer
  /// shows the bank picker + PSD2 consent UI, then redirects back
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

  /// Create an investment from this transaction and auto-link it.
  static Future<Map<String, dynamic>> createInvestmentFromTransaction({
    required String txId,
    required String description,
    required double amount,
    required String purchaseDate,
    int depreciationYears = 5,
    String category = 'general',
  }) async {
    final token = await _getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/banking/transactions/$txId/create-investment'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'description': description,
          'amount': amount,
          'purchase_date': purchaseDate,
          'depreciation_years': depreciationYears,
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

  /// Upload an MT940 or CAMT.053 file to /banking/import. The backend
  /// auto-detects the format, persists the entries to the
  /// bank_transactions cache, runs the matcher, and returns a summary
  /// `{format, imported, auto_linked, suggested}`.
  static Future<Map<String, dynamic>> importStatement({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final token = await _getToken();
    try {
      final uri = Uri.parse('$baseUrl/api/v1/banking/import');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      // Best-effort content-type. The backend trusts the bytes, not the header.
      String contentType = 'application/octet-stream';
      final ext = fileName.toLowerCase().split('.').last;
      if (ext == 'xml' || ext == 'camt') contentType = 'application/xml';
      if (ext == 'sta' || ext == 'mt940' || ext == 'txt') contentType = 'text/plain';
      if (ext == 'pdf') contentType = 'application/pdf';

      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: MediaType.parse(contentType),
      ));

      final response = await request.send();
      final body = await response.stream.bytesToString();
      final data = jsonDecode(body);
      if (response.statusCode == 200) {
        return {'success': true, ...data};
      }
      return {'success': false, 'message': data['detail']?.toString() ?? 'import_failed'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  /// Send a bank-statement PDF to /bank/parse-statement. Claude extracts
  /// every transaction line. Returns
  /// `{success, transactions: [{date, description, amount}], count, bank}`
  /// or `{success: false, message}` / `{success: true, count: 0, error}`.
  static Future<Map<String, dynamic>> parseStatement({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final token = await _getToken();
    try {
      final uri = Uri.parse('$baseUrl/api/v1/bank/parse-statement');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: MediaType.parse('application/pdf'),
      ));
      final response = await request.send();
      final body = await response.stream.bytesToString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return {'success': true, ...data};
      }
      return {
        'success': false,
        'message': data['detail']?.toString() ?? 'parse_failed',
      };
    } catch (e) {
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

  /// Fetch the linked-transactions report as PDF bytes. When
  /// [matchedOnly] is true the report excludes unmatched + private
  /// transactions (no personal entries). Returns null on failure.
  static Future<Uint8List?> fetchReportPdf({required bool matchedOnly}) async {
    final token = await _getToken();
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/banking/report?matched_only=$matchedOnly'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
