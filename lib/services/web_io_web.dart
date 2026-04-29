import 'dart:async';
import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'web_io_types.dart';
export 'web_io_types.dart';

String getUserAgent() => html.window.navigator.userAgent;

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
