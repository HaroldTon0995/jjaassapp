import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../models/order_model.dart';
import '../services/location_service.dart';
import '../services/inventory_storage.dart';

class OrderProvider extends ChangeNotifier {
  final List<OrderModel> _orders = [];
  final Map<String, double> _driverCashedOutEarnings = {};
  final Set<String> _deletedProductIds = {};
  bool _isLoading = false;
  Timer? _pollingTimer;

  Set<String> get deletedProductIds => Set.unmodifiable(_deletedProductIds);

  // Helpers for category visual styling
  static Color defaultColorForCategory(String category) {
    switch (category) {
      case 'water':
        return Colors.blue;
      case 'container':
        return Colors.indigo;
      case 'accessory':
        return Colors.amber;
      default:
        return Colors.blueGrey;
    }
  }

  static IconData defaultIconForCategory(String category) {
    switch (category) {
      case 'water':
        return Icons.water_drop_rounded;
      case 'container':
        return Icons.local_drink_rounded;
      case 'accessory':
        return Icons.inventory_2_rounded;
      default:
        return Icons.inventory_2_rounded;
    }
  }

  // Shared dynamic inventory items catalog (Water Refills, Containers & Bottles, Accessories)
  // Clean initialization: stocks start at 0.0 until configured by the Admin or loaded from storage.
  final List<Map<String, dynamic>> _inventoryItems = [
    {
      'id': 'prod_purified',
      'name': 'Purified Water Reservoir',
      'category': 'water',
      'unit': 'Liters',
      'price': 30.0,
      'stock': 10000.0,
      'capacity': 10000.0,
      'color': Colors.blue,
      'icon': Icons.water_drop_rounded,
      'description': '10,000L commercial bulk drinking water filtration tank (19L / refill)',
      'is_refill': true,
      'is_active': true,
    },
    {
      'id': 'prod_set_a',
      'name': '19L Water + New Container (Set A)',
      'category': 'water',
      'unit': 'Sets',
      'price': 230.0,
      'stock': 30.0,
      'capacity': 50.0,
      'color': Color(0xFF0284C7),
      'icon': Icons.inventory_2_rounded,
      'description': 'Brand new 5-gallon jug filled with pure drinking water',
      'is_refill': true,
      'is_active': true,
    },
    {
      'id': 'item_slim_gallon',
      'name': '5-Gallon Slim Container',
      'category': 'container',
      'unit': 'Units',
      'price': 220.0,
      'stock': 0.0,
      'capacity': 100.0,
      'color': Colors.indigo,
      'icon': Icons.local_drink_rounded,
      'image': 'assets/images/slim_container.jpg',
      'description': 'BPA-free durable slim poly-carbonate gallon jug',
      'is_refill': false,
      'is_active': true,
    },
    {
      'id': 'item_round_gallon',
      'name': '5-Gallon Round Container',
      'category': 'container',
      'unit': 'Units',
      'price': 200.0,
      'stock': 0.0,
      'capacity': 100.0,
      'color': Colors.deepPurple,
      'icon': Icons.crop_portrait_rounded,
      'image': 'assets/images/round_container.jpg',
      'description': 'Heavy-duty standard round water bottle',
      'is_refill': false,
      'is_active': true,
    },
  ];

  int _emptyContainerStocks = 50;
  int _refilledContainerStocks = 50;

  int get emptyContainerStocks => _emptyContainerStocks;
  int get refilledContainerStocks => _refilledContainerStocks;

  void adjustContainerReserves({int emptyChange = 0, int refilledChange = 0}) {
    _emptyContainerStocks = max(0, _emptyContainerStocks + emptyChange);
    _refilledContainerStocks = max(0, _refilledContainerStocks + refilledChange);
    notifyListeners();
    InventoryStorage.saveReserves(_emptyContainerStocks, _refilledContainerStocks);
  }

  void setContainerReserves({required int emptyStocks, required int refilledStocks}) {
    _emptyContainerStocks = max(0, emptyStocks);
    _refilledContainerStocks = max(0, refilledStocks);
    notifyListeners();
    InventoryStorage.saveReserves(_emptyContainerStocks, _refilledContainerStocks);
  }

  void setInventoryStockAndCapacity(
    String id, {
    required double stock,
    required double capacity,
    double? price,
    String? name,
  }) {
    final idx = _inventoryItems.indexWhere((p) => p['id'] == id);
    if (idx != -1) {
      final safeCapacity = max(capacity, stock);
      _inventoryItems[idx]['stock'] = max(0.0, stock);
      _inventoryItems[idx]['capacity'] = safeCapacity;
      if (price != null) _inventoryItems[idx]['price'] = price;
      if (name != null && name.isNotEmpty) _inventoryItems[idx]['name'] = name;

      notifyListeners();
      InventoryStorage.saveInventory(_inventoryItems);
      _syncInventoryToSupabase(_inventoryItems[idx], action: 'update');
    }
  }

  void setAllInventoryLevels(
    List<Map<String, dynamic>> itemsList, {
    int? emptyReserves,
    int? refilledReserves,
  }) {
    for (final updated in itemsList) {
      final id = updated['id'];
      final idx = _inventoryItems.indexWhere((p) => p['id'] == id);
      if (idx != -1) {
        final stock = (updated['stock'] as num?)?.toDouble() ?? 0.0;
        final cap = (updated['capacity'] as num?)?.toDouble() ?? stock;
        _inventoryItems[idx]['stock'] = max(0.0, stock);
        _inventoryItems[idx]['capacity'] = max(cap, stock);
        if (updated['price'] != null) {
          _inventoryItems[idx]['price'] = (updated['price'] as num).toDouble();
        }
        if (updated['name'] != null) {
          _inventoryItems[idx]['name'] = updated['name'];
        }
        _syncInventoryToSupabase(_inventoryItems[idx], action: 'update');
      }
    }

    notifyListeners();
    InventoryStorage.saveInventory(_inventoryItems);
  }

  List<Map<String, dynamic>> get inventoryItems => _inventoryItems;

  List<Map<String, dynamic>> get refillProducts =>
      _inventoryItems.where((i) {
        final active = (i['is_active'] ?? true) == true;
        final isRefill = i['is_refill'] == true ||
            (i['category'] == 'water' &&
                (i['unit']?.toString().toLowerCase() == 'gallons' ||
                    i['name'].toString().toLowerCase().contains('refill') ||
                    i['name'].toString().toLowerCase().contains('19l')));
        return active && isRefill;
      }).toList();

  List<Map<String, dynamic>> get standaloneProducts =>
      _inventoryItems.where((i) {
        final active = (i['is_active'] ?? true) == true;
        final id = i['id']?.toString() ?? '';
        final name = (i['name']?.toString() ?? '').toLowerCase();
        final isCoreJug = id == 'item_slim_gallon' ||
            id == 'item_round_gallon' ||
            name == '5-gallon slim container' ||
            name == '5-gallon round container';
        final isRefill = i['is_refill'] == true ||
            (i['category'] == 'water' &&
                (i['unit']?.toString().toLowerCase() == 'gallons' ||
                    i['name'].toString().toLowerCase().contains('refill') ||
                    i['name'].toString().toLowerCase().contains('19l')));
        return active && !isCoreJug && !isRefill;
      }).toList();

  List<Map<String, dynamic>> get waterProducts {
    final refills = refillProducts;
    if (refills.isNotEmpty) return refills;
    return _inventoryItems.where((i) => i['category'] == 'water' && (i['is_active'] ?? true) == true).toList();
  }

  void addInventoryItem({
    required String name,
    required String category,
    required String unit,
    required double price,
    required double stock,
    required double capacity,
    required Color color,
    required IconData icon,
    String description = '',
    bool isActive = true,
    bool isRefill = false,
  }) {
    final bool calculatedIsRefill = isRefill ||
        (category == 'water' &&
            (unit.toLowerCase() == 'gallons' ||
                name.toLowerCase().contains('refill') ||
                name.toLowerCase().contains('19l')));
    final newItem = {
      'id': 'item_${DateTime.now().millisecondsSinceEpoch}',
      'name': name,
      'category': category,
      'unit': unit,
      'price': price,
      'stock': stock,
      'capacity': capacity,
      'color': color,
      'icon': icon,
      'description': description,
      'is_refill': calculatedIsRefill,
      'is_active': isActive,
    };
    _deletedProductIds.remove(newItem['id']);
    InventoryStorage.saveDeletedProductIds(_deletedProductIds);
    _inventoryItems.add(newItem);
    notifyListeners();
    InventoryStorage.saveInventory(_inventoryItems);
    _syncInventoryToSupabase(newItem, action: 'insert');
  }

  void addWaterProduct({
    required String name,
    required double price,
    required double stock,
    required double capacity,
    required Color color,
    required IconData icon,
    String description = '',
    bool isActive = true,
    bool isRefill = true,
  }) {
    addInventoryItem(
      name: name,
      category: 'water',
      unit: 'Gallons',
      price: price,
      stock: stock,
      capacity: capacity,
      color: color,
      icon: icon,
      description: description.isNotEmpty ? description : 'Water Refill Product',
      isActive: isActive,
      isRefill: isRefill,
    );
  }

  void updateInventoryItem({
    required String id,
    required String name,
    required String category,
    required String unit,
    required double price,
    required double stock,
    required double capacity,
    required Color color,
    required IconData icon,
    String description = '',
    bool isActive = true,
    bool? isRefill,
  }) {
    final idx = _inventoryItems.indexWhere((p) => p['id'] == id);
    if (idx != -1) {
      final bool calculatedIsRefill = isRefill ??
          (_inventoryItems[idx]['is_refill'] == true ||
              (category == 'water' &&
                  (unit.toLowerCase() == 'gallons' ||
                      name.toLowerCase().contains('refill') ||
                      name.toLowerCase().contains('19l'))));
      _inventoryItems[idx] = {
        'id': id,
        'name': name,
        'category': category,
        'unit': unit,
        'price': price,
        'stock': stock,
        'capacity': capacity,
        'color': color,
        'icon': icon,
        'description': description,
        'is_refill': calculatedIsRefill,
        'is_active': isActive,
      };
      notifyListeners();
      InventoryStorage.saveInventory(_inventoryItems);
      _syncInventoryToSupabase(_inventoryItems[idx], action: 'update');
    }
  }

