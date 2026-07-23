import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'api_cache.dart';
import 'auth_service.dart';
import 'mem_cache.dart';
import 'offline_queue.dart';

class QuotesService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<String?> _getToken() async {
    await AuthService.refreshTokenIfNeeded();
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

  /// Synchronous peek into the in-memory cache for a single quote. The
  /// detail screen calls this to paint instantly on a revisit before the
  /// silent background refresh lands. Null if not cached this session.
  static Map<String, dynamic>? peekQuote(String quoteId) {
    final cached = MemCache.read<Map<String, dynamic>>('quote:$quoteId');
    if (cached != null && cached['success'] == true) return cached;
    return null;
  }

  /// Drop the in-memory caches a quote mutation makes stale so the detail
  /// screen re-fetches fresh data on its next load.
  static void _invalidateQuoteCaches(String quoteId) {
    MemCache.invalidate('quote:$quoteId');
  }

  /// 5-minute in-memory cache with stale-while-revalidate, keyed per quote.
  /// ApiCache stays the offline disk fallback inside the fetcher. A repeat
  /// open returns the RAM cache instantly; a stale open serves cache and
  /// refreshes in the background.
  static Future<Map<String, dynamic>> getQuote(String quoteId) async {
    return MemCache.readWithRefresh<Map<String, dynamic>>(
      key: 'quote:$quoteId',
      ttl: const Duration(minutes: 5),
      cacheIf: (v) => v['success'] == true,
      fetcher: () => ApiCache.read(
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
      ),
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
    final result = await OfflineQueue.putOrEnqueue(
      url: '$baseUrl/api/v1/quotes/$quoteId',
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: {'status': status},
      label: 'Offerte status → $status',
    );
    _invalidateQuoteCaches(quoteId);
    return result;
  }

  static Future<Map<String, dynamic>> deleteQuote(String quoteId) async {
    final token = await _getToken();
    final result = await OfflineQueue.deleteOrEnqueue(
      url: '$baseUrl/api/v1/quotes/$quoteId',
      headers: {'Authorization': 'Bearer $token'},
      label: 'Offerte verwijderen: $quoteId',
    );
    _invalidateQuoteCaches(quoteId);
    return result;
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
        // Converting flips the quote to "converted" — drop its detail cache.
        _invalidateQuoteCaches(quoteId);
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
