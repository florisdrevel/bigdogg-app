import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'api_cache.dart';

class ProfileService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<Map<String, dynamic>> getProfile() async {
    return ApiCache.read(
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
    String? language,
    bool? onboardingComplete,
    String? invoicePrimaryColor,
    String? invoiceAccentColor,
  }) async {
    final token = await _getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/profile/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'business_name': businessName,
          'full_name': fullName,
          'address': address,
          'postcode': postcode,
          'city': city,
          'country': country,
          'kvk_number': kvkNumber,
          'btw_number': btwNumber,
          'iban': iban,
          'language': language,
          'onboarding_complete': onboardingComplete,
          'invoice_primary_color': invoicePrimaryColor,
          'invoice_accent_color': invoiceAccentColor,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'profile': data['profile']};
      }
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
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
        return {'success': true, 'logo_url': data['logo_url']};
      }
      return {'success': false, 'message': data['detail'] ?? 'Upload failed'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }
}