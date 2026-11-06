import 'package:web/web.dart' as web;

class InventoryStorageImpl {
  static void saveString(String key, String value) {
    try {
      web.window.localStorage.setItem(key, value);
    } catch (_) {}
  }

  static String? getString(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }
}
