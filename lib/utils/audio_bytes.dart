import 'dart:typed_data';

import 'audio_bytes_stub.dart'
    if (dart.library.io) 'audio_bytes_io.dart'
    if (dart.library.html) 'audio_bytes_web.dart';

Future<Uint8List> readAudioBytes(String path) {
  return readAudioBytesImpl(path);
}
