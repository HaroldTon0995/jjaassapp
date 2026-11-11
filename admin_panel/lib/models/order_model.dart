import 'package:flutter/material.dart';

enum OrderStatus {
  pending,
  confirmed,
  assigned,
  onDelivery,
  completed,
  cancelled;

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.assigned:
        return 'Assigned';
      case OrderStatus.onDelivery:
        return 'On Delivery';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.pending:
        return const Color(0xFFF59E0B);
      case OrderStatus.confirmed:
        return const Color(0xFF8B5CF6);
      case OrderStatus.assigned:
        return const Color(0xFFF43F5E);
      case OrderStatus.onDelivery:
        return const Color(0xFF0284C7);
      case OrderStatus.completed:
        return const Color(0xFF10B981);
      case OrderStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }
}

class OrderModel {
  final String id;
  final String txnId;
  final String customerId;
  String customerName;
  final String customerPhone;
  String deliveryAddress;
  final String waterType;
  final int quantity;
  final double pricePerUnit;
  final double totalAmount;
  final String paymentMethod;
  String paymentStatus; // 'Pending' or 'Paid'
  OrderStatus orderStatus;
  String? driverId;
  String? driverName;
  final DateTime createdAt;
  DateTime? completedAt;
  final String distance;
  final double? latitude;
  final double? longitude;
  final String? deliveryNote; // Customer's delivery preference / note
  bool isBorrowingContainers;
  int? borrowedSlimCount;
  int? borrowedRoundCount;
  final bool isCollectionJob;
  bool isGallonReturned;

  OrderModel({
    required this.id,
    required this.txnId,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.waterType,
    required this.quantity,
    required this.pricePerUnit,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.orderStatus,
    this.driverId,
    this.driverName,
    required this.createdAt,
    this.completedAt,
    this.distance = '1.5 km',
    this.latitude,
    this.longitude,
    this.deliveryNote,
    this.isBorrowingContainers = false,
    this.borrowedSlimCount,
    this.borrowedRoundCount,
    this.isCollectionJob = false,
    this.isGallonReturned = false,
  });

  String get formattedTotal => '₱${totalAmount.toStringAsFixed(2)}';
  String get itemsSummary => '$quantity x $waterType';

  bool get isWalkIn =>
      customerId == 'usr_walkin_guest' ||
      deliveryAddress.toLowerCase().contains('walk-in') ||
      deliveryAddress.toLowerCase().contains('pickup');

  bool get requiresDriver => !isWalkIn;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'txnId': txnId,
      'customerId': customerId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      'waterType': waterType,
      'quantity': quantity,
      'pricePerUnit': pricePerUnit,
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'orderStatus': orderStatus.name,
      'driverId': driverId,
      'driverName': driverName,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'distance': distance,
      'latitude': latitude,
      'longitude': longitude,
      'deliveryNote': deliveryNote,
      'isBorrowingContainers': isBorrowingContainers,
      'borrowedSlimCount': borrowedSlimCount,
      'borrowedRoundCount': borrowedRoundCount,
      'isCollectionJob': isCollectionJob,
      'isGallonReturned': isGallonReturned,
    };
  }

  static String _resolveOrderCustomerName(Map<String, dynamic> json) {
    final raw = (json['customerName'] ?? json['customer_name'] ?? '')
        .toString()
        .trim();
    if (raw.isNotEmpty &&
        raw.toLowerCase() != 'new user' &&
        raw.toLowerCase() != 'registered user') {
      return raw;
    }
    final rawPhone = (json['customerPhone'] ?? json['customer_phone'] ?? '')
        .toString()
        .trim();
    if (rawPhone.isNotEmpty && rawPhone != '+63 912 345 6789') {
      return 'Customer ($rawPhone)';
    }
    final rawId = (json['id'] ?? '').toString().trim();
    if (rawId.isNotEmpty) {
      return 'Customer (${rawId.replaceFirst('#', '')})';
    }
    return 'Customer';
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      txnId: json['txnId'] as String,
      customerId: json['customerId'] as String,
      customerName: _resolveOrderCustomerName(json),
      customerPhone: json['customerPhone'] as String? ?? '+63 912 345 6789',
      deliveryAddress: json['deliveryAddress'] as String,
      waterType: json['waterType'] as String,
      quantity: (json['quantity'] as num).toInt(),
      pricePerUnit: (json['pricePerUnit'] as num).toDouble(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      paymentMethod: json['paymentMethod'] as String,
      paymentStatus: json['paymentStatus'] as String,
      orderStatus: OrderStatus.values.byName(json['orderStatus'] as String),
      driverId: json['driverId'] as String?,
      driverName: json['driverName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      distance: json['distance'] as String? ?? '1.5 km',
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      deliveryNote: json['deliveryNote'] as String?,
      isBorrowingContainers:
          (json['deliveryAddress']?.toString().contains('[GALLONS_RETURNED]') ??
              false)
          ? false
          : (json['isBorrowingContainers'] == true ||
                json['is_borrowing_containers'] == true ||
                ((json['deliveryAddress']?.toString().contains('[BORROWED_') ??
                        false) &&
                    !(json['deliveryAddress']?.toString().contains(
                          '[GALLONS_RETURNED]',
                        ) ??
                        false))),
      borrowedSlimCount:
          (json['borrowedSlimCount'] ?? json['borrowed_slim_count'] as num?)
              ?.toInt() ??
          (() {
            final addr = json['deliveryAddress']?.toString() ?? '';
            final match = RegExp(r'\[BORROWED_SLIM:(\d+)\]').firstMatch(addr);
            return match != null ? int.tryParse(match.group(1)!) : null;
          })(),
      borrowedRoundCount:
          (json['borrowedRoundCount'] ?? json['borrowed_round_count'] as num?)
              ?.toInt() ??
          (() {
            final addr = json['deliveryAddress']?.toString() ?? '';
            final match = RegExp(r'\[BORROWED_ROUND:(\d+)\]').firstMatch(addr);
            return match != null ? int.tryParse(match.group(1)!) : null;
          })(),
      isCollectionJob:
          json['isCollectionJob'] == true ||
          json['is_collection_job'] == true ||
          (json['waterType']?.toString().toLowerCase().contains('collection') ??
              false) ||
          (json['paymentMethod']?.toString().toLowerCase().contains(
                'collection',
              ) ??
              false) ||
          (json['deliveryNote']?.toString().toLowerCase().contains(
                'weekly empty gallon retrieval',
              ) ??
              false) ||
          (json['deliveryNote']?.toString().toLowerCase().contains(
                'weekly full route collection',
              ) ??
              false) ||
          (json['deliveryNote']?.toString().toLowerCase().contains(
                'weekly regular collection',
              ) ??
              false),
      isGallonReturned:
          json['isGallonReturned'] == true ||
          json['is_gallon_returned'] == true ||
          (json['deliveryAddress']?.toString().contains('[GALLONS_RETURNED]') ??
              false) ||
          (json['deliveryNote']?.toString().contains('[GALLONS_RETURNED]') ??
              false),
    );
  }
}