  void deleteInventoryItem(String id) {
    _deletedProductIds.add(id);
    _inventoryItems.removeWhere((p) => p['id'] == id);
    notifyListeners();
    InventoryStorage.saveDeletedProductIds(_deletedProductIds);
    InventoryStorage.saveInventory(_inventoryItems);
    _syncInventoryToSupabase({'id': id}, action: 'delete');
  }

  final List<Map<String, dynamic>> _restockLogs = [];
  List<Map<String, dynamic>> get restockLogs => List.unmodifiable(_restockLogs);

  void restockInventoryItem(
    String id,
    double amount, {
    String? restockedBy,
    String? notes,
  }) {
    final idx = _inventoryItems.indexWhere((p) => p['id'] == id);
    if (idx != -1) {
      final capacity = (_inventoryItems[idx]['capacity'] as num).toDouble();
      final currentStock = (_inventoryItems[idx]['stock'] as num).toDouble();
      final newStock = currentStock + amount;
      final newCapacity = max(capacity, newStock);
      _inventoryItems[idx]['capacity'] = newCapacity;
      _inventoryItems[idx]['stock'] = newStock;

      final logEntry = {
        'id': 'restock_${DateTime.now().millisecondsSinceEpoch}',
        'itemId': id,
        'itemName': _inventoryItems[idx]['name'],
        'amount': amount,
        'previousStock': currentStock,
        'newStock': newStock,
        'unit': _inventoryItems[idx]['unit'] ?? 'Units',
        'timestamp': DateTime.now(),
        'restockedBy': restockedBy ?? 'Administrator',
        'notes': notes ?? 'Inventory stock replenished',
      };
      _restockLogs.insert(0, logEntry);

      notifyListeners();
      InventoryStorage.saveInventory(_inventoryItems);
      InventoryStorage.saveRestockLogs(_restockLogs);
      _syncInventoryToSupabase(_inventoryItems[idx], action: 'update');
      _syncRestockLogToSupabase(logEntry);
    }
  }

  void refillWaterProduct(String id, double amount) {
    restockInventoryItem(id, amount);
  }
  final Set<String> _returnedGallonOrderIds = {};

  bool isGallonReturned(String orderId) => _returnedGallonOrderIds.contains(orderId);

  // Gallon remaining stock getters
  double get remainingSlimGallons {
    final item = _inventoryItems.firstWhere(
      (i) => i['id'] == 'item_slim_gallon' || i['name'].toString().toLowerCase().contains('slim'),
      orElse: () => {'stock': 0.0},
    );
    return (item['stock'] as num).toDouble();
  }

  double get remainingRoundGallons {
    final item = _inventoryItems.firstWhere(
      (i) => i['id'] == 'item_round_gallon' || i['name'].toString().toLowerCase().contains('round'),
      orElse: () => {'stock': 0.0},
    );
    return (item['stock'] as num).toDouble();
  }

  double get slimGallonCapacity {
    final item = _inventoryItems.firstWhere(
      (i) => i['id'] == 'item_slim_gallon' || i['name'].toString().toLowerCase().contains('slim'),
      orElse: () => {'capacity': 100.0},
    );
    final cap = (item['capacity'] as num).toDouble();
    return cap > 0 ? cap : 100.0;
  }

  double get roundGallonCapacity {
    final item = _inventoryItems.firstWhere(
      (i) => i['id'] == 'item_round_gallon' || i['name'].toString().toLowerCase().contains('round'),
      orElse: () => {'capacity': 100.0},
    );
    final cap = (item['capacity'] as num).toDouble();
    return cap > 0 ? cap : 100.0;
  }

  // Bulk Water Reservoir (Liters) Getters
  double get waterReservoirLiters {
    final item = _inventoryItems.firstWhere(
      (i) => i['id'] == 'prod_purified' || i['category'] == 'water',
      orElse: () => {'stock': 10000.0},
    );
    return (item['stock'] as num).toDouble();
  }

  double get waterReservoirCapacity {
    final item = _inventoryItems.firstWhere(
      (i) => i['id'] == 'prod_purified' || i['category'] == 'water',
      orElse: () => {'capacity': 10000.0},
    );
    final cap = (item['capacity'] as num).toDouble();
    return cap > 0 ? cap : 10000.0;
  }

  int get availableRefillsCount {
    return (waterReservoirLiters / 19.0).floor();
  }

  Future<void> refillBulkWaterReservoir(double liters, {String? notes}) async {
    final idx = _inventoryItems.indexWhere((i) => i['id'] == 'prod_purified' || i['category'] == 'water');
    if (idx != -1) {
      final currentStock = (_inventoryItems[idx]['stock'] as num).toDouble();
      final capacity = (_inventoryItems[idx]['capacity'] as num).toDouble();
      final newStock = min(capacity, currentStock + liters);
      _inventoryItems[idx]['stock'] = newStock;

      final logEntry = {
        'id': 'water_refill_${DateTime.now().millisecondsSinceEpoch}',
        'itemId': 'prod_purified',
        'itemName': 'Purified Water Reservoir',
        'amount': liters,
        'previousStock': currentStock,
        'newStock': newStock,
        'unit': 'Liters',
        'timestamp': DateTime.now(),
        'restockedBy': 'Station Administrator',
        'notes': notes ?? 'Bulk water filtration tank replenishment (+${liters.toInt()}L)',
      };
      _restockLogs.insert(0, logEntry);
      notifyListeners();
      InventoryStorage.saveInventory(_inventoryItems);
      InventoryStorage.saveRestockLogs(_restockLogs);
      _syncInventoryToSupabase(_inventoryItems[idx], action: 'update');
      _syncRestockLogToSupabase(logEntry);
    }
  }

  // Borrowed gallons list
  List<Map<String, dynamic>> get customerBorrows {
    final list = <Map<String, dynamic>>[];
    for (final order in _orders) {
      if (order.orderStatus == OrderStatus.cancelled) continue;
      if (order.isCollectionJob) continue;

      final lower = order.waterType.toLowerCase();
      final isNewContainerSale = lower.contains('set a') || lower.contains('new container');
      if (isNewContainerSale) continue; // Brand new container purchase, customer did not borrow

      // Only orders that are explicitly marked as borrowing containers, or contain borrowed tag
      if (!order.isBorrowingContainers && !order.deliveryAddress.contains('[BORROWED_')) {
        continue;
      }

      final isReturned = order.isGallonReturned ||
          _returnedGallonOrderIds.contains(order.id) ||
          _returnedGallonOrderIds.contains(order.txnId) ||
          order.deliveryAddress.contains('[GALLONS_RETURNED]') ||
          (order.deliveryNote?.contains('[GALLONS_RETURNED]') ?? false);

      final int slimCount = order.borrowedSlimCount ?? 0;
      final int roundCount = order.borrowedRoundCount ?? 0;

      if (order.isBorrowingContainers && (slimCount > 0 || roundCount > 0)) {
        final bool isSlimReturned = isReturned ||
            slimCount == 0 ||
            _returnedGallonOrderIds.contains('${order.id}_slim') ||
            _returnedGallonOrderIds.contains('${order.txnId}_slim');

        final bool isRoundReturned = isReturned ||
            roundCount == 0 ||
            _returnedGallonOrderIds.contains('${order.id}_round') ||
            _returnedGallonOrderIds.contains('${order.txnId}_round');

        if (slimCount > 0) {
          list.add({
            'orderId': order.id,
            'txnId': order.txnId,
            'customerId': order.customerId,
            'customerName': order.customerName,
            'customerPhone': order.customerPhone,
            'deliveryAddress': order.deliveryAddress,
            'gallonType': '5-Gallon Slim',
            'quantity': slimCount,
            'orderStatus': order.orderStatus,
            'borrowedAt': order.createdAt,
            'isReturned': isSlimReturned,
            'isBulkBorrow': true,
          });
        }
        if (roundCount > 0) {
          list.add({
            'orderId': order.id,
            'txnId': order.txnId,
            'customerId': order.customerId,
            'customerName': order.customerName,
            'customerPhone': order.customerPhone,
            'deliveryAddress': order.deliveryAddress,
            'gallonType': '5-Gallon Round',
            'quantity': roundCount,
            'orderStatus': order.orderStatus,
            'borrowedAt': order.createdAt,
            'isReturned': isRoundReturned,
            'isBulkBorrow': true,
          });
        }
        continue;
      }

      final slimMatch = RegExp(r'(\d+)\s*slim', caseSensitive: false).firstMatch(lower);
      final roundMatch = RegExp(r'(\d+)\s*round', caseSensitive: false).firstMatch(lower);
      final int slimQty = slimMatch != null ? int.tryParse(slimMatch.group(1)!) ?? 0 : 0;
      final int roundQty = roundMatch != null ? int.tryParse(roundMatch.group(1)!) ?? 0 : 0;

      if (slimQty > 0 && roundQty > 0) {
        list.add({
          'orderId': order.id,
          'txnId': order.txnId,
          'customerId': order.customerId,
          'customerName': order.customerName,
          'customerPhone': order.customerPhone,
          'deliveryAddress': order.deliveryAddress,
          'gallonType': '5-Gallon Slim',
          'quantity': slimQty,
          'orderStatus': order.orderStatus,
          'borrowedAt': order.createdAt,
          'isReturned': isReturned,
        });
        list.add({
          'orderId': order.id,
          'txnId': order.txnId,
          'customerId': order.customerId,
          'customerName': order.customerName,
          'customerPhone': order.customerPhone,
          'deliveryAddress': order.deliveryAddress,
          'gallonType': '5-Gallon Round',
          'quantity': roundQty,
          'orderStatus': order.orderStatus,
          'borrowedAt': order.createdAt,
          'isReturned': isReturned,
        });
      } else {
        String gallonType = '5-Gallon Slim';
        if (roundQty > 0 || lower.contains('round')) {
          gallonType = '5-Gallon Round';
        }
        list.add({
          'orderId': order.id,
          'txnId': order.txnId,
          'customerId': order.customerId,
          'customerName': order.customerName,
          'customerPhone': order.customerPhone,
          'deliveryAddress': order.deliveryAddress,
          'gallonType': gallonType,
          'quantity': order.quantity,
          'orderStatus': order.orderStatus,
          'borrowedAt': order.createdAt,
          'isReturned': isReturned,
        });
      }
    }
    return list;
  }

