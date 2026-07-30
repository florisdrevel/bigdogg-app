import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/web_io.dart';
import '../theme.dart';

/// Nudges iOS/iPadOS web visitors to install BigDogg via "Add to Home
/// Screen" — the App Store rejected native iOS distribution under
/// Guideline 3.1.1 (subscription content must be sellable via IAP, and this
/// app doesn't qualify for the reader-app exception), so the installable
/// PWA is the actual iOS distribution channel. Safari never fires an
/// automatic install prompt the way Android/Chrome do, so without this
/// banner iOS users would have no way to discover the option.
///
/// Dismissal is session-only (in-memory), never persisted — this
/// project's hard rule bans localStorage/sessionStorage in Flutter code.
class IosInstallBanner extends StatefulWidget {
  final bool isNl;
  const IosInstallBanner({super.key, required this.isNl});

  static bool shouldShow() {
    if (!kIsWeb) return false;
    if (isStandaloneWebApp()) return false;
    final ua = getUserAgent();
    return ua.contains('iPhone') || ua.contains('iPad') || ua.contains('iPod');
  }

  @override
  State<IosInstallBanner> createState() => _IosInstallBannerState();
}

class _IosInstallBannerState extends State<IosInstallBanner> {
  bool _dismissed = false;

  // Only Safari can act on the "tap Share, then Add to Home Screen"
  // instructions — Chrome/Firefox/Edge on iOS are all forced to use
  // Apple's WebKit under the hood but don't expose that install path.
  bool get _isSafari {
    final ua = getUserAgent();
    return ua.contains('Safari') &&
        !ua.contains('CriOS') &&
        !ua.contains('FxiOS') &&
        !ua.contains('EdgiOS');
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || !IosInstallBanner.shouldShow()) {
      return const SizedBox.shrink();
    }
    final isNl = widget.isNl;
    final message = _isSafari
        ? (isNl
            ? 'Zet BigDogg op je beginscherm: tik op het deel-icoon onderin Safari, kies daarna "Zet op beginscherm".'
            : 'Add BigDogg to your home screen: tap the Share icon in Safari, then "Add to Home Screen".')
        : (isNl
            ? 'Open deze pagina in Safari om BigDogg als app te installeren.'
            : 'Open this page in Safari to install BigDogg as an app.');

    return Material(
      color: BigDoggTheme.teal800,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.ios_share_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.3),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: Colors.white70, size: 18),
                onPressed: () => setState(() => _dismissed = true),
                splashRadius: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
