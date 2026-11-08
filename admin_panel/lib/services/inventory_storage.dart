import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'inventory_storage_stub.dart'
    if (dart.library.js_interop) 'inventory_storage_web.dart'
    if (dart.library.html) 'inventory_storage_web.dart';

class InventoryStorage {
  static const String _inventoryKey = 'jjaass_inventory_items_v3';
  static const String _restockLogsKey = 'jjaass_restock_logs_v3';
  static const String _reservesKey = 'jjaass_container_reserves_v3';
  static const String _returnedGallonsKey = 'jjaass_returned_gallons_v3';
  static const String _deletedProductIdsKey = 'jjaass_deleted_product_ids_v3';

  static void saveInventory(List<Map<String, dynamic>> items) {
    try {
      final cleanList = items.map((item) {
        final copy = Map<String, dynamic>.from(item);
        copy.remove('color');
        copy.remove('icon');
        return copy;
      }).toList();
      InventoryStorageImpl.saveString(_inventoryKey, jsonEncode(cleanList));
      debugPrint(
        'InventoryStorage: saved ${cleanList.length} items to local storage.',
      );
    } catch (e) {
      debugPrint('InventoryStorage save error: $e');
    }
  }

  static List<Map<String, dynamic>>? loadInventory() {
    try {
      final raw = InventoryStorageImpl.getString(_inventoryKey);
      if (raw != null && raw.isNotEmpty) {
        final deletedIds = loadDeletedProductIds();
        final decoded = jsonDecode(raw) as List<dynamic>;
        final list = decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((item) {
              final id = item['id']?.toString() ?? '';
              if (deletedIds.contains(id)) return false;
              return id != 'item_electric_pump' &&
                  id != 'item_manual_pump' &&
                  id != 'item_dispenser_caps';
            })
            .toList();
        debugPrint(
          'InventoryStorage: loaded ${list.length} items from local storage.',
        );
        return list;
      }
    } catch (e) {
      debugPrint('InventoryStorage load error: $e');
    }
    return null;
  }

  static void saveReserves(int emptyStocks, int refilledStocks) {
    try {
      final data = jsonEncode({
        'empty': emptyStocks,
        'refilled': refilledStocks,
      });
      InventoryStorageImpl.saveString(_reservesKey, data);
    } catch (e) {
      debugPrint('InventoryStorage save reserves error: $e');
    }
  }

  static Map<String, int>? loadReserves() {
    try {
      final raw = InventoryStorageImpl.getString(_reservesKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return {
          'empty': (decoded['empty'] as num?)?.toInt() ?? 0,
          'refilled': (decoded['refilled'] as num?)?.toInt() ?? 0,
        };
      }
    } catch (e) {
      debugPrint('InventoryStorage load reserves error: $e');
    }
    return null;
  }

  static void saveReturnedGallonOrders(Set<String> orderIds) {
    try {
      InventoryStorageImpl.saveString(
        _returnedGallonsKey,
        jsonEncode(orderIds.toList()),
      );
    } catch (e) {
      debugPrint('InventoryStorage save returned orders error: $e');
    }
  }

  static Set<String>? loadReturnedGallonOrders() {
    try {
      final raw = InventoryStorageImpl.getString(_returnedGallonsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded.map((e) => e.toString()).toSet();
      }
    } catch (e) {
      debugPrint('InventoryStorage load returned orders error: $e');
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
      debugPrint('InventoryStorage save logs error: $e');
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
            map['timestamp'] =
                DateTime.tryParse(map['timestamp']) ?? DateTime.now();
          }
          return map;
        }).toList();
      }
    } catch (e) {
      debugPrint('InventoryStorage load logs error: $e');
    }
    return null;
  }

  static void saveDeletedProductIds(Set<String> deletedIds) {
    try {
      InventoryStorageImpl.saveString(
        _deletedProductIdsKey,
        jsonEncode(deletedIds.toList()),
      );
    } catch (e) {
      debugPrint('InventoryStorage save deleted product ids error: $e');
    }
  }

  static Set<String> loadDeletedProductIds() {
    try {
      final raw = InventoryStorageImpl.getString(_deletedProductIdsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded.map((e) => e.toString()).toSet();
      }
    } catch (e) {
      debugPrint('InventoryStorage load deleted product ids error: $e');
    }
    return <String>{};
  }
}