  int get totalActiveBorrowedGallons {
    return customerBorrows
        .where((b) => b['isReturned'] == false)
        .fold<int>(0, (sum, b) => sum + (b['quantity'] as int));
  }

  int get activeSlimBorrowedGallons {
    return customerBorrows
        .where((b) => b['isReturned'] == false && (b['gallonType'] as String).contains('Slim'))
        .fold<int>(0, (sum, b) => sum + (b['quantity'] as int));
  }

  int get activeRoundBorrowedGallons {
    return customerBorrows
        .where((b) => b['isReturned'] == false && (b['gallonType'] as String).contains('Round'))
        .fold<int>(0, (sum, b) => sum + (b['quantity'] as int));
  }

  void returnBorrowedGallons({
    required String orderId,
    required String gallonType,
    required int quantity,
    String? customerName,
  }) {
    final lower = gallonType.toLowerCase();
    final String matchedId = lower.contains('round') ? 'item_round_gallon' : 'item_slim_gallon';
    final idx = _inventoryItems.indexWhere(
      (p) => p['id'] == matchedId || p['name'].toString().toLowerCase().contains(matchedId.contains('slim') ? 'slim' : 'round'),
    );
    if (idx != -1) {
        final capacity = (_inventoryItems[idx]['capacity'] as num).toDouble();
        final currentStock = (_inventoryItems[idx]['stock'] as num).toDouble();
        final newStock = currentStock + quantity;
        final newCapacity = max(capacity, newStock);
        _inventoryItems[idx]['capacity'] = newCapacity;
        _inventoryItems[idx]['stock'] = newStock;
        _syncInventoryToSupabase(_inventoryItems[idx], action: 'update');

        final logEntry = {
          'id': 'return_${DateTime.now().millisecondsSinceEpoch}',
          'itemId': matchedId,
          'itemName': _inventoryItems[idx]['name'],
          'amount': quantity.toDouble(),
          'previousStock': currentStock,
          'newStock': newStock,
          'unit': _inventoryItems[idx]['unit'] ?? 'Units',
          'timestamp': DateTime.now(),
          'restockedBy': customerName != null ? 'Return from $customerName' : 'Customer Container Return',
          'notes': 'Order reference: $orderId',
        };
        _restockLogs.insert(0, logEntry);
        _syncRestockLogToSupabase(logEntry);
      }

    _returnedGallonOrderIds.add(orderId);
    final orderIdx = _orders.indexWhere((o) => o.id == orderId);
    if (orderIdx != -1) {
      _orders[orderIdx].isBorrowingContainers = false;
      _orders[orderIdx].isGallonReturned = true;
      if (_isSupabaseConfigured) {
        try {
          final client = Supabase.instance.client;
          client.from('orders').update({
            'isBorrowingContainers': false,
            'isGallonReturned': true,
          }).eq('id', orderId).catchError((_) {
            final safeAddr = _orders[orderIdx].deliveryAddress.contains('[GALLONS_RETURNED]')
                ? _orders[orderIdx].deliveryAddress
                : '${_orders[orderIdx].deliveryAddress} [GALLONS_RETURNED]';
            _orders[orderIdx].deliveryAddress = safeAddr;
            client.from('orders').update({'deliveryAddress': safeAddr}).eq('id', orderId).catchError((_) {});
          });
        } catch (_) {}
      }
    }
    notifyListeners();
    InventoryStorage.saveInventory(_inventoryItems);
    InventoryStorage.saveRestockLogs(_restockLogs);
    InventoryStorage.saveReturnedGallonOrders(_returnedGallonOrderIds);
  }

  Future<void> collectDriverReturnedGallons({
    required String orderId,
    required String customerName,
    required int slimCount,
    required int roundCount,
    required String driverName,
    String? notes,
  }) async {
    // 1. Replenish Slim stock if collected
    if (slimCount > 0) {
      final slimIdx = _inventoryItems.indexWhere((p) => p['id'] == 'item_slim_gallon');
      if (slimIdx != -1) {
        final currentStock = (_inventoryItems[slimIdx]['stock'] as num).toDouble();
        final newStock = currentStock + slimCount;
        final capacity = (_inventoryItems[slimIdx]['capacity'] as num).toDouble();
        _inventoryItems[slimIdx]['stock'] = newStock;
        _inventoryItems[slimIdx]['capacity'] = max(capacity, newStock);
        await _syncInventoryToSupabase(_inventoryItems[slimIdx], action: 'update');

        final logEntry = {
          'id': 'return_slim_${DateTime.now().millisecondsSinceEpoch}',
          'itemId': 'item_slim_gallon',
          'itemName': '5-Gallon Slim Container',
          'amount': slimCount.toDouble(),
          'previousStock': currentStock,
          'newStock': newStock,
          'unit': 'Units',
          'timestamp': DateTime.now(),
          'restockedBy': 'Driver $driverName (Collected from $customerName)',
          'notes': notes ?? 'Order reference: $orderId - Gallon return collected',
        };
        _restockLogs.insert(0, logEntry);
        await _syncRestockLogToSupabase(logEntry);
      }
    }

    // 2. Replenish Round stock if collected
    if (roundCount > 0) {
      final roundIdx = _inventoryItems.indexWhere((p) => p['id'] == 'item_round_gallon');
      if (roundIdx != -1) {
        final currentStock = (_inventoryItems[roundIdx]['stock'] as num).toDouble();
        final newStock = currentStock + roundCount;
        final capacity = (_inventoryItems[roundIdx]['capacity'] as num).toDouble();
        _inventoryItems[roundIdx]['stock'] = newStock;
        _inventoryItems[roundIdx]['capacity'] = max(capacity, newStock);
        await _syncInventoryToSupabase(_inventoryItems[roundIdx], action: 'update');

        final logEntry = {
          'id': 'return_round_${DateTime.now().millisecondsSinceEpoch}',
          'itemId': 'item_round_gallon',
          'itemName': '5-Gallon Round Container',
          'amount': roundCount.toDouble(),
          'previousStock': currentStock,
          'newStock': newStock,
          'unit': 'Units',
          'timestamp': DateTime.now(),
          'restockedBy': 'Driver $driverName (Collected from $customerName)',
          'notes': notes ?? 'Order reference: $orderId - Gallon return collected',
        };
        _restockLogs.insert(0, logEntry);
        await _syncRestockLogToSupabase(logEntry);
      }
    }

    // 3. Update the customer's borrow record & reduce outstanding debt in memory and in Supabase
    int targetIdx = _orders.indexWhere((o) => o.id == orderId || o.txnId == orderId);
    if (targetIdx == -1) {
      targetIdx = _orders.indexWhere((o) =>
          (o.customerId == orderId ||
           o.customerName.trim().toLowerCase() == customerName.trim().toLowerCase()) &&
          !o.isCollectionJob &&
          !o.isGallonReturned);
    }

    if (targetIdx != -1) {
      final o = _orders[targetIdx];
      int remainingSlim = (o.borrowedSlimCount ?? 0) - slimCount;
      if (remainingSlim < 0) remainingSlim = 0;
      o.borrowedSlimCount = remainingSlim;

      int remainingRound = (o.borrowedRoundCount ?? 0) - roundCount;
      if (remainingRound < 0) remainingRound = 0;
      o.borrowedRoundCount = remainingRound;

      if (remainingSlim == 0 && remainingRound == 0) {
        o.isBorrowingContainers = false;
        o.isGallonReturned = true;
        _returnedGallonOrderIds.add(orderId);
        _returnedGallonOrderIds.add(o.id);
        _returnedGallonOrderIds.add(o.txnId);
      } else {
        if (slimCount > 0 && remainingSlim == 0) {
          _returnedGallonOrderIds.add('${orderId}_slim');
          _returnedGallonOrderIds.add('${o.id}_slim');
          _returnedGallonOrderIds.add('${o.txnId}_slim');
        }
        if (roundCount > 0 && remainingRound == 0) {
          _returnedGallonOrderIds.add('${orderId}_round');
          _returnedGallonOrderIds.add('${o.id}_round');
          _returnedGallonOrderIds.add('${o.txnId}_round');
        }
      }

      String safeAddr = o.deliveryAddress
          .replaceAll(RegExp(r'\[BORROWED_[A-Z]+:\d+\]'), '')
          .replaceAll('[GALLONS_RETURNED]', '')
          .trim();

      if (o.isGallonReturned) {
        safeAddr = '$safeAddr [GALLONS_RETURNED]';
      } else {
        safeAddr = '$safeAddr [BORROWED_SLIM:${o.borrowedSlimCount ?? 0}][BORROWED_ROUND:${o.borrowedRoundCount ?? 0}]';
      }
      o.deliveryAddress = safeAddr;

      if (_isSupabaseConfigured) {
        try {
          final client = Supabase.instance.client;
          final updatePayload = <String, dynamic>{
            'deliveryAddress': safeAddr,
            'isBorrowingContainers': o.isBorrowingContainers,
            'isGallonReturned': o.isGallonReturned,
          };
          if (o.borrowedSlimCount != null) updatePayload['borrowedSlimCount'] = o.borrowedSlimCount;
          if (o.borrowedRoundCount != null) updatePayload['borrowedRoundCount'] = o.borrowedRoundCount;

          try {
            await client.from('orders').update(updatePayload).eq('id', o.id);
          } catch (_) {
            await client.from('orders').update({'deliveryAddress': safeAddr}).eq('id', o.id);
          }
        } catch (e) {
          debugPrint('Supabase customer borrow update failed: $e');
        }
      }
    } else {
      _returnedGallonOrderIds.add(orderId);
    }

    // 5. Complete matching collection job orders in memory and in Supabase
    final matchingCollectionJobs = _orders.where((o) =>
        o.isCollectionJob &&
        (o.customerName.trim().toLowerCase() == customerName.trim().toLowerCase() ||
         o.customerName.trim().toLowerCase().contains(customerName.trim().toLowerCase()) ||
         customerName.trim().toLowerCase().contains(o.customerName.trim().toLowerCase()) ||
         o.id == orderId ||
         o.txnId == orderId) &&
        o.orderStatus != OrderStatus.completed &&
        o.orderStatus != OrderStatus.cancelled).toList();

    for (final job in matchingCollectionJobs) {
      job.orderStatus = OrderStatus.completed;
      job.completedAt = DateTime.now();
      if (_isSupabaseConfigured) {
        try {
          final client = Supabase.instance.client;
          await client.from('orders').update({
            'orderStatus': OrderStatus.completed.name,
            'completedAt': DateTime.now().toIso8601String(),
          }).eq('id', job.id);
        } catch (e) {
          debugPrint('Supabase collection job completion update failed: $e');
        }
      }
    }

    notifyListeners();
    InventoryStorage.saveInventory(_inventoryItems);
    InventoryStorage.saveRestockLogs(_restockLogs);
    InventoryStorage.saveReturnedGallonOrders(_returnedGallonOrderIds);
  }

