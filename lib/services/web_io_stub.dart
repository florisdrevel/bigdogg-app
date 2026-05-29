import 'package:file_picker/file_picker.dart';
// image_picker exports its own `PickedFile` class — hide it so our local
// model (web_io_types.PickedFile) stays unambiguous.
import 'package:image_picker/image_picker.dart' hide PickedFile;
import 'web_io_types.dart';
export 'web_io_types.dart';

// Native (Android / iOS / desktop) implementation of pickFiles. Web has
// its own copy in web_io_web.dart that uses dart:html.
//
// Routing:
//   - camera=true → image_picker camera capture (mobile only)
//   - accept hints PDF → file_picker (the only way to grab PDFs on
//     mobile without dragging in a heavier dependency)
//   - otherwise → file_picker (handles images, PDFs, anything else)

String getUserAgent() => '';

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
