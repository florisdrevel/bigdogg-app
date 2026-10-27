import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';
import 'auth_service.dart';

/// Product groups: saved, named bundles of products you can drop onto an
/// invoice in one tap, then fill in quantities. Backed by
/// /api/v1/product-groups.
class ProductGroupsService {
  static const String baseUrl = ApiConfig.baseUrl;

  static Future<String?> _getToken() async {
    await AuthService.refreshTokenIfNeeded();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Map<String, String> _headers(String? token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  /// Each group: { id, name, items: [{ product_id, name, unit_price,
  /// btw_rate, unit, default_quantity }] }.
  static Future<Map<String, dynamic>> getGroups() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/api/v1/product-groups/'),
        headers: _headers(token),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'groups': data['groups'] ?? []};
      }
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  /// [items] is a list of { 'product_id': String, 'default_quantity': num }.
  static Future<Map<String, dynamic>> createGroup({
    required String name,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/api/v1/product-groups/'),
        headers: _headers(token),
        body: jsonEncode({'name': name, 'items': items}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'group': data['group']};
      }
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  static Future<Map<String, dynamic>> updateGroup({
    required String groupId,
    String? name,
    List<Map<String, dynamic>>? items,
  }) async {
    try {
      final token = await _getToken();
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (items != null) body['items'] = items;
      final response = await http.put(
        Uri.parse('$baseUrl/api/v1/product-groups/$groupId'),
        headers: _headers(token),
        body: jsonEncode(body),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'group': data['group']};
      }
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  static Future<Map<String, dynamic>> deleteGroup(String groupId) async {
    try {
      final token = await _getToken();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/v1/product-groups/$groupId'),
        headers: _headers(token),
      );
      if (response.statusCode == 200) {
        return {'success': true};
      }
      final data = jsonDecode(response.body);
      return {'success': false, 'message': data['detail']};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }
}