  Future<OrderModel> createCollectionJobOrder({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required String driverId,
    required String driverName,
    int slimCount = 0,
    int roundCount = 0,
    String? scheduledDate,
    String? notes,
    double? latitude,
    double? longitude,
  }) async {
    _isLoading = true;
    notifyListeners();

    final randomNum = 1000 + Random().nextInt(8999);
    final orderId = '#COL-00$randomNum';
    final txnId = '#TXN-COL$randomNum';
    final totalQty = slimCount + roundCount;

    final scheduleNote = [
      if (scheduledDate != null && scheduledDate.isNotEmpty) 'Schedule: $scheduledDate',
      if (notes != null && notes.isNotEmpty) notes,
      'Weekly empty gallon retrieval',
    ].join(' • ');

    final newOrder = OrderModel(
      id: orderId,
      txnId: txnId,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: deliveryAddress,
      waterType: 'Weekly Gallon Collection',
      quantity: totalQty > 0 ? totalQty : 1,
      pricePerUnit: 0.0,
      totalAmount: 0.0,
      paymentMethod: 'Collection Service',
      paymentStatus: 'Scheduled',
      orderStatus: OrderStatus.assigned,
      driverId: driverId,
      driverName: driverName,
      createdAt: DateTime.now(),
      distance: '1.5 km',
      deliveryNote: scheduleNote,
      latitude: latitude,
      longitude: longitude,
      isCollectionJob: true,
      borrowedSlimCount: slimCount,
      borrowedRoundCount: roundCount,
    );

    _orders.insert(0, newOrder);

    if (_isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        final insertMap = <String, dynamic>{
          'id': newOrder.id,
          'txnId': newOrder.txnId,
          'customerId': newOrder.customerId,
          'customerName': newOrder.customerName,
          'customerPhone': newOrder.customerPhone,
          'deliveryAddress': newOrder.deliveryNote != null && newOrder.deliveryNote!.isNotEmpty
              ? '${newOrder.deliveryAddress} • Note: ${newOrder.deliveryNote}'
              : newOrder.deliveryAddress,
          'waterType': newOrder.waterType,
          'quantity': newOrder.quantity,
          'pricePerUnit': newOrder.pricePerUnit,
          'totalAmount': newOrder.totalAmount,
          'paymentMethod': newOrder.paymentMethod,
          'paymentStatus': newOrder.paymentStatus,
          'orderStatus': newOrder.orderStatus.name,
          'driverId': newOrder.driverId,
          'driverName': newOrder.driverName,
          'createdAt': newOrder.createdAt.toIso8601String(),
          'distance': newOrder.distance,
        };
        if (newOrder.latitude != null) insertMap['latitude'] = newOrder.latitude!;
        if (newOrder.longitude != null) insertMap['longitude'] = newOrder.longitude!;

        try {
          final richMap = Map<String, dynamic>.from(insertMap);
          richMap['isCollectionJob'] = true;
          richMap['borrowedSlimCount'] = newOrder.borrowedSlimCount;
          richMap['borrowedRoundCount'] = newOrder.borrowedRoundCount;
          if (newOrder.deliveryNote != null) richMap['deliveryNote'] = newOrder.deliveryNote;
          await client.from('orders').insert(richMap);
        } catch (e) {
          debugPrint('Supabase collection job rich insert failed ($e). Retrying with base columns...');
          try {
            await client.from('orders').insert(insertMap);
            debugPrint('Successfully inserted collection job ${newOrder.id} to Supabase with base columns!');
          } catch (retryErr) {
            debugPrint('Supabase collection job retry insert failed: $retryErr');
          }
        }
      } catch (e) {
        debugPrint('Supabase collection job order insert error: $e');
      }
    }

