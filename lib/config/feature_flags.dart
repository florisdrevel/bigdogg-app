import 'package:flutter/foundation.dart' show kIsWeb;

/// True when the current build must hide all in-app subscribe CTAs and
/// pricing — i.e. ANY native build (iOS + Android).
///
/// Why both platforms now:
///
///   * Apple App Store (Guideline 3.1.1 / 3.1.3) still penalises
///     "steering" users to outside payment for digital subscriptions.
///   * Google Play Developer Policy requires Play Billing for digital
///     subscriptions in apps distributed via the Play Store, except in
///     EU/EEA/UK/India where alternative billing is permitted under DMA.
///
/// To avoid paying 15–30% to either store, the native app shows zero
/// pricing, zero "Subscribe" CTAs, and only directs users to
/// bigdogg.nl in their default external browser to manage their
/// account. All marketing and subscription flow lives on the web.
///
/// Web build is unchanged — full conversion-focused chooser, Stripe
/// Checkout directly, no platform fees because no app store is involved.
bool get kIsReaderMode {
  if (kIsWeb) return false;
  return true;
}
