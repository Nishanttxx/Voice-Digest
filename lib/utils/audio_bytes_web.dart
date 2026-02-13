import 'dart:typed_data';
import 'dart:html' as html;

Future<Uint8List> readAudioBytesImpl(String path) async {
  final response = await html.HttpRequest.request(
    path,
    responseType: 'arraybuffer',
  );
  final data = response.response;
  if (data is ByteBuffer) {
    return data.asUint8List();
  }
  throw StateError('Unsupported audio response type.');
}
