import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import 'web_io.dart';

/// Single shared "download → in-app loading screen → open" flow used by EVERY
/// PDF download button in the app (invoices, quotes, VAT report, annual report).
///
/// Native (Android/iOS): show an in-app loading dialog, download the PDF bytes,
/// then hand them to the system viewer / share sheet (via [downloadBytes] →
/// Printing.sharePdf) — instead of kicking the user out to a blank browser tab.
/// Web: open in a new browser tab, which is the expected download UX there.
///
/// `url` must be a fully-authenticated PDF endpoint (token in the query string).
/// 90s timeout covers slow generation (e.g. AI tax tips on the annual report).
Future<void> openPdfInApp(
  BuildContext context, {
  required String url,
  required String filename,
  required bool isNl,
}) async {
  if (kIsWeb) {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        _error(context, isNl);
      }
    } catch (_) {
      if (context.mounted) _error(context, isNl);
    }
    return;
  }

  _showLoadingDialog(context, isNl);
  try {
    final resp =
        await http.get(Uri.parse(url)).timeout(const Duration(seconds: 90));
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
      await openPdfFile(filename, resp.bodyBytes);
    } else if (context.mounted) {
      _error(context, isNl);
    }
  } catch (_) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    if (context.mounted) _error(context, isNl);
  }
}

void _showLoadingDialog(BuildContext context, bool isNl) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor:
                    AlwaysStoppedAnimation<Color>(BigDoggTheme.teal800),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isNl ? 'PDF wordt voorbereid…' : 'Preparing your PDF…',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: BigDoggTheme.teal800,
                  fontFamily: 'PlusJakartaSans'),
            ),
            const SizedBox(height: 8),
            Text(
              isNl
                  ? 'Even geduld — de PDF opent zo automatisch.'
                  : 'One moment — the PDF will open automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.45),
            ),
          ],
        ),
      ),
    ),
  );
}

void _error(BuildContext context, bool isNl) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(isNl ? 'Kan PDF niet openen' : 'Could not open PDF'),
    backgroundColor: BigDoggTheme.error,
  ));
}
