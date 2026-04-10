import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'api_config.dart';

class ClientsService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<Map<String, dynamic>> getClients() async {
    final token = await _getToken();
    try {
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
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  static Future<Map<String, dynamic>> createClient({
    required String contactName,
    required String email,
    String? companyName,
    String? phone,
    String? address,
    String? postcode,
    String? city,
  }) async {
    final token = await _getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/clients/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contact_name': contactName,
          'email': email,
          'company_name': companyName,
          'phone': phone,
          'address': address,
          'postcode': postcode,
          'city': city,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'client': data['client']};
      }
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
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
  }) async {
    final token = await _getToken();
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/v1/clients/$clientId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contact_name': contactName,
          'email': email,
          'company_name': companyName,
          'phone': phone,
          'address': address,
          'postcode': postcode,
          'city': city,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'client': data['client']};
      }
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  static Future<Map<String, dynamic>> deleteClient(String clientId) async {
    final token = await _getToken();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/v1/clients/$clientId'),
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

  static Future<Map<String, dynamic>> createInvite() async {
    final token = await _getToken();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/clients/invite'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await Clipboard.setData(ClipboardData(text: data['invite_url']));
        return {'success': true, 'invite_url': data['invite_url']};
      }
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }
}