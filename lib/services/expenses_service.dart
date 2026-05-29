import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'api_cache.dart';
import 'auth_service.dart';
import 'local_storage_service.dart';
import 'mem_cache.dart';
import 'offline_queue.dart';

class ExpensesService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<String?> _getToken() async {
    await AuthService.refreshTokenIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<Map<String, dynamic>> getExpenses() async {
    return MemCache.readWithRefresh<Map<String, dynamic>>(
      key: 'expenses_list',
      ttl: const Duration(minutes: 5),
      cacheIf: (v) => v['success'] == true,
      fetcher: () => ApiCache.read(
        key: 'expenses_list',
        fetcher: () async {
          final token = await _getToken();
          final response = await http.get(
            Uri.parse('$baseUrl/api/v1/expenses/'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
          final data = jsonDecode(response.body);
          if (response.statusCode == 200) {
            return {'success': true, 'expenses': data['expenses']};
          }
          return {'success': false, 'message': data['detail']};
        },
      ),
    );
  }

  /// Drop caches that depend on the expenses list — dashboard overviews
  /// aggregate expense totals so they go stale too.
  static void _invalidateExpenseCaches() {
    MemCache.invalidate('expenses_list');
    MemCache.invalidatePrefix('overview_');
    MemCache.invalidatePrefix('quarter_detail');
    // Spec: any mutation forces a fresh dashboard fetch on next load.
    LocalStorageService.remove('dashboard');
  }

  static Future<Map<String, dynamic>> createExpense({
    required String description,
    required double amountExBtw,
    required int btwRate,
    required String category,
    String? expenseDate,
    String? projectId,
  }) async {
    final token = await _getToken();
    final body = {
      'description': description,
      'amount_ex_btw': amountExBtw,
      'btw_rate': btwRate,
      'category': category,
      'expense_date': expenseDate,
    };
    if (projectId != null) body['project_id'] = projectId;

    final result = await OfflineQueue.postOrEnqueue(
      url: '$baseUrl/api/v1/expenses/',
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: body,
      label: 'Kosten: $description',
    );
    _invalidateExpenseCaches();
    return result;
  }

  static Future<Map<String, dynamic>> parseReceipt({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final token = await _getToken();
    try {
      final uri = Uri.parse('$baseUrl/api/v1/expenses/parse-receipt');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      String contentType = 'image/jpeg';
      final ext = fileName.toLowerCase().split('.').last;
      if (ext == 'png') contentType = 'image/png';
      if (ext == 'gif') contentType = 'image/gif';
      if (ext == 'webp') contentType = 'image/webp';
      if (ext == 'pdf') contentType = 'application/pdf';
      if (ext == 'heic' || ext == 'heif') contentType = 'image/heic';

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
          contentType: MediaType.parse(contentType),
        ),
      );

      final response = await request.send();
      final body = await response.stream.bytesToString();
      final data = jsonDecode(body);
      if (response.statusCode == 200) {
        return {'success': true, ...data};
      }
      return {'success': false, 'message': data['detail'] ?? 'Parse failed'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>> uploadReceipt(
    String expenseId,
    Uint8List imageBytes,
    String filename,
  ) async {
    final token = await _getToken();
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/v1/expenses/upload-receipt/$expenseId'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: filename,
      ));
      final response = await request.send();
      final body = await response.stream.bytesToString();
      final data = jsonDecode(body);
      if (response.statusCode == 200) {
        return {'success': true, 'receipt_url': data['receipt_url']};
      }
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  static Future<Map<String, dynamic>> deleteExpense(String expenseId) async {
    final token = await _getToken();
    final result = await OfflineQueue.deleteOrEnqueue(
      url: '$baseUrl/api/v1/expenses/$expenseId',
      headers: {'Authorization': 'Bearer $token'},
      label: 'Kosten verwijderen: $expenseId',
    );
    _invalidateExpenseCaches();
    return result;
  }
}