import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'api_cache.dart';
import 'auth_service.dart';
import 'mem_cache.dart';
import 'offline_queue.dart';

class ProfileService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<String?> _getToken() async {
    await AuthService.refreshTokenIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  /// Synchronous peek into the in-memory profile cache, used by the
  /// Profile screen to populate its fields instantly on a revisit before
  /// the silent background refresh lands. Null if not cached this session.
  static Map<String, dynamic>? peekProfile() {
    final cached = MemCache.read<Map<String, dynamic>>('profile');
    if (cached != null && cached['success'] == true) return cached;
    return null;
  }

  /// 5-minute in-memory cache with stale-while-revalidate. ApiCache stays
  /// the offline disk fallback inside the fetcher. Repeat opens of the
  /// Profile screen render instantly; a stale open refreshes in the
  /// background.
  static Future<Map<String, dynamic>> getProfile() async {
    return MemCache.readWithRefresh<Map<String, dynamic>>(
      key: 'profile',
      ttl: const Duration(minutes: 5),
      cacheIf: (v) => v['success'] == true,
      fetcher: () => ApiCache.read(
        key: 'profile',
        fetcher: () async {
          final token = await _getToken();
          final response = await http.get(
            Uri.parse('$baseUrl/api/v1/profile/'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          );
          final data = jsonDecode(response.body);
          if (response.statusCode == 200) {
            return {'success': true, 'profile': data['profile']};
          }
          return {'success': false, 'message': data['detail']};
        },
      ),
    );
  }

  static Future<Map<String, dynamic>> saveProfile({
    String? businessName,
    String? fullName,
    String? address,
    String? postcode,
    String? city,
    String? country,
    String? kvkNumber,
    String? btwNumber,
    String? iban,
    String? bankAccountName,
    String? language,
    bool? onboardingComplete,
    String? invoicePrimaryColor,
    String? invoiceAccentColor,
    bool? defaultExcludePaymentLink,
  }) async {
    final token = await _getToken();
    final result = await OfflineQueue.postOrEnqueue(
      url: '$baseUrl/api/v1/profile/',
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: {
        'business_name': businessName,
        'full_name': fullName,
        'address': address,
        'postcode': postcode,
        'city': city,
        'country': country,
        'kvk_number': kvkNumber,
        'btw_number': btwNumber,
        'iban': iban,
        'bank_account_name': bankAccountName,
        'language': language,
        'onboarding_complete': onboardingComplete,
        'invoice_primary_color': invoicePrimaryColor,
        'invoice_accent_color': invoiceAccentColor,
        'default_exclude_payment_link': defaultExcludePaymentLink,
      },
      label: 'Profiel bijwerken',
    );
    // Drop the cached profile so the next read reflects the edit.
    MemCache.invalidate('profile');
    return result;
  }

  static Future<Map<String, dynamic>> uploadLogo({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final token = await _getToken();
    try {
      final ext = fileName.split('.').last.toLowerCase();
      final mimeType = ext == 'png'
          ? 'image/png'
          : ext == 'jpg' || ext == 'jpeg'
              ? 'image/jpeg'
              : ext == 'webp'
                  ? 'image/webp'
                  : 'image/png';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/v1/profile/logo'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // New logo invalidates the cached profile (logo_url changed).
        MemCache.invalidate('profile');
        return {'success': true, 'logo_url': data['logo_url']};
      }
      return {'success': false, 'message': data['detail'] ?? 'Upload failed'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }
}