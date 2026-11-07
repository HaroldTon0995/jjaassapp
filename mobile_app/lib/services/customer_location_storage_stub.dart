class LocationStoragePlatform {
  static final Map<String, String> _mem = {};

  static Future<void> saveString(String key, String value) async {
    _mem[key] = value;
  }

  static Future<String?> getString(String key) async {
    return _mem[key];
  }

  static Future<void> removeKey(String key) async {
    _mem.remove(key);
  }
}

