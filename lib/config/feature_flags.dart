import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// True when the current build must hide all in-app subscribe CTAs and
/// pricing — i.e. Apple App Store iOS builds.
///
/// Apple App Store Guideline 3.1.1 / 3.1.3 still penalises "steering"
/// users to outside payment for digital subscriptions. Until BigDogg
/// either qualifies for the External Purchase Link Entitlement or ships
/// proper Apple In-App Purchase, iOS shows only a neutral "Manage
/// subscription on bigdogg.nl" surface — no price, no Subscribe button,
/// no upgrade copy.
///
/// Web and Android keep the conversion-focused flow.
///
/// Use `defaultTargetPlatform` rather than `dart:io` Platform so this
/// stays compile-safe on Flutter web (no `dart:io`).
bool get kIsReaderMode {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.iOS;
}
