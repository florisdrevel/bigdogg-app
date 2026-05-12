import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

/// Owner-side: create / list / revoke / extend access links.
/// Accountant-side: token-gated public portal endpoints — no auth header,
/// the URL token is the credential.
class AccountantsService {
  static const String _base = '${ApiConfig.baseUrl}/api/v1/accountants';

  static Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static const Map<String, String> _publicHeaders = {
    'Content-Type': 'application/json',
  };

  // ── Owner ─────────────────────────────────────────────────

  /// Create a new access link. Returns `{ok, error?, accept_url?, email_sent?, email_error?}`.
  static Future<Map<String, dynamic>> invite(String email) async {
    try {
      final r = await http.post(
        Uri.parse('$_base/invite'),
        headers: await _authHeaders(),
        body: jsonEncode({'email': email}),
      );
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        return {
          'ok':          true,
          'accept_url':  data['accept_url'],
          'token':       data['token'],
          'email_sent':  data['email_sent'] == true,
          'email_error': data['email_error'],
        };
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

  /// List every link this owner has ever created (active, revoked, expired).
  static Future<List<Map<String, dynamic>>> listInvites() async {
    try {
      final r = await http.get(Uri.parse('$_base/invites'),
          headers: await _authHeaders());
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        return ((data['invites'] as List?) ?? [])
            .cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  /// Soft-revoke: marks the link as used so the token can never be opened
  /// again. The portal endpoints return 403 link_revoked.
  static Future<bool> cancelInvite(String token) async {
    try {
      final r = await http.delete(Uri.parse('$_base/invites/$token'),
          headers: await _authHeaders());
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Bump expiry +14 days from now.
  static Future<bool> extendInvite(String token) async {
    try {
      final r = await http.post(Uri.parse('$_base/invites/$token/extend'),
          headers: await _authHeaders());
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Accountant portal — token-gated, public ───────────────

  static Uri _portal(String token, [String? sub]) =>
      Uri.parse('$_base/portal/$token${sub == null ? '' : '/$sub'}');

  /// Returns `{ok, status?, error?, meta?}`. status mirrors HTTP code so
  /// the screen can render "link expired" / "link revoked" / "not found".
  static Future<Map<String, dynamic>> portalMeta(String token) async {
    try {
      final r = await http.get(_portal(token), headers: _publicHeaders);
      if (r.statusCode == 200) {
        return {'ok': true, 'meta': jsonDecode(r.body) as Map<String, dynamic>};
      }
      String detail = 'lookup_failed';
      try {
        detail = (jsonDecode(r.body) as Map)['detail']?.toString() ?? detail;
      } catch (_) {}
      return {'ok': false, 'status': r.statusCode, 'error': detail};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>?> portalOverview(String token) async {
    try {
      final r = await http.get(_portal(token, 'overview'),
          headers: _publicHeaders);
      if (r.statusCode == 200) {
        return jsonDecode(r.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  static Future<List<Map<String, dynamic>>> portalInvoices(String token) async {
    try {
      final r = await http.get(_portal(token, 'invoices'),
          headers: _publicHeaders);
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        return ((data['invoices'] as List?) ?? [])
            .cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> portalExpenses(String token) async {
    try {
      final r = await http.get(_portal(token, 'expenses'),
          headers: _publicHeaders);
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        return ((data['expenses'] as List?) ?? [])
            .cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  /// Returns the full URL the device should open in a browser to download
  /// the invoice PDF. We let the browser/OS handle the download since
  /// streaming bytes through Flutter on web is awkward.
  static String portalInvoicePdfUrl(String token, String invoiceId) =>
      '$_base/portal/$token/invoices/$invoiceId/pdf';
}
