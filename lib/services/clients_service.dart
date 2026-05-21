import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'api_cache.dart';
import 'auth_service.dart';
import 'offline_queue.dart';

class ClientsService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<String?> _getToken() async {
    await AuthService.refreshTokenIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<Map<String, dynamic>> getClients() async {
    return ApiCache.read(
      key: 'clients_list',
      fetcher: () async {
        final token = await _getToken();
        final response = await http.get(
          Uri.parse('$baseUrl/api/v1/clients/'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
        final data = jsonDecode(response.body);
        if (response.statusCode == 200) {
          return {'success': true, 'clients': data['clients']};
        }
        return {'success': false, 'message': data['detail']};
      },
    );
  }

  static Future<Map<String, dynamic>> createClient({
    required String contactName,
    required String email,
    String? companyName,
    String? phone,
    String? address,
    String? postcode,
    String? city,
    String? btwNumber,
    String? kvkNumber,
  }) async {
    final token = await _getToken();
    return OfflineQueue.postOrEnqueue(
      url: '$baseUrl/api/v1/clients/',
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: {
        'contact_name': contactName,
        'email': email,
        'company_name': companyName,
        'phone': phone,
        'address': address,
        'postcode': postcode,
        'city': city,
        'btw_number': btwNumber,
        'kvk_number': kvkNumber,
      },
      label: 'Klant: $contactName',
    );
  }

  static Future<Map<String, dynamic>> updateClient({
    required String clientId,
    String? contactName,
    String? email,
    String? companyName,
    String? phone,
    String? address,
    String? postcode,
    String? city,
    String? btwNumber,
    String? kvkNumber,
  }) async {
    final token = await _getToken();
    return OfflineQueue.putOrEnqueue(
      url: '$baseUrl/api/v1/clients/$clientId',
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: {
        'contact_name': contactName,
        'email': email,
        'company_name': companyName,
        'phone': phone,
        'address': address,
        'postcode': postcode,
        'city': city,
        'btw_number': btwNumber,
        'kvk_number': kvkNumber,
      },
      label: 'Klant bijwerken: ${contactName ?? clientId}',
    );
  }

  static Future<Map<String, dynamic>> deleteClient(String clientId) async {
    final token = await _getToken();
    return OfflineQueue.deleteOrEnqueue(
      url: '$baseUrl/api/v1/clients/$clientId',
      headers: {'Authorization': 'Bearer $token'},
      label: 'Klant verwijderen: $clientId',
    );
  }

  static Future<Map<String, dynamic>> createInvite() async {
    final token = await _getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/clients/invite'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // No clipboard here — handled in UI on user tap
        return {'success': true, 'invite_url': data['invite_url']};
      }
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  static Future<Map<String, dynamic>> validateInvite(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/clients/onboarding/$token'),
      );
      final data = jsonDecode(response.body);
      return {'success': true, 'valid': data['valid']};
    } catch (e) {
      return {'success': false, 'valid': false};
    }
  }

  static Future<Map<String, dynamic>> completeOnboarding({
    required String token,
    required String contactName,
    required String email,
    String? companyName,
    String? phone,
    String? address,
    String? postcode,
    String? city,
    String? btwNumber,
    String? kvkNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/clients/onboarding/$token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contact_name': contactName,
          'email': email,
          'company_name': companyName,
          'phone': phone,
          'address': address,
          'postcode': postcode,
          'city': city,
          'btw_number': btwNumber,
          'kvk_number': kvkNumber,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }
}