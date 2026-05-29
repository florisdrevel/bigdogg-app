import 'dart:async';

/// Tiny in-memory TTL cache with stale-while-revalidate helpers.
///
/// Separate from `ApiCache` (which is a disk offline-fallback) — this
/// one is RAM-only, lives until app restart or explicit invalidate, and
/// is meant to make repeat screen visits feel instant.
///
/// Pattern:
///   final cached = MemCache.read<List<dynamic>>('invoices_list');
///   if (cached != null && MemCache.isFresh('invoices_list', _ttl)) {
///     return cached;            // serve cache, no fetch
///   }
///   final fresh = await fetcher();
///   MemCache.write('invoices_list', fresh);
///   return fresh;
///
/// For the stale-while-revalidate flavor, see [readWithRefresh].
class MemCache {
  static final Map<String, _Entry> _store = {};
  // Tracks the live refresh per key so multiple screens triggering the
  // same key at once de-dupe into one network call.
  static final Map<String, Future<dynamic>> _inflight = {};

  static T? read<T>(String key) {
    final e = _store[key];
    if (e == null) return null;
    return e.value as T?;
  }

  static DateTime? cachedAt(String key) => _store[key]?.cachedAt;

  static bool isFresh(String key, Duration ttl) {
    final e = _store[key];
    if (e == null) return false;
    return DateTime.now().difference(e.cachedAt) < ttl;
  }

  static void write<T>(String key, T value) {
    _store[key] = _Entry(value, DateTime.now());
  }

  static void invalidate(String key) {
    _store.remove(key);
    _inflight.remove(key);
  }

  /// Wipe every entry whose key starts with [prefix]. Used to drop a
  /// whole family at once — e.g. invalidating all dashboard summaries
  /// after a mutation touches their underlying data.
  static void invalidatePrefix(String prefix) {
    _store.removeWhere((k, _) => k.startsWith(prefix));
    _inflight.removeWhere((k, _) => k.startsWith(prefix));
  }

  static void clearAll() {
    _store.clear();
    _inflight.clear();
  }

  /// Stale-while-revalidate orchestrator.
  ///
  /// - Cache empty → awaits the fetcher and returns its result.
  /// - Cache fresh (within [ttl]) → returns cached immediately, no fetch.
  /// - Cache stale → returns cached immediately AND kicks off a
  ///   background fetch that updates the cache. Optionally calls
  ///   [onRefreshed] when the refresh lands so the UI can rebuild.
  static Future<T> readWithRefresh<T>({
    required String key,
    required Duration ttl,
    required Future<T> Function() fetcher,
    void Function(T fresh)? onRefreshed,
    bool Function(T value)? cacheIf,
  }) async {
    final cached = read<T>(key);
    if (cached != null && isFresh(key, ttl)) {
      return cached;
    }
    if (cached != null) {
      // Stale: serve cache, refresh in background. De-dupe concurrent
      // refreshes by stashing the inflight future per key.
      if (_inflight[key] == null) {
        _inflight[key] = () async {
          try {
            final fresh = await fetcher();
            if (cacheIf == null || cacheIf(fresh)) {
              write(key, fresh);
              onRefreshed?.call(fresh);
            }
            return fresh;
          } finally {
            _inflight.remove(key);
          }
        }();
      }
      return cached;
    }
    // Cold cache — await the fetcher.
    final fresh = await fetcher();
    if (cacheIf == null || cacheIf(fresh)) {
      write(key, fresh);
    }
    return fresh;
  }
}

class _Entry {
  final dynamic value;
  final DateTime cachedAt;
  _Entry(this.value, this.cachedAt);
}
