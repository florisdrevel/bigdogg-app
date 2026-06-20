import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Hive-backed persistent cache for the four data sets that drive the
/// app's main screens. Survives restarts, keeps the app usable in
/// read-only mode without internet.
///
/// Everything is stored as a JSON string keyed by name — no Hive type
/// adapters, no codegen, no schema migrations to babysit. Each data
/// type also gets a `<key>:ts` ISO-8601 string holding the last
/// successful network sync timestamp, used by the offline banner and
/// the Settings "last synced" row.
///
/// Keys in use: 'invoices', 'expenses', 'dashboard', 'clients', 'hours',
/// 'trips', 'products', 'projects', 'investments'. (`oldestLastSync()`
/// only tracks the original four for the Settings "last synced" row.)
class LocalStorageService {
  static const String _boxName = 'bigdogg_cache';
  static Box<String>? _box;

  /// Call once from main() before runApp. Idempotent.
  static Future<void> init() async {
    if (_box != null) return;
    await Hive.initFlutter();
    _box = await Hive.openBox<String>(_boxName);
  }

  /// jsonEncode the value and write under [key]. Accepts anything
  /// jsonEncode can handle (Map / List / primitives). Throws if a
  /// non-encodable value is passed — that's a programmer error and we
  /// want to find it loudly.
  static Future<void> save(String key, dynamic data) async {
    final box = _requireBox();
    await box.put(key, jsonEncode(data));
  }

  /// Returns the decoded value (Map / List / primitive) or null if no
  /// entry exists or the stored payload is corrupt.
  static dynamic get(String key) {
    final box = _box;
    if (box == null) return null;
    final raw = box.get(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      // Corrupt entry — pretend it isn't there so the screen falls
      // back to its empty state and re-fetches.
      return null;
    }
  }

  static Future<void> remove(String key) async {
    final box = _box;
    if (box == null) return;
    await box.delete(key);
    await box.delete('$key:ts');
  }

  static Future<void> saveLastSync(String key, DateTime time) async {
    final box = _requireBox();
    await box.put('$key:ts', time.toUtc().toIso8601String());
  }

  static DateTime? getLastSync(String key) {
    final box = _box;
    if (box == null) return null;
    final raw = box.get('$key:ts');
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  /// Returns the OLDEST lastSync across the known data keys, or null if
  /// nothing has synced yet. Used by Settings → "Last synced" row to
  /// give the user a worst-case view of cache freshness.
  static DateTime? oldestLastSync() {
    const keys = ['invoices', 'expenses', 'dashboard', 'clients'];
    DateTime? oldest;
    for (final k in keys) {
      final t = getLastSync(k);
      if (t == null) continue;
      if (oldest == null || t.isBefore(oldest)) oldest = t;
    }
    return oldest;
  }

  /// Wipe everything. Called from logout — never leave one user's
  /// financial data accessible to the next person who opens the app.
  static Future<void> clearAll() async {
    final box = _box;
    if (box == null) return;
    await box.clear();
  }

  static Box<String> _requireBox() {
    final b = _box;
    if (b == null) {
      throw StateError(
          'LocalStorageService.init() must be called before use.');
    }
    return b;
  }
}
