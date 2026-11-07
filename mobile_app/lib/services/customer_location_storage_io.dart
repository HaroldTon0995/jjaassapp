import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocationStoragePlatform {
  static Future<File> _getFile(String key) async {
    final dir = await getApplicationDocumentsDirectory();
    final sanitized = key.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    return File('${dir.path}/$sanitized.json');
  }

  static Future<void> saveString(String key, String value) async {
    try {
      final file = await _getFile(key);
      await file.writeAsString(value);
    } catch (_) {}
  }

  static Future<String?> getString(String key) async {
    try {
      final file = await _getFile(key);
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return null;
  }

  static Future<void> removeKey(String key) async {
    try {
      final file = await _getFile(key);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

