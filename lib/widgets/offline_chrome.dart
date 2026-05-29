import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';
import '../theme.dart';

/// 16px circular progress indicator pinned to the top-right of a
/// screen. Tells the user a background refresh is in flight without
/// blocking interaction — exactly what the spec demands instead of
/// full-screen spinners on repeat visits.
class TopRightRefreshDot extends StatelessWidget {
  final bool visible;
  final double topPadding;
  final double rightPadding;
  const TopRightRefreshDot({
    super.key,
    required this.visible,
    this.topPadding = 8,
    this.rightPadding = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Positioned(
      top: topPadding,
      right: rightPadding,
      child: const IgnorePointer(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
                AlwaysStoppedAnimation<Color>(BigDoggTheme.teal700),
          ),
        ),
      ),
    );
  }
}

/// Slim 32px banner: "Offline — gegevens van HH:mm".
///
/// Renders nothing if [lastSync] is null. Subtle grey so it doesn't
/// alarm the user — they're still seeing their data, just from a
/// snapshot.
class OfflineBanner extends StatelessWidget {
  final DateTime? lastSync;
  final bool isNl;
  const OfflineBanner({super.key, required this.lastSync, required this.isNl});

  @override
  Widget build(BuildContext context) {
    if (lastSync == null) return const SizedBox.shrink();
    final hh = lastSync!.hour.toString().padLeft(2, '0');
    final mm = lastSync!.minute.toString().padLeft(2, '0');
    final label = isNl
        ? 'Offline — gegevens van $hh:$mm'
        : 'Offline — data from $hh:$mm';
    return Container(
      width: double.infinity,
      height: 32,
      alignment: Alignment.center,
      color: const Color(0xFFEEEBE5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_outlined,
              size: 14, color: BigDoggTheme.lightTextSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: BigDoggTheme.lightTextSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Centred empty state shown only when there's no cache AND the network
/// fetch failed. Spec wording.
class OfflineEmptyState extends StatelessWidget {
  final bool isNl;
  const OfflineEmptyState({super.key, required this.isNl});

  @override
  Widget build(BuildContext context) {
    final line1 = isNl
        ? 'Nog geen offline gegevens beschikbaar'
        : 'No offline data available yet';
    final line2 = isNl
        ? 'Verbind met internet om je gegevens te laden'
        : 'Connect to the internet to load your data';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off,
                size: 56, color: BigDoggTheme.lightTextHint),
            const SizedBox(height: 16),
            Text(
              line1,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: BigDoggTheme.teal800,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              line2,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: BigDoggTheme.lightTextSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal dialog blocking create-actions when offline. Used by create
/// FAB onPressed across invoices/expenses/clients.
Future<void> showOfflineGateDialog(BuildContext context, bool isNl) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.wifi_off_rounded, color: BigDoggTheme.warning, size: 22),
          SizedBox(width: 10),
        ],
      ),
      content: Text(
        isNl
            ? 'Je bent offline\nVerbind met internet om nieuwe gegevens aan te maken.'
            : 'You\'re offline\nConnect to the internet to create new data.',
        style: const TextStyle(fontSize: 14.5, height: 1.5),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: BigDoggTheme.teal800,
            foregroundColor: Colors.white,
          ),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Convenience read for the "we're offline AND we have a cache from
/// $lastSync" predicate used by the OfflineBanner. Returns null when
/// the screen should NOT show the banner (either we're online or no
/// cache exists yet).
DateTime? offlineBannerTimestamp({
  required bool isInOfflineMode,
  required String cacheKey,
}) {
  if (!isInOfflineMode) return null;
  return LocalStorageService.getLastSync(cacheKey);
}
