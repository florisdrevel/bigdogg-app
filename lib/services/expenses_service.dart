import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class ExpensesService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<Map<String, dynamic>> getExpenses() async {
    final token = await _getToken();
    try {
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
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  static Future<Map<String, dynamic>> createExpense({
    required String description,
    required double amountExBtw,
    required int btwRate,
    required String category,
    String? expenseDate,
  }) async {
    final token = await _getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/expenses/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'description': description,
          'amount_ex_btw': amountExBtw,
          'btw_rate': btwRate,
          'category': category,
          'expense_date': expenseDate,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'expense': data['expense']};
      }
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }
  static Future<Map<String, dynamic>> parseReceipt({
  required Uint8List fileBytes,
  required String fileName,
}) async {
  final token = await _getToken();
  try {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/expenses/parse-receipt'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
    ));
    final response = await request.send();
    final body = await response.stream.bytesToString();
    final data = jsonDecode(body);
    if (response.statusCode == 200) {
      return {'success': true, ...data};
    }
    return {'success': false, 'message': data['detail']};
  } catch (e) {
    return {'success': false, 'message': 'Connection error'};
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
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/v1/expenses/$expenseId'),
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