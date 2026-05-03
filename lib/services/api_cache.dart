import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tiny offline read-cache for service calls.
///
/// Pattern:
///   final result = await ApiCache.read(
///     key: 'invoices_list',
///     fetcher: () => _doActualHttpGet(),
///   );
///
/// Behavior:
///   * Successful network response (`success: true`) → save JSON to
///     SharedPreferences, return as-is, mark online.
///   * Network error / timeout / non-success status → return last cached
///     JSON tagged with `from_cache: true` and `cached_at: <ms>`. If no
///     cache exists yet, return `{success: false, message: 'offline'}` so
///     existing error-handling code paths still work.
///   * `OfflineState` is updated so the dashboard can show an "Offline"
///     pill globally.
///
/// Writes are NOT cached — the user already gets a clean error if they
/// try to create something while offline.
class ApiCache {
  static const Duration _timeout = Duration(seconds: 6);

  static Future<Map<String, dynamic>> read({
    required String key,
    required Future<Map<String, dynamic>> Function() fetcher,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final result = await fetcher().timeout(_timeout);
      if (result['success'] == true) {
        await prefs.setString('cache:$key', jsonEncode(result));
        await prefs.setInt(
            'cache:$key:ts', DateTime.now().millisecondsSinceEpoch);
        OfflineState.instance.setOffline(false);
      }
      return result;
    } catch (_) {
      final cached = prefs.getString('cache:$key');
      OfflineState.instance.setOffline(true);
      if (cached != null) {
        try {
          final parsed =
              Map<String, dynamic>.from(jsonDecode(cached) as Map);
          parsed['from_cache'] = true;
          final ts = prefs.getInt('cache:$key:ts');
          if (ts != null) parsed['cached_at'] = ts;
          return parsed;
        } catch (_) {/* fall through to offline shape */}
      }
      return {'success': false, 'message': 'offline'};
    }
  }

  /// Wipe every cache entry. Call from logout to avoid leaking
  /// previous-user data into a fresh session.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final toRemove = prefs
        .getKeys()
        .where((k) => k.startsWith('cache:'))
        .toList(growable: false);
    for (final k in toRemove) {
      await prefs.remove(k);
    }
    OfflineState.instance.setOffline(false);
  }
}

/// Global "are we currently offline?" flag. Listenable so the dashboard
/// can render an Offline pill that flips automatically when the next
/// successful fetch comes back.
class OfflineState extends ChangeNotifier {
  static final OfflineState instance = OfflineState._();
  OfflineState._();

  bool _offline = false;
  bool get offline => _offline;

  void setOffline(bool v) {
    if (_offline == v) return;
    _offline = v;
    notifyListeners();
  }
}
