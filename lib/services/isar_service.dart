import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:voice_digest/models/voice_digest.dart';

class IsarService {
  late Future<Isar> db;

  IsarService() {
    db = openDB();
  }

  Future<Isar> openDB() async {
    if (Isar.instanceNames.isEmpty) {
      final dir = await getApplicationDocumentsDirectory();
      return await Isar.open(
        [VoiceDigestSchema],
        directory: dir.path,
        inspector: true, // Allows you to inspect the database in debug mode
      );
    }
    return Future.value(Isar.getInstance());
  }

  Future<void> saveDigest(VoiceDigest newDigest) async {
    final isar = await db;
    isar.writeTxnSync<int>(() => isar.voiceDigests.putSync(newDigest));
  }

  Future<List<VoiceDigest>> getAllDigests() async {
    final isar = await db;
    return await isar.voiceDigests.where().sortByCreatedAtDesc().findAll();
  }

  Future<void> deleteDigest(int id) async {
    final isar = await db;
    await isar.writeTxn(() async {
      await isar.voiceDigests.delete(id);
    });
  }
}
