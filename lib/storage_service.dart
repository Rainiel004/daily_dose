import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';

class StorageService {
  // Get file path
  Future<String> get _localPath async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  // Get reference to file
  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/notes.txt');
  }

  // Save note to file
  Future<void> saveNote(String content) async {
    final file = await _localFile;
    await file.writeAsString(content);
  }

  // Load note from file
  Future<String> loadNote() async {
    try {
      final file = await _localFile;
      return await file.readAsString();
    } catch (e) {
      return ''; // Return empty if file doesn't exist
    }
  }
}