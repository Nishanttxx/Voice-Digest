import 'package:isar/isar.dart';

part 'voice_digest.g.dart';

@collection
class VoiceDigest {
  Id id = Isar.autoIncrement; // you can also use id = null to auto increment

  late String originalTranscript;
  late String translatedText;
  late String sourceLanguage;
  late String targetLanguage;
  late DateTime createdAt;
}
