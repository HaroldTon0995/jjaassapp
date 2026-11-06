import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'inventory_storage_stub.dart'
    if (dart.library.js_interop) 'inventory_storage_web.dart';

class InventoryStorage {
  static const String _inventoryKey = 'jjaass_inventory_items_v2';
  static const String _restockLogsKey = 'jjaass_restock_logs_v2';

  static void saveInventory(List<Map<String, dynamic>> items) {
    try {
      final cleanList = items.map((item) {
        final copy = Map<String, dynamic>.from(item);
        copy.remove('color');
        copy.remove('icon');
        return copy;
      }).toList();
      InventoryStorageImpl.saveString(_inventoryKey, jsonEncode(cleanList));
    } catch (e) {
      debugPrint('LocalStorage save error: $e');
    }
  }

  static List<Map<String, dynamic>>? loadInventory() {
    try {
      final raw = InventoryStorageImpl.getString(_inventoryKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('LocalStorage load error: $e');
    }
    return null;
  }

  static void saveRestockLogs(List<Map<String, dynamic>> logs) {
    try {
      final serialized = logs.map((log) {
        final copy = Map<String, dynamic>.from(log);
        if (copy['timestamp'] is DateTime) {
          copy['timestamp'] = (copy['timestamp'] as DateTime).toIso8601String();
        }
        return copy;
      }).toList();
      InventoryStorageImpl.saveString(_restockLogsKey, jsonEncode(serialized));
    } catch (e) {
      debugPrint('LocalStorage save logs error: $e');
    }
  }

  static List<Map<String, dynamic>>? loadRestockLogs() {
    try {
      final raw = InventoryStorageImpl.getString(_restockLogsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          if (map['timestamp'] is String) {
            map['timestamp'] = DateTime.tryParse(map['timestamp']) ?? DateTime.now();
          }
          return map;
        }).toList();
      }
    } catch (e) {
      debugPrint('LocalStorage load logs error: $e');
    }
    return null;
  }
}