    _isLoading = false;
    notifyListeners();
    return newOrder;
  }

  List<Map<String, dynamic>> getDriverDailyCollections(String driverName) {
    final now = DateTime.now();
    return _restockLogs.where((log) {
      final by = log['restockedBy']?.toString() ?? '';
      if (!by.toLowerCase().contains(driverName.toLowerCase())) return false;
      final ts = log['timestamp'] as DateTime?;
      if (ts == null) return false;
      return ts.year == now.year && ts.month == now.month && ts.day == now.day;
    }).toList();
  }

  int getDriverDailyCollectedGallonsCount(String driverName) {
    final logs = getDriverDailyCollections(driverName);
    return logs.fold<int>(0, (sum, l) => sum + ((l['amount'] as num?)?.toInt() ?? 0));
  }

  void deductProductStock(
    String name,
    int qty, {
    bool isWalkIn = false,
    bool isBorrowingContainers = false,
    int? borrowedSlimQty,
    int? borrowedRoundQty,
  }) {
    final lowerName = name.toLowerCase();
    // 1. Deduct water volume (19 Liters per refilled 5-gallon jug)
    final waterIdx = _inventoryItems.indexWhere(
      (p) =>
          p['category'] == 'water' &&
          (p['id'] == 'prod_purified' ||
              p['name'] == name ||
              lowerName.contains('purified') ||
              lowerName.contains('water') ||
              lowerName.contains('refill') ||
              lowerName.contains('set a')),
    );
    if (waterIdx != -1) {
      final currentStock = (_inventoryItems[waterIdx]['stock'] as num).toDouble();
      final litersDeducted = qty * 19.0;
      _inventoryItems[waterIdx]['stock'] = max(0.0, currentStock - litersDeducted);
      _syncInventoryToSupabase(_inventoryItems[waterIdx], action: 'update');
    }

    // 2. Physical Container Inventory Deduction:
    // In a water refilling station, regular refills with container exchange DO NOT deplete physical container stock!
    final isNewContainerSale = lowerName.contains('set a') || lowerName.contains('new container');

    if (!isNewContainerSale && !isBorrowingContainers && !lowerName.contains('container') && !lowerName.contains('jug')) {
      adjustContainerReserves(emptyChange: qty, refilledChange: -qty);
      notifyListeners();
      InventoryStorage.saveInventory(_inventoryItems);
      return;
    }

    // Parse or use explicit Slim vs Round breakdown
    int slimQty = borrowedSlimQty ?? 0;
    int roundQty = borrowedRoundQty ?? 0;

    if (slimQty == 0 && roundQty == 0) {
      final slimMatch = RegExp(r'(\d+)\s*slim', caseSensitive: false).firstMatch(lowerName);
      final roundMatch = RegExp(r'(\d+)\s*round', caseSensitive: false).firstMatch(lowerName);
      slimQty = slimMatch != null ? int.tryParse(slimMatch.group(1)!) ?? 0 : 0;
      roundQty = roundMatch != null ? int.tryParse(roundMatch.group(1)!) ?? 0 : 0;
      if (slimQty == 0 && roundQty == 0) {
        if (lowerName.contains('round')) {
          roundQty = qty;
        } else {
          slimQty = qty;
        }
      }
    }

    if (slimQty > 0) {
      final slimIdx = _inventoryItems.indexWhere(
        (p) => p['id'] == 'item_slim_gallon' || p['name'].toString().toLowerCase().contains('slim'),
      );
      if (slimIdx != -1) {
        final currentStock = (_inventoryItems[slimIdx]['stock'] as num).toDouble();
        _inventoryItems[slimIdx]['stock'] = max(0.0, currentStock - slimQty);
        _syncInventoryToSupabase(_inventoryItems[slimIdx], action: 'update');
      }
    }

    if (roundQty > 0) {
      final roundIdx = _inventoryItems.indexWhere(
        (p) => p['id'] == 'item_round_gallon' || p['name'].toString().toLowerCase().contains('round'),
      );
      if (roundIdx != -1) {
        final currentStock = (_inventoryItems[roundIdx]['stock'] as num).toDouble();
        _inventoryItems[roundIdx]['stock'] = max(0.0, currentStock - roundQty);
        _syncInventoryToSupabase(_inventoryItems[roundIdx], action: 'update');
      }
    }

    // Update container reserves:
    // If selling a brand new container (Set A), customer does not return an empty container
    if (isNewContainerSale) {
      adjustContainerReserves(emptyChange: 0, refilledChange: -qty);
    } else if (isBorrowingContainers) {
      adjustContainerReserves(emptyChange: 0, refilledChange: -(slimQty + roundQty));
    } else {
      adjustContainerReserves(emptyChange: qty, refilledChange: -qty);
    }
    notifyListeners();
    InventoryStorage.saveInventory(_inventoryItems);
  }

  void refundProductStock(
    String name,
    int qty, {
    bool isWalkIn = false,
    bool isBorrowingContainers = false,
    int? borrowedSlimQty,
    int? borrowedRoundQty,
  }) {
    final lowerName = name.toLowerCase();
    // 1. Replenish water product stock
    final waterIdx = _inventoryItems.indexWhere(
      (p) =>
          p['category'] == 'water' &&
          (p['name'] == name ||
              lowerName.contains(p['name'].toString().toLowerCase()) ||
              p['name'].toString().toLowerCase().contains(lowerName) ||
              (lowerName.contains('set a') && p['id'] == 'prod_set_a') ||
              (lowerName.contains('purified') && p['id'] == 'prod_purified')),
    );
    if (waterIdx != -1) {
      final capacity = (_inventoryItems[waterIdx]['capacity'] as num).toDouble();
      final currentStock = (_inventoryItems[waterIdx]['stock'] as num).toDouble();
      final newStock = currentStock + qty;
      _inventoryItems[waterIdx]['capacity'] = max(capacity, newStock);
      _inventoryItems[waterIdx]['stock'] = newStock;
      _syncInventoryToSupabase(_inventoryItems[waterIdx], action: 'update');
    }

    // 2. Container Inventory Refund
    final isNewContainerSale = lowerName.contains('set a') || lowerName.contains('new container');

    // Walk-in order with customer's own container did not deduct container inventory
    if (isWalkIn && !isNewContainerSale && !isBorrowingContainers) {
      notifyListeners();
      InventoryStorage.saveInventory(_inventoryItems);
      return;
    }

    // Parse exact Slim vs Round breakdown
    int slimQty = borrowedSlimQty ?? 0;
    int roundQty = borrowedRoundQty ?? 0;

    if (slimQty == 0 && roundQty == 0) {
      final slimMatch = RegExp(r'(\d+)\s*slim', caseSensitive: false).firstMatch(lowerName);
      final roundMatch = RegExp(r'(\d+)\s*round', caseSensitive: false).firstMatch(lowerName);
      slimQty = slimMatch != null ? int.tryParse(slimMatch.group(1)!) ?? 0 : 0;
      roundQty = roundMatch != null ? int.tryParse(roundMatch.group(1)!) ?? 0 : 0;
      if (slimQty == 0 && roundQty == 0) {
        if (lowerName.contains('round')) {
          roundQty = qty;
        } else {
          slimQty = qty;
        }
      }
    }

    if (slimQty > 0) {
      final slimIdx = _inventoryItems.indexWhere(
        (p) => p['id'] == 'item_slim_gallon' || p['name'].toString().toLowerCase().contains('slim'),
      );
      if (slimIdx != -1) {
        final capacity = (_inventoryItems[slimIdx]['capacity'] as num).toDouble();
        final currentStock = (_inventoryItems[slimIdx]['stock'] as num).toDouble();
        final newStock = currentStock + slimQty;
        _inventoryItems[slimIdx]['capacity'] = max(capacity, newStock);
        _inventoryItems[slimIdx]['stock'] = newStock;
        _syncInventoryToSupabase(_inventoryItems[slimIdx], action: 'update');
      }
    }

    if (roundQty > 0) {
      final roundIdx = _inventoryItems.indexWhere(
        (p) => p['id'] == 'item_round_gallon' || p['name'].toString().toLowerCase().contains('round'),
      );
      if (roundIdx != -1) {
        final capacity = (_inventoryItems[roundIdx]['capacity'] as num).toDouble();
        final currentStock = (_inventoryItems[roundIdx]['stock'] as num).toDouble();
        final newStock = currentStock + roundQty;
        _inventoryItems[roundIdx]['capacity'] = max(capacity, newStock);
        _inventoryItems[roundIdx]['stock'] = newStock;
        _syncInventoryToSupabase(_inventoryItems[roundIdx], action: 'update');
      }
    }

    // 3. Refund any accessories included in the order summary
    final addonRegex = RegExp(r'(\d+)\s*x\s*([^,+]+)');
    for (final m in addonRegex.allMatches(name)) {
      final aQty = int.tryParse(m.group(1) ?? '0') ?? 0;
      final aName = (m.group(2) ?? '').trim().toLowerCase();
      if (aQty > 0 && aName.isNotEmpty) {
        final aIdx = _inventoryItems.indexWhere(
          (i) => i['category'] == 'accessory' && aName.contains(i['name'].toString().toLowerCase()),
        );
        if (aIdx != -1) {
          refundItemStockById(_inventoryItems[aIdx]['id'] as String, aQty);
        }
      }
    }

    notifyListeners();
    InventoryStorage.saveInventory(_inventoryItems);
  }

  void deductItemStockById(String id, int qty) {
    final idx = _inventoryItems.indexWhere((i) => i['id'] == id);
    if (idx != -1) {
      final currentStock = (_inventoryItems[idx]['stock'] as num).toDouble();
      _inventoryItems[idx]['stock'] = max(0.0, currentStock - qty);
      _syncInventoryToSupabase(_inventoryItems[idx], action: 'update');
      notifyListeners();
      InventoryStorage.saveInventory(_inventoryItems);
    }
  }

  void refundItemStockById(String id, int qty) {
    final idx = _inventoryItems.indexWhere((i) => i['id'] == id);
    if (idx != -1) {
      final capacity = (_inventoryItems[idx]['capacity'] as num).toDouble();
      final currentStock = (_inventoryItems[idx]['stock'] as num).toDouble();
      final newStock = currentStock + qty;
      _inventoryItems[idx]['capacity'] = max(capacity, newStock);
      _inventoryItems[idx]['stock'] = newStock;
      _syncInventoryToSupabase(_inventoryItems[idx], action: 'update');
      notifyListeners();
      InventoryStorage.saveInventory(_inventoryItems);
    }
  }

  void initializeOperatingStocks() {
    for (final item in _inventoryItems) {
      final id = item['id'];
      if (id == 'prod_purified') {
        item['stock'] = 10000.0;
        item['capacity'] = 10000.0;
        item['unit'] = 'Liters';
        item['name'] = 'Purified Water Reservoir';
      } else if (id == 'prod_set_a') {
        item['stock'] = 30.0;
        item['capacity'] = 50.0;
      } else if (id == 'item_slim_gallon') {
        item['stock'] = 50.0;
        item['capacity'] = 100.0;
      } else if (id == 'item_round_gallon') {
        item['stock'] = 50.0;
        item['capacity'] = 100.0;
      }
      _syncInventoryToSupabase(item, action: 'update');
    }
    notifyListeners();
    InventoryStorage.saveInventory(_inventoryItems);
  }

  Future<void> _syncInventoryToSupabase(Map<String, dynamic> item, {required String action}) async {
    if (!_isSupabaseConfigured) return;
    try {
      final client = Supabase.instance.client;
      if (action == 'insert' || action == 'update') {
        final payload = <String, dynamic>{
          'id': item['id'],
          'name': item['name'],
          'category': item['category'],
          'unit': item['unit'],
          'price': item['price'],
          'stock': item['stock'],
          'capacity': item['capacity'],
          'description': item['description'] ?? '',
          'is_refill': item['is_refill'] ?? false,
          'is_active': item['is_active'] ?? true,
        };
        try {
          await client.from('inventory').upsert(payload);
        } catch (e) {
          // If remote table does not have is_refill or is_active column yet, fall back gracefully
          if (payload.containsKey('is_refill')) {
            payload.remove('is_refill');
          }
          if (payload.containsKey('is_active')) {
            payload.remove('is_active');
          }
          await client.from('inventory').upsert(payload);
        }
      } else if (action == 'delete') {
        await client.from('inventory').delete().eq('id', item['id']);
      }
    } catch (e) {
      debugPrint('Supabase inventory sync: $e');
    }
  }

  Future<void> _syncRestockLogToSupabase(Map<String, dynamic> log) async {
    if (!_isSupabaseConfigured) return;
    try {
      final client = Supabase.instance.client;
      await client.from('inventory_logs').insert({
        'item_id': log['itemId'],
        'item_name': log['itemName'],
        'amount': log['amount'],
        'previous_stock': log['previousStock'],
        'new_stock': log['newStock'],
        'unit': log['unit'],
        'restocked_by': log['restockedBy'],
        'notes': log['notes'],
        'created_at': (log['timestamp'] as DateTime).toIso8601String(),
      });
    } catch (e) {
      debugPrint('Supabase restock log sync (optional table): $e');
    }
  }

  RealtimeChannel? _inventoryRealtimeChannel;
  StreamSubscription? _inventorySubscription;

  void _listenToSupabaseInventory() {
    if (!_isSupabaseConfigured) return;
    try {
      final client = Supabase.instance.client;

      // 1. Direct channel for instant Postgres Change broadcast
      _inventoryRealtimeChannel = client
          .channel('public:inventory_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'inventory',
            callback: (payload) {
              if (payload.eventType == PostgresChangeEvent.delete) {
                final deletedId = payload.oldRecord['id']?.toString();
                if (deletedId != null && deletedId.isNotEmpty) {
                  _deletedProductIds.add(deletedId);
                  InventoryStorage.saveDeletedProductIds(_deletedProductIds);
                  _inventoryItems.removeWhere((p) => p['id'] == deletedId);
                  InventoryStorage.saveInventory(_inventoryItems);
                  notifyListeners();
                }
              }
              fetchSupabaseInventory(silent: true);
            },
          )
          .subscribe();

      // 2. Realtime Stream
      _inventorySubscription = client
          .from('inventory')
          .stream(primaryKey: ['id'])
          .listen(
            (List<Map<String, dynamic>> response) {
              if (response.isNotEmpty) {
                _processSupabaseInventoryResponse(response);
              }
            },
            onError: (error) {
              debugPrint('Supabase Realtime Inventory stream error: $error');
            },
          );
    } catch (e) {
      debugPrint('Supabase Realtime Inventory stream setup failed: $e');
    }
  }

  void _processSupabaseInventoryResponse(List<dynamic> response) {
    bool hasChanges = false;
    final fetchedIds = <String>{};

    for (final row in response) {
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      if (_deletedProductIds.contains(id) ||
          id == 'item_electric_pump' ||
          id == 'item_manual_pump' ||
          id == 'item_dispenser_caps') {
        continue;
      }
      fetchedIds.add(id);

      final idx = _inventoryItems.indexWhere((i) => i['id'] == id);
      final newStock = (row['stock'] as num?)?.toDouble() ?? 0.0;
      final newCap = (row['capacity'] as num?)?.toDouble() ?? 100.0;
      final newPrice = (row['price'] as num?)?.toDouble() ?? 0.0;
      final newName = row['name']?.toString() ?? '';
      final newUnit = row['unit']?.toString() ?? 'Units';
      final newCat = row['category']?.toString() ?? 'water';
      final newDesc = row['description']?.toString() ?? '';
      final newIsActive = row['is_active'] is bool ? row['is_active'] as bool : true;
      final newIsRefill = row['is_refill'] is bool
          ? row['is_refill'] as bool
          : (newCat == 'water' &&
              (newUnit.toLowerCase() == 'gallons' ||
                  newName.toLowerCase().contains('refill') ||
                  newName.toLowerCase().contains('19l')));

      if (idx != -1) {
        final cur = _inventoryItems[idx];
        if (cur['stock'] != newStock ||
            cur['capacity'] != newCap ||
            cur['price'] != newPrice ||
            cur['name'] != newName ||
            cur['unit'] != newUnit ||
            cur['category'] != newCat ||
            cur['description'] != newDesc ||
            cur['is_refill'] != newIsRefill ||
            (cur['is_active'] ?? true) != newIsActive) {
          cur['stock'] = newStock;
          cur['capacity'] = newCap;
          cur['price'] = newPrice;
          cur['name'] = newName;
          cur['unit'] = newUnit;
          cur['category'] = newCat;
          cur['description'] = newDesc;
          cur['is_refill'] = newIsRefill;
          cur['is_active'] = newIsActive;
          hasChanges = true;
        }
      } else {
        // New item added in Supabase by Admin!
        _inventoryItems.add({
          'id': id,
          'name': newName,
          'category': newCat,
          'unit': newUnit,
          'price': newPrice,
          'stock': newStock,
          'capacity': newCap,
          'description': newDesc,
          'is_refill': newIsRefill,
          'is_active': newIsActive,
          'color': defaultColorForCategory(newCat),
          'icon': defaultIconForCategory(newCat),
        });
        hasChanges = true;
      }
    }

    // Remove items ONLY if explicitly deleted by Admin
    final toRemove = _inventoryItems.where((i) {
      final id = i['id']?.toString() ?? '';
      return _deletedProductIds.contains(id);
    }).map((i) => i['id'] as String).toList();

    if (toRemove.isNotEmpty) {
      _inventoryItems.removeWhere((i) => toRemove.contains(i['id']));
      hasChanges = true;
    }

    // Auto-seed/sync local items that are missing from Supabase
    for (final localItem in _inventoryItems) {
      final localId = localItem['id']?.toString() ?? '';
      if (localId.isNotEmpty &&
          !fetchedIds.contains(localId) &&
          !_deletedProductIds.contains(localId)) {
        _syncInventoryToSupabase(localItem, action: 'insert');
      }
    }

    if (hasChanges) {
      InventoryStorage.saveInventory(_inventoryItems);
      notifyListeners();
    }
  }

  Future<void> fetchSupabaseInventory({bool silent = false}) async {
    if (!_isSupabaseConfigured) return;
    try {
      final client = Supabase.instance.client;
      final List<dynamic> response = await client.from('inventory').select();
      if (response.isNotEmpty) {
        _processSupabaseInventoryResponse(response);
      }
    } catch (e) {
      debugPrint('Supabase direct fetch inventory error: $e');
    }
  }

  bool get isLoading => _isLoading;
  List<OrderModel> get orders => List.unmodifiable(_orders);

  bool get _isSupabaseConfigured =>
      AppConstants.supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' &&
      AppConstants.supabaseAnonKey != 'YOUR_SUPABASE_PROJECT_ANON_KEY';

  StreamSubscription? _ordersSubscription;

  void _loadLocalInventoryCache() {
    final loadedDeleted = InventoryStorage.loadDeletedProductIds();
    _deletedProductIds.addAll(loadedDeleted);
    _deletedProductIds.add('item_electric_pump');
    _deletedProductIds.add('item_manual_pump');
    _deletedProductIds.add('item_dispenser_caps');
    _deletedProductIds.remove('item_slim_gallon');
    _deletedProductIds.remove('item_round_gallon');
    _inventoryItems.removeWhere((item) => _deletedProductIds.contains(item['id']));

    // Guarantee core 5-gallon containers exist
    if (!_inventoryItems.any((i) => i['id'] == 'item_slim_gallon')) {
      _inventoryItems.add({
        'id': 'item_slim_gallon',
        'name': '5-Gallon Slim Container',
        'category': 'container',
        'unit': 'Units',
        'price': 220.0,
        'stock': 0.0,
        'capacity': 100.0,
        'color': Colors.indigo,
        'icon': Icons.local_drink_rounded,
        'image': 'assets/images/slim_container.jpg',
        'description': 'BPA-free durable slim poly-carbonate gallon jug',
        'is_refill': false,
        'is_active': true,
      });
    }

    if (!_inventoryItems.any((i) => i['id'] == 'item_round_gallon')) {
      _inventoryItems.add({
        'id': 'item_round_gallon',
        'name': '5-Gallon Round Container',
        'category': 'container',
        'unit': 'Units',
        'price': 200.0,
        'stock': 0.0,
        'capacity': 100.0,
        'color': Colors.deepPurple,
        'icon': Icons.crop_portrait_rounded,
        'image': 'assets/images/round_container.jpg',
        'description': 'Heavy-duty standard round water bottle',
        'is_refill': false,
        'is_active': true,
      });
    }

    final cachedLogs = InventoryStorage.loadRestockLogs();
    if (cachedLogs != null && cachedLogs.isNotEmpty) {
      _restockLogs.clear();
      _restockLogs.addAll(cachedLogs);
    }

    final cachedItems = InventoryStorage.loadInventory();
    if (cachedItems != null && cachedItems.isNotEmpty) {
      for (final cached in cachedItems) {
        final id = cached['id']?.toString() ?? '';
        if (id.isEmpty || _deletedProductIds.contains(id)) continue;

        final idx = _inventoryItems.indexWhere((i) => i['id'] == id);
        if (idx != -1) {
          if (cached['stock'] != null) {
            _inventoryItems[idx]['stock'] = (cached['stock'] as num).toDouble();
          }
          if (cached['capacity'] != null) {
            final cap = (cached['capacity'] as num).toDouble();
            _inventoryItems[idx]['capacity'] = cap > 0 ? cap : 100.0;
          }
          if (cached['price'] != null) {
            _inventoryItems[idx]['price'] = (cached['price'] as num).toDouble();
          }
          if (cached['name'] != null) {
            _inventoryItems[idx]['name'] = cached['name'];
          }
          if (cached['unit'] != null) {
            _inventoryItems[idx]['unit'] = cached['unit'];
          }
          if (cached['description'] != null) {
            _inventoryItems[idx]['description'] = cached['description'];
          }
          if (cached['is_active'] != null) {
            _inventoryItems[idx]['is_active'] = cached['is_active'];
          }
          if (cached['is_refill'] != null) {
            _inventoryItems[idx]['is_refill'] = cached['is_refill'] == true;
          }
        } else {
          // Custom items previously saved
          final cat = cached['category']?.toString() ?? 'container';
          final nameStr = cached['name']?.toString() ?? '';
          final unitStr = cached['unit']?.toString() ?? '';
          final isRefill = cached['is_refill'] is bool
              ? cached['is_refill'] as bool
              : (cat == 'water' &&
                  (unitStr.toLowerCase() == 'gallons' ||
                      nameStr.toLowerCase().contains('refill') ||
                      nameStr.toLowerCase().contains('19l')));
          _inventoryItems.add({
            ...cached,
            'is_refill': isRefill,
            'color': defaultColorForCategory(cat),
            'icon': defaultIconForCategory(cat),
            'is_active': cached['is_active'] ?? true,
          });
        }
      }
    }

    // Ensure container capacities are at least 100
    for (final item in _inventoryItems) {
      final id = item['id']?.toString() ?? '';
      if (id == 'item_slim_gallon' || id == 'item_round_gallon') {
        final cap = (item['capacity'] as num?)?.toDouble() ?? 0.0;
        if (cap <= 0.0) item['capacity'] = 100.0;
      }
    }

    final cachedReserves = InventoryStorage.loadReserves();
    if (cachedReserves != null) {
      if (!((cachedReserves['empty'] == 0 || cachedReserves['empty'] == null) &&
          (cachedReserves['refilled'] == 0 || cachedReserves['refilled'] == null))) {
        _emptyContainerStocks = cachedReserves['empty'] ?? 50;
        _refilledContainerStocks = cachedReserves['refilled'] ?? 50;
      }
    }

    final cachedReturns = InventoryStorage.loadReturnedGallonOrders();
    if (cachedReturns != null) {
      _returnedGallonOrderIds.addAll(cachedReturns);
    }
  }

  OrderProvider() {
    _loadLocalInventoryCache();
    if (_isSupabaseConfigured) {
      // 1. Initial direct fetch
      fetchSupabaseOrders();
      fetchSupabaseInventory();
      // 2. Realtime Stream
      _listenToSupabaseOrders();
      _listenToSupabaseInventory();
      // 3. Fallback sync polling every 3 seconds for guaranteed cross-device sync
      _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        fetchSupabaseOrders(silent: true);
        fetchSupabaseInventory(silent: true);
      });
    } else {
      _seedMockOrders();
    }
  }

  Future<void> fetchSupabaseOrders({bool silent = false}) async {
    if (!_isSupabaseConfigured) return;
    try {
      final client = Supabase.instance.client;
      final List<dynamic> response = await client.from('orders').select();
      
      final fetched = response
          .map((item) => OrderModel.fromJson(item as Map<String, dynamic>))
          .toList();

      // Sort newest first
      fetched.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (fetched.isNotEmpty) {
        // Detect if there are changes compared to current in-memory orders
        bool hasChanges = _orders.length != fetched.length;
        if (!hasChanges) {
          for (int i = 0; i < fetched.length; i++) {
            if (_orders[i].id != fetched[i].id ||
                _orders[i].orderStatus != fetched[i].orderStatus ||
                _orders[i].paymentStatus != fetched[i].paymentStatus ||
                _orders[i].driverId != fetched[i].driverId) {
              hasChanges = true;
              break;
            }
          }
        }

        _orders.clear();
        _orders.addAll(fetched);
        if (hasChanges || !silent) {
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Supabase direct fetch orders error: $e');
    }
  }

  void _listenToSupabaseOrders() {
    if (!_isSupabaseConfigured) return;
    try {
      final client = Supabase.instance.client;
      _ordersSubscription = client
          .from('orders')
          .stream(primaryKey: ['id'])
          .listen(
            (List<Map<String, dynamic>> response) {
              final fetched = response
                  .map((item) => OrderModel.fromJson(item))
                  .toList();
              
              // Sort newest first
              fetched.sort((a, b) => b.createdAt.compareTo(a.createdAt));

              _orders.clear();
              _orders.addAll(fetched);
              notifyListeners();
            },
            onError: (error) {
              debugPrint('Supabase Realtime Orders stream error: $error');
            },
          );
    } catch (e) {
      debugPrint('Supabase Realtime Orders stream setup failed: $e');
    }
  }

  @override
  void dispose() {
    _inventoryRealtimeChannel?.unsubscribe();
    _inventorySubscription?.cancel();
    _ordersSubscription?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  // Customer Actions

  Future<OrderModel> placeOrder({
    required String customerId,
    required String customerName,
    required String customerPhone,
    required String deliveryAddress,
    required String waterType,
    required int quantity,
    required double pricePerUnit,
    required String paymentMethod,
    double? customTotalAmount,
    Map<String, int>? addonItems,
    String? paymentStatus,
    OrderStatus? orderStatus,
    String? driverId,
    String? driverName,
    String? deliveryNote,
    double? latitude,
    double? longitude,
    bool isWalkIn = false,
    bool isBorrowingContainers = false,
    int? borrowedSlimQty,
    int? borrowedRoundQty,
  }) async {
    _isLoading = true;
    notifyListeners();

    final randomNum = 1000 + Random().nextInt(8999);
    final orderId = '#ORD-00$randomNum';
    final txnId = '#TXN-88$randomNum';
    final totalAmount = customTotalAmount ?? (pricePerUnit * quantity);

    String taggedAddress = deliveryAddress;
    if (isBorrowingContainers) {
      final slim = borrowedSlimQty ?? 0;
      final round = borrowedRoundQty ?? 0;
      if (!taggedAddress.contains('[BORROWED_SLIM:') && !taggedAddress.contains('[BORROWED_ROUND:')) {
        taggedAddress = '$taggedAddress [BORROWED_SLIM:$slim] [BORROWED_ROUND:$round]';
      }
    }

    final newOrder = OrderModel(
      id: orderId,
      txnId: txnId,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryAddress: taggedAddress,
      waterType: waterType,
      quantity: quantity,
      pricePerUnit: pricePerUnit,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus ?? 'Pending',
      orderStatus: orderStatus ?? (driverId != null ? OrderStatus.assigned : OrderStatus.pending),
      driverId: driverId,
      driverName: driverName,
      createdAt: DateTime.now(),
      distance: '${(1.0 + Random().nextDouble() * 3.0).toStringAsFixed(1)} km',
      deliveryNote: (deliveryNote != null && deliveryNote.trim().isNotEmpty)
          ? deliveryNote.trim()
          : null,
      latitude: latitude,
      longitude: longitude,
      isBorrowingContainers: isBorrowingContainers,
      borrowedSlimCount: borrowedSlimQty,
      borrowedRoundCount: borrowedRoundQty,
    );

    final bool isOrderWalkIn = isWalkIn ||
        customerId == 'usr_walkin_guest' ||
        deliveryAddress.toLowerCase().contains('walk-in') ||
        deliveryAddress.toLowerCase().contains('pickup');

    _orders.insert(0, newOrder);
    deductProductStock(
      waterType,
      quantity,
      isWalkIn: isOrderWalkIn,
      isBorrowingContainers: isBorrowingContainers,
      borrowedSlimQty: borrowedSlimQty,
      borrowedRoundQty: borrowedRoundQty,
    );
    if (addonItems != null) {
      addonItems.forEach((id, qty) {
        if (qty > 0) {
          deductItemStockById(id, qty);
        }
      });
    }

    if (_isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        
        // Use clean JSON with camelCase and standard columns
        final insertMap = {
          'id': newOrder.id,
          'txnId': newOrder.txnId,
          'customerId': newOrder.customerId,
          'customerName': newOrder.customerName,
          'customerPhone': newOrder.customerPhone,
          'deliveryAddress': newOrder.deliveryAddress,
          'waterType': newOrder.waterType,
          'quantity': newOrder.quantity,
          'pricePerUnit': newOrder.pricePerUnit,
          'totalAmount': newOrder.totalAmount,
          'paymentMethod': newOrder.paymentMethod,
          'paymentStatus': newOrder.paymentStatus,
          'orderStatus': newOrder.orderStatus.name,
          'createdAt': newOrder.createdAt.toIso8601String(),
          'distance': newOrder.distance,
        };
        if (newOrder.driverId != null) {
          insertMap['driverId'] = newOrder.driverId!;
        }
        if (newOrder.driverName != null) {
          insertMap['driverName'] = newOrder.driverName!;
        }
        if (newOrder.deliveryNote != null) {
          insertMap['deliveryNote'] = newOrder.deliveryNote!;
        }
        if (newOrder.latitude != null) {
          insertMap['latitude'] = newOrder.latitude!;
        }
        if (newOrder.longitude != null) {
          insertMap['longitude'] = newOrder.longitude!;
        }
        if (newOrder.isBorrowingContainers) {
          insertMap['isBorrowingContainers'] = true;
          if (newOrder.borrowedSlimCount != null) {
            insertMap['borrowedSlimCount'] = newOrder.borrowedSlimCount!;
          }
          if (newOrder.borrowedRoundCount != null) {
            insertMap['borrowedRoundCount'] = newOrder.borrowedRoundCount!;
          }
        }

        try {
          await client.from('orders').insert(insertMap);
          debugPrint('Successfully inserted order ${newOrder.id} to Supabase!');
        } catch (colErr) {
          debugPrint('Supabase initial insert failed: $colErr. Retrying with safe base columns...');
          // Remove custom columns if they do not exist in the database table
          insertMap.remove('deliveryNote');
          insertMap.remove('isBorrowingContainers');
          insertMap.remove('borrowedSlimCount');
          insertMap.remove('borrowedRoundCount');
          if (newOrder.deliveryNote != null && newOrder.deliveryNote!.isNotEmpty) {
            insertMap['deliveryAddress'] =
                '${newOrder.deliveryAddress} (Note: ${newOrder.deliveryNote})';
          }
          try {
            await client.from('orders').insert(insertMap);
            debugPrint('Successfully inserted order ${newOrder.id} with safe columns!');
          } catch (retryErr) {
            debugPrint('Supabase retry insert failed: $retryErr');
          }
        }
        
        // Refresh immediately with notify
        await fetchSupabaseOrders(silent: false);
      } catch (e) {
        debugPrint('Supabase insert failed: $e');
      }
    }

    _isLoading = false;
    notifyListeners();
    return newOrder;
  }

  // Driver Actions

  Future<bool> acceptJob({
    required String orderId,
    required String driverId,
    required String driverName,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return false;

    // Check if driver already has an active job
    final hasActive = _orders.any(
      (o) => o.driverId == driverId && o.orderStatus == OrderStatus.onDelivery,
    );
    if (hasActive) return false;

    _orders[index].driverId = driverId;
    _orders[index].driverName = driverName;
    _orders[index].orderStatus = OrderStatus.onDelivery;

    // Start live GPS broadcasting for driver
    LocationService().startBroadcasting(
      driverId: driverId,
      driverName: driverName,
      orderId: orderId,
    );

    if (_isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        await client
            .from('orders')
            .update({
              'driverId': driverId,
              'driverName': driverName,
              'orderStatus': OrderStatus.onDelivery.name,
            })
            .eq('id', orderId);
        await fetchSupabaseOrders(silent: true);
      } catch (e) {
        debugPrint('Supabase accept order update error: $e');
      }
    }

    notifyListeners();
    return true;
  }

  Future<bool> completeJob({
    required String orderId,
    required String driverId,
  }) async {
    final index = _orders.indexWhere(
      (o) => o.id == orderId && o.driverId == driverId,
    );
    if (index == -1) return false;

    _orders[index].orderStatus = OrderStatus.completed;
    _orders[index].paymentStatus = 'Paid';
    _orders[index].completedAt = DateTime.now();

    // Stop GPS broadcasting
    LocationService().stopBroadcasting();

    if (_isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        await client
            .from('orders')
            .update({
              'orderStatus': OrderStatus.completed.name,
              'paymentStatus': 'Paid',
              'completedAt': DateTime.now().toIso8601String(),
            })
            .eq('id', orderId);
        await fetchSupabaseOrders(silent: true);
      } catch (e) {
        debugPrint('Supabase complete order update error: $e');
      }
    }

    notifyListeners();
    return true;
  }

  void cashOutDriverEarnings(String driverId) {
    final currentEarnings = getDriverEarnings(driverId);
    if (currentEarnings <= 0) return;

    _driverCashedOutEarnings[driverId] =
        (_driverCashedOutEarnings[driverId] ?? 0.0) + currentEarnings;

    notifyListeners();
  }

  // Admin Actions

  Future<void> confirmOrder(String orderId) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;

    _orders[index].orderStatus = OrderStatus.confirmed;

    if (_isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        await client
            .from('orders')
            .update({'orderStatus': OrderStatus.confirmed.name})
            .eq('id', orderId);
        await fetchSupabaseOrders(silent: true);
      } catch (e) {
        debugPrint('Supabase confirm order update error: $e');
      }
    }

    notifyListeners();
  }

  Future<void> markOrderAsPaid(String orderId) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index].paymentStatus = 'Paid';
      notifyListeners();
    }

    if (_isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        await client
            .from('orders')
            .update({'paymentStatus': 'Paid'})
            .eq('id', orderId);
        await fetchSupabaseOrders(silent: false);
      } catch (e) {
        debugPrint('Supabase mark order paid error: $e');
      }
    }

    notifyListeners();
  }

  Future<void> assignDriver({
    required String orderId,
    required String driverId,
    required String driverName,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;

    _orders[index].driverId = driverId;
    _orders[index].driverName = driverName;
    _orders[index].orderStatus = OrderStatus.assigned;

    if (_isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        await client
            .from('orders')
            .update({
              'driverId': driverId,
              'driverName': driverName,
              'orderStatus': OrderStatus.assigned.name,
            })
            .eq('id', orderId);
        await fetchSupabaseOrders(silent: true);
      } catch (e) {
        debugPrint('Supabase assign driver update error: $e');
      }
    }

    notifyListeners();
  }

  Future<void> updateOrderStatus({
    required String orderId,
    required OrderStatus newStatus,
    String? driverId,
    String? driverName,
  }) async {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;

    final previousStatus = _orders[index].orderStatus;
    _orders[index].orderStatus = newStatus;

    if (newStatus == OrderStatus.completed && previousStatus != OrderStatus.completed) {
      _orders[index].paymentStatus = 'Paid';
      _orders[index].completedAt = DateTime.now();
      LocationService().stopBroadcasting();

      // Automatically resolve borrowed container on delivery completion (driver collects empty exchange jug)
      final lower = _orders[index].waterType.toLowerCase();
      final isNewContainerSale = lower.contains('set a') || lower.contains('new container');
      if (!isNewContainerSale && !_orders[index].isCollectionJob && !_returnedGallonOrderIds.contains(orderId)) {
        returnBorrowedGallons(
          orderId: orderId,
          gallonType: _orders[index].waterType,
          quantity: _orders[index].quantity,
          customerName: _orders[index].customerName,
        );
      }
    } else if (newStatus == OrderStatus.cancelled && previousStatus != OrderStatus.cancelled) {
      // Auto-replenish stock and void any borrow record on order cancellation
      refundProductStock(
        _orders[index].waterType,
        _orders[index].quantity,
        isWalkIn: _orders[index].isWalkIn,
        isBorrowingContainers: _orders[index].isBorrowingContainers,
        borrowedSlimQty: _orders[index].borrowedSlimCount,
        borrowedRoundQty: _orders[index].borrowedRoundCount,
      );
      _returnedGallonOrderIds.remove(orderId);
    }
    if (driverId != null) {
      _orders[index].driverId = driverId;
    }
    if (driverName != null) {
      _orders[index].driverName = driverName;
    }

    if (_isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        final updateData = <String, dynamic>{'orderStatus': newStatus.name};
        if (newStatus == OrderStatus.completed) {
          updateData['paymentStatus'] = 'Paid';
          updateData['completedAt'] = DateTime.now().toIso8601String();
        }
        if (driverId != null) updateData['driverId'] = driverId;
        if (driverName != null) updateData['driverName'] = driverName;

        await client.from('orders').update(updateData).eq('id', orderId);
        await fetchSupabaseOrders(silent: true);
      } catch (e) {
        debugPrint('Supabase admin update order error: $e');
      }
    }

    notifyListeners();
  }

  // Helper Queries

  // Customer Queries
  List<OrderModel> getCustomerOrders(String customerId) {
    if (customerId.isEmpty) return [];
    return _orders.where((o) => o.customerId == customerId).toList();
  }

  List<OrderModel> getCustomerDeliveries(String customerId) {
    if (customerId.isEmpty) return [];
    return _orders.where((o) => o.customerId == customerId).toList();
  }

  int getCustomerRewardPoints(String customerId) {
    if (customerId.isEmpty) return 0;
    final completed = getCustomerOrders(
      customerId,
    ).where((o) => o.orderStatus == OrderStatus.completed);
    int points = 100;
    for (var o in completed) {
      points += o.quantity * 10;
    }
    return points;
  }

  // Driver Queries
  bool _driverMatches(OrderModel o, String driverId, String? driverName, String? driverEmail) {
    final cleanId = driverId.trim();
    final cleanName = driverName?.trim().toLowerCase();
    final cleanEmail = driverEmail?.trim().toLowerCase();

    if (cleanId.isNotEmpty && o.driverId != null && o.driverId == cleanId) {
      return true;
    }
    if (cleanName != null && cleanName.isNotEmpty && o.driverName != null) {
      final oName = o.driverName!.trim().toLowerCase();
      if (oName == cleanName || oName.contains(cleanName) || cleanName.contains(oName)) {
        return true;
      }
    }
    if (cleanEmail != null && cleanEmail.isNotEmpty) {
      if (o.driverId != null && o.driverId!.trim().toLowerCase() == cleanEmail) {
        return true;
      }
      final emailPrefix = cleanEmail.split('@').first;
      if (emailPrefix.length >= 3 && o.driverName != null) {
        if (o.driverName!.toLowerCase().replaceAll(' ', '').contains(emailPrefix)) {
          return true;
        }
      }
    }
    return false;
  }

  List<OrderModel> getAvailableDriverJobs(String driverId, {String? driverName, String? driverEmail}) {
    return _orders
        .where(
          (o) =>
              (o.orderStatus == OrderStatus.assigned || o.orderStatus == OrderStatus.confirmed) &&
              (o.driverId == null || o.driverId!.isEmpty || _driverMatches(o, driverId, driverName, driverEmail)),
        )
        .toList();
  }

  List<OrderModel> getAssignedDriverJobs(String driverId, {String? driverName, String? driverEmail}) {
    return _orders
        .where(
          (o) =>
              o.orderStatus == OrderStatus.assigned && _driverMatches(o, driverId, driverName, driverEmail),
        )
        .toList();
  }

  OrderModel? getActiveDriverJob(String driverId, {String? driverName, String? driverEmail}) {
    final list = _orders.where(
      (o) => o.orderStatus == OrderStatus.onDelivery && _driverMatches(o, driverId, driverName, driverEmail),
    );
    return list.isNotEmpty ? list.first : null;
  }

  List<OrderModel> getDriverCompletedJobs(String driverId, {String? driverName, String? driverEmail}) {
    return _orders
        .where(
          (o) =>
              o.orderStatus == OrderStatus.completed && _driverMatches(o, driverId, driverName, driverEmail),
        )
        .toList();
  }

  double getDriverEarnings(String driverId) {
    final completed = getDriverCompletedJobs(driverId);
    double gross = 0.0;
    for (var job in completed) {
      gross += job.totalAmount * 0.5;
    }
    final cashedOut = _driverCashedOutEarnings[driverId] ?? 0.0;
    return max(0.0, gross - cashedOut);
  }

  // Admin Analytics Queries
  double getTotalRevenue() {
    double total = 0.0;
    for (var order in _orders) {
      if (order.orderStatus == OrderStatus.completed ||
          order.paymentStatus == 'Paid') {
        total += order.totalAmount;
      }
    }
    return total;
  }

  int getCompletedCount() {
    return _orders.where((o) => o.orderStatus == OrderStatus.completed).length;
  }

  int getPendingCount() {
    return _orders.where((o) => o.orderStatus == OrderStatus.pending).length;
  }

  int getActiveDeliveriesCount() {
    return _orders.where((o) => o.orderStatus == OrderStatus.onDelivery).length;
  }

  void _seedMockOrders() {
    // Fallback seed when Supabase is not configured
  }
}
