import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

/// Owner-side and accountant-side endpoints around the read-only
/// accountant portal.
///
/// Owner perspective: invite an accountant by email, list pending
/// invites, list active accountants, revoke. Accountant perspective:
/// accept an invite token after signing in, list every BigDogg user
/// that has linked them.
class AccountantsService {
  static const String _base = '${ApiConfig.baseUrl}/api/v1/accountants';

  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Owner ─────────────────────────────────────────────────

  /// Returns `{ok, error?, accept_url?}`. Backend sends the email.
  static Future<Map<String, dynamic>> invite(String email) async {
    try {
      final r = await http.post(
        Uri.parse('$_base/invite'),
        headers: await _headers(),
        body: jsonEncode({'email': email}),
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        return {'ok': true, 'accept_url': data['accept_url']};
      }
      String detail = 'invite_failed';
      try {
        detail = (jsonDecode(r.body) as Map)['detail']?.toString() ?? detail;
      } catch (_) {}
      return {'ok': false, 'error': detail};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  static Future<List<Map<String, dynamic>>> listInvites() async {
    try {
      final r = await http.get(Uri.parse('$_base/invites'),
          headers: await _headers());
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        final raw = (data['invites'] as List?) ?? [];
        return raw.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> cancelInvite(String token) async {
    try {
      final r = await http.delete(Uri.parse('$_base/invites/$token'),
          headers: await _headers());
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> listActive() async {
    try {
      final r = await http.get(Uri.parse('$_base/'),
          headers: await _headers());
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        final raw = (data['accountants'] as List?) ?? [];
        return raw.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> revoke(String accountantId) async {
    try {
      final r = await http.delete(Uri.parse('$_base/$accountantId'),
          headers: await _headers());
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Accountant ────────────────────────────────────────────

  /// Returns `{ok, error?, owner_id?}`.
  static Future<Map<String, dynamic>> acceptInvite(String token) async {
    try {
      final r = await http.post(
        Uri.parse('$_base/accept-invite/$token'),
        headers: await _headers(),
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        return {'ok': true, 'owner_id': data['owner_id']};
      }
      String detail = 'accept_failed';
      try {
        detail = (jsonDecode(r.body) as Map)['detail']?.toString() ?? detail;
      } catch (_) {}
      return {'ok': false, 'error': detail};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  static Future<List<Map<String, dynamic>>> listClients() async {
    try {
      final r = await http.get(Uri.parse('$_base/clients'),
          headers: await _headers());
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        final raw = (data['clients'] as List?) ?? [];
        return raw.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> clientInvoices(String userId) async {
    try {
      final r = await http.get(
          Uri.parse('$_base/clients/$userId/invoices'),
          headers: await _headers());
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        return ((data['invoices'] as List?) ?? [])
            .cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> clientExpenses(String userId) async {
    try {
      final r = await http.get(
          Uri.parse('$_base/clients/$userId/expenses'),
          headers: await _headers());
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        return ((data['expenses'] as List?) ?? [])
            .cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>?> clientOverview(String userId) async {
    try {
      final r = await http.get(
          Uri.parse('$_base/clients/$userId/overview'),
          headers: await _headers());
      if (r.statusCode == 200) {
        return jsonDecode(r.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}
