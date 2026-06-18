import 'dart:async';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'web_io_types.dart';
export 'web_io_types.dart';

String getUserAgent() => html.window.navigator.userAgent;

/// Trigger a browser download of in-memory bytes (e.g. a PDF fetched from
/// the backend). Web-only; the native stub is a no-op.
void downloadBytes(String filename, Uint8List bytes,
    {String mimeType = 'application/octet-stream'}) {
  final blob = html.Blob(<Uint8List>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}

/// Web: open the PDF in a new browser tab for viewing. (On web, callers
/// normally hand off to launchUrl before reaching this; kept for parity.)
Future<void> openPdfFile(String filename, Uint8List bytes) async {
  final blob = html.Blob(<Uint8List>[bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
}

Future<List<PickedFile>?> pickFiles({
  bool camera = false,
  String accept = '*/*',
  bool multiple = false,
}) async {
  final completer = Completer<List<PickedFile>?>();
  final input = html.FileUploadInputElement();
  input.accept = accept;
  if (camera) input.setAttribute('capture', 'environment');
  input.multiple = multiple;
  input.click();
  input.onChange.listen((_) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    final result = <PickedFile>[];
    for (final file in files) {
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;
      result.add(PickedFile(
        name: file.name,
        bytes: Uint8List.fromList(reader.result as List<int>),
      ));
    }
    completer.complete(result);
  });
  return completer.future;
}
