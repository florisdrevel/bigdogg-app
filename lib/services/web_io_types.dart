import 'dart:typed_data';

class PickedFile {
  final String name;
  final Uint8List bytes;
  const PickedFile({required this.name, required this.bytes});
}
