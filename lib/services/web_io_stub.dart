import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
// image_picker exports its own `PickedFile` class — hide it so our local
// model (web_io_types.PickedFile) stays unambiguous.
import 'package:image_picker/image_picker.dart' hide PickedFile;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'web_io_types.dart';
export 'web_io_types.dart';

// Native (Android/iOS) implementation: open the system share sheet so the
// user can save the PDF report to Files, email it, etc. Web has its own
// copy in web_io_web.dart that triggers an in-browser download.
void downloadBytes(String filename, Uint8List bytes,
    {String mimeType = 'application/octet-stream'}) {
  unawaited(Printing.sharePdf(bytes: bytes, filename: filename));
}

// Native: write the PDF to a temp file and OPEN it in the device's default
// viewer (ACTION_VIEW) — so the user sees the document, not a share sheet.
// Falls back to the share sheet only if no viewer app is available. Web has
// its own copy that opens the PDF in a new browser tab.
Future<void> openPdfFile(String filename, Uint8List bytes) async {
  try {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$filename';
    await File(path).writeAsBytes(bytes, flush: true);
    final result = await OpenFilex.open(path, type: 'application/pdf');
    if (result.type != ResultType.done) {
      unawaited(Printing.sharePdf(bytes: bytes, filename: filename));
    }
  } catch (_) {
    unawaited(Printing.sharePdf(bytes: bytes, filename: filename));
  }
}

// Native (Android / iOS / desktop) implementation of pickFiles. Web has
// its own copy in web_io_web.dart that uses dart:html.
//
// Routing:
//   - camera=true → image_picker camera capture (mobile only)
//   - accept hints PDF → file_picker (the only way to grab PDFs on
//     mobile without dragging in a heavier dependency)
//   - otherwise → file_picker (handles images, PDFs, anything else)

String getUserAgent() => '';

// Native builds are already an installed app — nothing to nudge.
bool isStandaloneWebApp() => true;

Future<List<PickedFile>?> pickFiles({
  bool camera = false,
  String accept = '*/*',
  bool multiple = false,
}) async {
  if (camera) {
    final picker = ImagePicker();
    final shot = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (shot == null) return null;
    final bytes = await shot.readAsBytes();
    return [PickedFile(name: shot.name, bytes: bytes)];
  }

  final acceptLower = accept.toLowerCase();
  final pdfOnly =
      acceptLower.contains('pdf') && !acceptLower.contains('image');

  final result = await FilePicker.platform.pickFiles(
    type: pdfOnly ? FileType.custom : FileType.any,
    allowedExtensions: pdfOnly ? const ['pdf'] : null,
    allowMultiple: multiple,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  return [
    for (final f in result.files)
      if (f.bytes != null) PickedFile(name: f.name, bytes: f.bytes!),
  ];
}
