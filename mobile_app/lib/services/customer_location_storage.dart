import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import 'customer_location_storage_stub.dart'
    if (dart.library.js_interop) 'customer_location_storage_web.dart'
    if (dart.library.html) 'customer_location_storage_web.dart'
    if (dart.library.io) 'customer_location_storage_io.dart';

class CustomerLocationData {
  final double latitude;
  final double longitude;
  final String? addressLabel;
  final String? landmark;
  final DateTime updatedAt;

  CustomerLocationData({
    required this.latitude,
    required this.longitude,
    this.addressLabel,
    this.landmark,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'addressLabel': addressLabel,
        'landmark': landmark,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory CustomerLocationData.fromJson(Map<String, dynamic> json) =>
      CustomerLocationData(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        addressLabel: json['addressLabel'] as String?,
        landmark: json['landmark'] as String?,
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
      );

  String get formattedCoordinates =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  String get displayAddress {
    if (addressLabel != null && addressLabel!.trim().isNotEmpty) {
      if (landmark != null && landmark!.trim().isNotEmpty) {
        return '$addressLabel (${landmark!.trim()})';
      }
      return addressLabel!.trim();
    }
    final coords = 'GPS Pin ($formattedCoordinates)';
    if (landmark != null && landmark!.trim().isNotEmpty) {
      return '$coords - ${landmark!.trim()}';
    }
    return coords;
  }
}

class CustomerLocationStorage {
  static const String _defaultKey = 'jjaass_customer_pinned_location_v1';

  static String _getKey(String? userId) {
    if (userId != null && userId.trim().isNotEmpty) {
      return '${_defaultKey}_${userId.trim()}';
    }
    return _defaultKey;
  }

  static bool get _isSupabaseConfigured =>
      AppConstants.supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' &&
      AppConstants.supabaseAnonKey != 'YOUR_SUPABASE_PROJECT_ANON_KEY';

  /// Saves the pinned location permanently to local storage & Supabase (if configured)
  static Future<void> savePinnedLocation({
    required double latitude,
    required double longitude,
    String? addressLabel,
    String? landmark,
    String? userId,
  }) async {
    final locationData = CustomerLocationData(
      latitude: latitude,
      longitude: longitude,
      addressLabel: addressLabel,
      landmark: landmark,
      updatedAt: DateTime.now(),
    );

    try {
      final jsonStr = jsonEncode(locationData.toJson());
      // Save for user-specific key
      await LocationStoragePlatform.saveString(_getKey(userId), jsonStr);
      // Also save for global key so it's instantly available
      await LocationStoragePlatform.saveString(_defaultKey, jsonStr);
      debugPrint(
        'CustomerLocationStorage: Saved permanent location: ${locationData.formattedCoordinates}',
      );
    } catch (e) {
      debugPrint('CustomerLocationStorage save error: $e');
    }

    // Sync to Supabase user profile in background if available
    if (_isSupabaseConfigured && userId != null && userId.isNotEmpty) {
      try {
        final client = Supabase.instance.client;
        await client.from('profiles').update({
          'latitude': latitude,
          'longitude': longitude,
          if (addressLabel != null && addressLabel.isNotEmpty)
            'address': addressLabel,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
        debugPrint(
          'CustomerLocationStorage: Synced location to Supabase profile.',
        );
      } catch (e) {
        debugPrint('CustomerLocationStorage Supabase sync error: $e');
      }
    }
  }

  /// Loads the saved permanent pinned location
  static Future<CustomerLocationData?> loadPinnedLocation({
    String? userId,
  }) async {
    try {
      // 1. Try loading user-specific key
      String? raw = await LocationStoragePlatform.getString(_getKey(userId));
      // 2. Fallback to default key
      raw ??= await LocationStoragePlatform.getString(_defaultKey);

      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        return CustomerLocationData.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('CustomerLocationStorage load error: $e');
    }

    // 3. Fallback to Supabase if configured and user is logged in
    if (_isSupabaseConfigured && userId != null && userId.isNotEmpty) {
      try {
        final client = Supabase.instance.client;
        final res = await client
            .from('profiles')
            .select('latitude, longitude, address')
            .eq('id', userId)
            .maybeSingle();

        if (res != null &&
            res['latitude'] != null &&
            res['longitude'] != null) {
          final lat = (res['latitude'] as num).toDouble();
          final lng = (res['longitude'] as num).toDouble();
          final addr = res['address'] as String?;
          final data = CustomerLocationData(
            latitude: lat,
            longitude: lng,
            addressLabel: addr,
          );
          // Cache locally
          await savePinnedLocation(
            latitude: lat,
            longitude: lng,
            addressLabel: addr,
            userId: userId,
          );
          return data;
        }
      } catch (e) {
        debugPrint('CustomerLocationStorage Supabase profile load error: $e');
      }
    }

    return null;
  }

  /// Clears the saved pinned location
  static Future<void> clearPinnedLocation({String? userId}) async {
    try {
      await LocationStoragePlatform.removeKey(_getKey(userId));
      await LocationStoragePlatform.removeKey(_defaultKey);
    } catch (e) {
      debugPrint('CustomerLocationStorage clear error: $e');
    }
  }
}
