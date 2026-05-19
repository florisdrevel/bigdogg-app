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

  static Future<bool> cancelInvite(String token) async {
    try {
      final r = await http.delete(Uri.parse('$_base/invites/$token'),
          headers: await _authHeaders());
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

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

  static Uri _portal(String token, [String? sub, Map<String, String>? query]) {
    final base = '$_base/portal/$token${sub == null ? '' : '/$sub'}';
    final uri = Uri.parse(base);
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }

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

  static Future<List<int>> portalYears(String token) async {
    try {
      final r = await http.get(_portal(token, 'years'),
          headers: _publicHeaders);
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        return ((data['years'] as List?) ?? [])
            .map((e) => (e as num).toInt())
            .toList();
      }
    } catch (_) {}
    return [DateTime.now().year];
  }

  static Future<Map<String, dynamic>?> portalOverview(
      String token, int year) async {
    try {
      final r = await http.get(
          _portal(token, 'overview', {'year': '$year'}),
          headers: _publicHeaders);
      if (r.statusCode == 200) {
        return jsonDecode(r.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  static Future<List<Map<String, dynamic>>> portalInvoices(
      String token, int year) async {
    try {
      final r = await http.get(
          _portal(token, 'invoices', {'year': '$year'}),
          headers: _publicHeaders);
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        return ((data['invoices'] as List?) ?? [])
            .cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> portalExpenses(
      String token, int year) async {
    try {
      final r = await http.get(
          _portal(token, 'expenses', {'year': '$year'}),
          headers: _publicHeaders);
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        return ((data['expenses'] as List?) ?? [])
            .cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>?> portalInvestments(
      String token, int year) async {
    try {
      final r = await http.get(
          _portal(token, 'investments', {'year': '$year'}),
          headers: _publicHeaders);
      if (r.statusCode == 200) {
        return jsonDecode(r.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> portalHours(
      String token, int year) async {
    try {
      final r = await http.get(
          _portal(token, 'hours', {'year': '$year'}),
          headers: _publicHeaders);
      if (r.statusCode == 200) {
        return jsonDecode(r.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> portalAging(String token) async {
    try {
      final r = await http.get(_portal(token, 'aging'),
          headers: _publicHeaders);
      if (r.statusCode == 200) {
        return jsonDecode(r.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> portalBtwBreakdown(
      String token, int year) async {
    try {
      final r = await http.get(
          _portal(token, 'btw-breakdown', {'year': '$year'}),
          headers: _publicHeaders);
      if (r.statusCode == 200) {
        return jsonDecode(r.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  static String portalInvoicePdfUrl(String token, String invoiceId) =>
      '$_base/portal/$token/invoices/$invoiceId/pdf';

  static String portalCsvExportUrl(String token, int year) =>
      '$_base/portal/$token/export.csv?year=$year';

  /// Full annual report PDF (same one the user themselves can download —
  /// with AI tax tips). Pass `lang='nl'` or `'en'`.
  static String portalAnnualReportPdfUrl(
    String token,
    int year,
    String lang,
  ) =>
      '$_base/portal/$token/annual-report.pdf?year=$year&lang=$lang';
}
