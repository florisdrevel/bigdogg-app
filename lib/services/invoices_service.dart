import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'api_cache.dart';
import 'auth_service.dart';
import 'local_storage_service.dart';
import 'mem_cache.dart';
import 'offline_queue.dart';
import 'dart:typed_data';
import 'package:http_parser/http_parser.dart';

class InvoicesService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<String?> getToken() async {
    await AuthService.refreshTokenIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// 5-minute in-memory cache with stale-while-revalidate. The disk-
  /// cache (ApiCache) remains the offline fallback inside the fetcher.
  /// Repeat screen visits return the RAM cache instantly; the next
  /// visit after 5 minutes triggers a background refresh.
  static Future<Map<String, dynamic>> getInvoices() async {
    return MemCache.readWithRefresh<Map<String, dynamic>>(
      key: 'invoices_list',
      ttl: const Duration(minutes: 5),
      cacheIf: (v) => v['success'] == true,
      fetcher: () => ApiCache.read(
        key: 'invoices_list',
        fetcher: () async {
          final token = await getToken();
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
        },
      ),
    );
  }

  static Future<Map<String, dynamic>> createInvoice({
    required String clientId,
    required List<Map<String, dynamic>> lines,
    String? notes,
    String? projectId,
  }) async {
    final token = await getToken();
    final result = await OfflineQueue.postOrEnqueue(
      url: '$baseUrl/api/v1/invoices/',
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: {
        'client_id': clientId,
        'lines': lines,
        'notes': notes,
        if (projectId != null) 'project_id': projectId,
      },
      label: 'Factuur (${lines.length} regel${lines.length == 1 ? '' : 's'})',
    );
    _invalidateInvoiceCaches();
    return result;
  }

  /// Drop every cache touched by an invoice mutation. The list itself
  /// must reload; quarterly / annual overviews aggregate invoice totals
  /// so they're stale too. The single-invoice detail cache is dropped so
  /// the detail screen re-fetches after a status change / edit.
  static void _invalidateInvoiceCaches() {
    MemCache.invalidate('invoices_list');
    MemCache.invalidatePrefix('invoice:'); // per-invoice detail caches
    MemCache.invalidatePrefix('overview_');
    MemCache.invalidatePrefix('quarter_detail');
    // Spec: any mutation forces a fresh dashboard fetch on next load.
    LocalStorageService.remove('dashboard');
  }

  /// Synchronous peek into the in-memory cache for a single invoice. The
  /// detail screen calls this to paint instantly on a revisit (complete
  /// data we already fetched this session) before the silent background
  /// refresh lands. Returns null if not cached this session.
  static Map<String, dynamic>? peekInvoice(String invoiceId) {
    final cached = MemCache.read<Map<String, dynamic>>('invoice:$invoiceId');
    if (cached != null && cached['success'] == true) return cached;
    return null;
  }

  /// 5-minute in-memory cache with stale-while-revalidate, keyed per
  /// invoice. ApiCache stays the offline disk fallback inside the fetcher.
  /// A repeat open returns the RAM cache instantly; a stale open serves
  /// cache and refreshes in the background.
  static Future<Map<String, dynamic>> getInvoice(String invoiceId) async {
    return MemCache.readWithRefresh<Map<String, dynamic>>(
      key: 'invoice:$invoiceId',
      ttl: const Duration(minutes: 5),
      cacheIf: (v) => v['success'] == true,
      fetcher: () => ApiCache.read(
        key: 'invoice:$invoiceId',
        fetcher: () async {
          final token = await getToken();
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
              'lines': data['lines'],
            };
          }
          return {'success': false, 'message': data['detail']};
        },
      ),
    );
  }

  static Future<Map<String, dynamic>> updateStatus(
    String invoiceId,
    String status,
  ) async {
    final token = await getToken();
    final result = await OfflineQueue.patchOrEnqueue(
      url: '$baseUrl/api/v1/invoices/$invoiceId/status',
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: {'status': status},
      label: 'Factuur status → $status',
    );
    _invalidateInvoiceCaches();
    return result;
  }

  /// Flip the per-invoice "send the Stripe payment link" toggle.
  static Future<Map<String, dynamic>> setPaymentLinkEnabled(
    String invoiceId,
    bool enabled,
  ) async {
    final token = await getToken();
    return OfflineQueue.patchOrEnqueue(
      url: '$baseUrl/api/v1/invoices/$invoiceId',
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: {'payment_link_enabled': enabled},
      label: 'Factuur betaallink → ${enabled ? 'aan' : 'uit'}',
    );
  }

  static Future<Map<String, dynamic>> deleteInvoice(String invoiceId) async {
    final token = await getToken();
    final result = await OfflineQueue.deleteOrEnqueue(
      url: '$baseUrl/api/v1/invoices/$invoiceId',
      headers: {'Authorization': 'Bearer $token'},
      label: 'Factuur verwijderen: $invoiceId',
    );
    _invalidateInvoiceCaches();
    return result;
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

  static Future<Map<String, dynamic>> deleteImportedInvoice(
    String invoiceId,
  ) async {
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
    final token = await getToken();
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
