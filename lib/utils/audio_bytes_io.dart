import 'dart:io';
import 'dart:typed_data';

Future<Uint8List> readAudioBytesImpl(String path) {
  return File(path).readAsBytes();
}
