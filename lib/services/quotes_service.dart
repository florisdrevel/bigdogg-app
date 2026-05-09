import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'api_cache.dart';
import 'offline_queue.dart';

class QuotesService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<String?> getToken() => _getToken();

  static Future<Map<String, dynamic>> getQuotes() async {
    return ApiCache.read(
      key: 'quotes_list',
      fetcher: () async {
        final token = await _getToken();
        final response = await http.get(
          Uri.parse('$baseUrl/api/v1/quotes/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
        final data = jsonDecode(response.body);
        if (response.statusCode == 200) {
          return {'success': true, 'quotes': data['quotes']};
        }
        return {'success': false, 'message': data['detail']};
      },
    );
  }

  static Future<Map<String, dynamic>> getQuote(String quoteId) async {
    return ApiCache.read(
      key: 'quote:$quoteId',
      fetcher: () async {
        final token = await _getToken();
        final response = await http.get(
          Uri.parse('$baseUrl/api/v1/quotes/$quoteId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
        final data = jsonDecode(response.body);
        if (response.statusCode == 200) {
          return {
            'success': true,
            'quote': data['quote'],
            'lines': data['lines']
          };
        }
        return {'success': false, 'message': data['detail']};
      },
    );
  }

  static Future<Map<String, dynamic>> createQuote({
    required String clientId,
    required List<Map<String, dynamic>> lines,
    String? notes,
    String? projectId,
    String? validUntil,
  }) async {
    final token = await _getToken();
    return OfflineQueue.postOrEnqueue(
      url: '$baseUrl/api/v1/quotes/',
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: {
        'client_id': clientId,
        'lines': lines,
        'notes': notes,
        if (projectId != null) 'project_id': projectId,
        if (validUntil != null) 'valid_until': validUntil,
      },
      label: 'Offerte (${lines.length} regel${lines.length == 1 ? '' : 's'})',
    );
  }

  static Future<Map<String, dynamic>> updateStatus(
    String quoteId,
    String status,
  ) async {
    final token = await _getToken();
    return OfflineQueue.putOrEnqueue(
      url: '$baseUrl/api/v1/quotes/$quoteId',
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: {'status': status},
      label: 'Offerte status → $status',
    );
  }

  static Future<Map<String, dynamic>> deleteQuote(String quoteId) async {
    final token = await _getToken();
    return OfflineQueue.deleteOrEnqueue(
      url: '$baseUrl/api/v1/quotes/$quoteId',
      headers: {'Authorization': 'Bearer $token'},
      label: 'Offerte verwijderen: $quoteId',
    );
  }

  static Future<Map<String, dynamic>> convertToInvoice(String quoteId) async {
    final token = await _getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/quotes/$quoteId/convert'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'invoice_id': data['invoice_id'],
          'invoice_number': data['invoice_number'],
          'already_converted': data['already_converted'] == true,
        };
      }
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }
}
