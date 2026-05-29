import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Lightweight singleton wrapping `connectivity_plus`.
///
/// Two ways to read state:
///   - [isConnected] — broadcast Stream<bool> that emits when network
///     state flips. Use for live UI updates.
///   - [isConnectedNow] — synchronous getter for instant checks before
///     opening a create-form / submitting a mutation.
///
/// "Connected" here means "the OS reports any non-none interface".
/// We don't try to ping a real server — that would add latency and the
/// app's existing offline_queue handles actual request failures.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  bool _isConnected = true;
  final _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _initialised = false;

  /// Stream that emits every time connectivity changes. Replays the
  /// current value on subscribe so first listeners get an immediate
  /// state instead of waiting for the next OS event.
  Stream<bool> get isConnected async* {
    yield _isConnected;
    yield* _controller.stream;
  }

  bool get isConnectedNow => _isConnected;

  /// Call once from main() after LocalStorageService.init().
  static Future<void> init() => instance._init();

  Future<void> _init() async {
    if (_initialised) return;
    _initialised = true;
    final conn = Connectivity();
    try {
      final initial = await conn.checkConnectivity();
      _isConnected = _hasInterface(initial);
    } catch (_) {
      // Assume online when the platform plugin isn't available (e.g.
      // unit tests, very old web browsers). Better to attempt requests
      // and let them fail naturally than to falsely block the user.
      _isConnected = true;
    }
    _sub = conn.onConnectivityChanged.listen((results) {
      final connected = _hasInterface(results);
      if (connected != _isConnected) {
        _isConnected = connected;
        _controller.add(connected);
      }
    });
  }

  bool _hasInterface(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Tear-down hook for hot-restart / tests.
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _controller.close();
    _initialised = false;
  }
}
