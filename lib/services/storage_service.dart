import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Sube una imagen y retorna la URL pública
  Future<String> uploadImage(File imageFile, String folder) async {
    final fileName = path.basename(imageFile.path);
    final ref = _storage.ref().child('$folder/$fileName');
    final uploadTask = await ref.putFile(imageFile);
    final url = await uploadTask.ref.getDownloadURL();
    return url;
  }

  // Elimina una imagen por URL
  Future<void> deleteImageByUrl(String url) async {
    final ref = _storage.refFromURL(url);
    await ref.delete();
  }
}
