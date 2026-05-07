import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight offline-write outbox.
///
/// When the user creates / edits / deletes something while the app
/// has no network, the call throws on `http.post/put/delete`. Rather
/// than surfacing a "Connection error" toast and silently dropping the
/// data, we enqueue the request locally and replay it the next time
/// the device is online.
///
/// Storage: a JSON array of `_QueuedRequest` objects in
/// SharedPreferences under `offline_queue_v1`. We chose SharedPrefs
/// over SQLite to keep the dep tree small — for the volumes a ZZP
/// produces in a typical offline window (a few minutes on a train),
/// JSON in prefs is more than enough.
///
/// This v1 deliberately doesn't try to mirror the entity in any local
/// list so the user can "see it appear immediately". That requires
/// per-entity caches and temp-ID swapping; we'll add it in v2 once we
/// observe how often this queue actually gets used.
class OfflineQueue {
  static const String _prefsKey = 'offline_queue_v1';

  static bool _draining = false;

  // ─── Storage ──────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> _read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _write(List<Map<String, dynamic>> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(queue));
  }

  /// Number of pending requests. UI uses this for a small badge.
  static Future<int> count() async => (await _read()).length;

  /// Wipe — used when the user logs out so a different user doesn't
  /// inherit the previous user's pending writes.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  // ─── Public API ───────────────────────────────────────────

  /// Enqueue a request for later replay. `label` is the human-readable
  /// description shown in the offline snackbar / pending list.
  static Future<void> enqueue({
    required String method,
    required String url,
    required String label,
    Map<String, String>? headers,
    Object? body,
  }) async {
    final queue = await _read();
    queue.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'method': method.toUpperCase(),
      'url': url,
      'label': label,
      'headers': headers ?? {},
      'body': body == null ? null : (body is String ? body : jsonEncode(body)),
      'enqueued_at': DateTime.now().toIso8601String(),
    });
    await _write(queue);
  }

  /// Replay every pending request. Stops early if a replay errors out
  /// — most likely the device is still offline. Successful items are
  /// removed from the queue immediately so a partial drain doesn't
  /// duplicate work on the next try.
  ///
  /// Returns the count of successful replays.
  static Future<int> drain() async {
    if (_draining) return 0;
    _draining = true;
    try {
      var queue = await _read();
      if (queue.isEmpty) return 0;
      int success = 0;
      while (queue.isNotEmpty) {
        final item = queue.first;
        try {
          final ok = await _replay(item);
          if (!ok) break; // network back up but server still rejecting — stop
          queue.removeAt(0);
          await _write(queue);
          success++;
        } catch (_) {
          // Probably still offline — stop draining, keep order.
          break;
        }
      }
      return success;
    } finally {
      _draining = false;
    }
  }

  static Future<bool> _replay(Map<String, dynamic> item) async {
    final method = (item['method'] ?? 'POST') as String;
    final url = item['url'] as String;
    final headers = (item['headers'] as Map?)?.cast<String, String>() ?? {};

    // Always use the freshest access token; the one we enqueued with
    // may have expired during the offline window.
    final prefs = await SharedPreferences.getInstance();
    final liveToken = prefs.getString('access_token');
    if (liveToken != null && liveToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $liveToken';
    }

    final body = item['body'] as String?;
    final uri = Uri.parse(url);

    http.Response r;
    switch (method) {
      case 'POST':
        r = await http.post(uri, headers: headers, body: body);
        break;
      case 'PUT':
        r = await http.put(uri, headers: headers, body: body);
        break;
      case 'PATCH':
        r = await http.patch(uri, headers: headers, body: body);
        break;
      case 'DELETE':
        r = await http.delete(uri, headers: headers, body: body);
        break;
      default:
        return true; // unknown method — drop it rather than blocking the queue
    }

    // 2xx — done. 4xx — server rejected; drop it (re-replaying won't help)
    // and let the user notice the missing record. 5xx / network error —
    // replay again next time.
    if (r.statusCode >= 200 && r.statusCode < 300) return true;
    if (r.statusCode >= 400 && r.statusCode < 500) return true;
    return false;
  }

  // ─── Convenience wrapper for write services ───────────────

  /// Try a POST. On network failure, enqueue and return an "offline"
  /// shaped result so the calling service can surface the correct
  /// "saved offline" message instead of a generic error.
  static Future<Map<String, dynamic>> postOrEnqueue({
    required String url,
    required Map<String, String> headers,
    required Object body,
    required String label,
  }) async {
    try {
      final r = await http.post(Uri.parse(url),
          headers: headers, body: body is String ? body : jsonEncode(body));
      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(r.body) as Map<String, dynamic>;
      } catch (_) {}
      if (r.statusCode >= 200 && r.statusCode < 300) {
        return {'success': true, ...data};
      }
      return {
        'success': false,
        'message': data['detail']?.toString() ?? 'Server error',
      };
    } catch (_) {
      await enqueue(method: 'POST', url: url, headers: headers,
          body: body, label: label);
      return {'success': true, 'offline': true, 'queued_label': label};
    }
  }
}
