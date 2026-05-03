import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'dart:typed_data';
import 'package:http_parser/http_parser.dart';

class InvoicesService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<String?> getToken() async {
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
    String? projectId,
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
          if (projectId != null) 'project_id': projectId,
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
        return {
          'success': true,
          'invoice': data['invoice'],
          'lines': data['lines']
        };
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

  static Future<Map<String, dynamic>> importInvoices({
    required List<Uint8List> filesBytes,
    required List<String> fileNames,
  }) async {
    final token = await getToken();
    try {
      final uri = Uri.parse('$baseUrl/api/v1/invoices/import-invoices');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      for (int i = 0; i < filesBytes.length; i++) {
        final fileName = fileNames[i];
        final ext = fileName.toLowerCase().split('.').last;

        String contentType;
        switch (ext) {
          case 'pdf':
            contentType = 'application/pdf';
            break;
          case 'png':
            contentType = 'image/png';
            break;
          case 'jpg':
          case 'jpeg':
            contentType = 'image/jpeg';
            break;
          case 'webp':
            contentType = 'image/webp';
            break;
          case 'heic':
          case 'heif':
            contentType = 'image/heic';
            break;
          default:
            contentType = 'image/jpeg';
        }

        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            filesBytes[i],
            filename: fileName,
            contentType: MediaType.parse(contentType),
          ),
        );
      }

      final response = await request.send();
      final body = await response.stream.bytesToString();
      final data = jsonDecode(body);
      if (response.statusCode == 200) {
        return {'success': true, ...data};
      }
      return {'success': false, 'message': data['detail'] ?? 'Import failed'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
  static Future<Map<String, dynamic>> importExpenses({
  required List<Uint8List> filesBytes,
  required List<String> fileNames,
}) async {
  final token = await getToken();
  try {
    final uri = Uri.parse('$baseUrl/api/v1/expenses/import-expenses');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    for (int i = 0; i < filesBytes.length; i++) {
      final fileName = fileNames[i];
      final ext = fileName.toLowerCase().split('.').last;
      String contentType;
      switch (ext) {
        case 'pdf': contentType = 'application/pdf'; break;
        case 'png': contentType = 'image/png'; break;
        case 'jpg': case 'jpeg': contentType = 'image/jpeg'; break;
        case 'webp': contentType = 'image/webp'; break;
        default: contentType = 'image/jpeg';
      }
      request.files.add(http.MultipartFile.fromBytes(
        'files', filesBytes[i],
        filename: fileName,
        contentType: MediaType.parse(contentType),
      ));
    }

    final response = await request.send();
    final body = await response.stream.bytesToString();
    final data = jsonDecode(body);
    if (response.statusCode == 200) {
      return {'success': true, ...data};
    }
    return {'success': false, 'message': data['detail'] ?? 'Import failed'};
  } catch (e) {
    return {'success': false, 'message': 'Connection error: $e'};
  }
}

static Future<Map<String, dynamic>> getImportedInvoices() async {
  final token = await getToken();
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/invoices/imported'),
      headers: {'Authorization': 'Bearer $token'},
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

static Future<Map<String, dynamic>> deleteImportedInvoice(String invoiceId) async {
  final token = await getToken();
  try {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/v1/invoices/imported/$invoiceId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) return {'success': true};
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