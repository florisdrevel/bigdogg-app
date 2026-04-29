// Conditional import shim — picks the web implementation when dart:html is
// available (Flutter web), otherwise the stub (Android, iOS, desktop).
export 'web_io_stub.dart' if (dart.library.html) 'web_io_web.dart';
