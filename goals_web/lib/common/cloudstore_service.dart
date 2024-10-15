import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class CloudstoreService {
  final FirebaseStorage storage;
  final String userId;

  CloudstoreService({required this.storage, required this.userId});

  Future<void> saveData(String filename, ByteData data) async {
    await saveDataBytes(filename, data.buffer.asUint8List());
  }

  Future<void> saveDataBytes(String filename, Uint8List data) async {
    await storage
        .ref("user")
        .child(this.userId)
        .child("img")
        .child(filename)
        .putData(data);
  }

  Future<String> getDownloadUrl(String filename) async {
    return storage
        .ref("user")
        .child(this.userId)
        .child("img")
        .child(filename)
        .getDownloadURL();
  }
}
