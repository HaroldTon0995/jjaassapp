import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';

class ApiService {
  final _random = Random();

  bool get isSupabaseConfigured => (AppConstants.supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' &&
          AppConstants.supabaseAnonKey != 'YOUR_SUPABASE_PROJECT_ANON_KEY');

  // Dynamic registered users list for local operations when Supabase is not configured
  static final List<UserModel> _registeredUsersList = [];

  // Expose static helper to add new users registered locally
  static void addMockUser(UserModel user) {
    final index = _registeredUsersList.indexWhere((u) => u.id == user.id || u.email.toLowerCase() == user.email.toLowerCase());
    if (index != -1) {
      _registeredUsersList[index] = user;
    } else {
      _registeredUsersList.add(user);
    }
  }

  // Mock fetching dashboard stats for customers
  Future<Map<String, dynamic>> getCustomerDashboardData() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return {
      'activeOrders': _random.nextInt(3),
      'pastDeliveries': 12 + _random.nextInt(10),
      'rewardPoints': 250 + _random.nextInt(100),
      'recentTransactions': [
        {'id': 'TX_1001', 'amount': '\$24.50', 'status': 'Delivered', 'date': 'Today'},
        {'id': 'TX_0989', 'amount': '\$12.80', 'status': 'Delivered', 'date': 'Yesterday'},
      ],
    };
  }

  // Mock fetching driver dashboard stats
  Future<Map<String, dynamic>> getDriverDashboardData() async {
    await Future.delayed(const Duration(milliseconds: 900));
    return {
      'todaysEarnings': 120.0 + _random.nextInt(80),
      'completedTrips': 5 + _random.nextInt(5),
      'rating': 4.7 + (_random.nextDouble() * 0.3),
      'onlineStatus': true,
      'availableJobs': [
        {'id': 'JOB_223', 'distance': '2.1 miles', 'payout': '\$14.50', 'destination': 'Downtown Center'},
        {'id': 'JOB_224', 'distance': '4.5 miles', 'payout': '\$22.00', 'destination': 'Uptown Galleria'},
      ],
    };
  }

  // Fetching system reports for admin - queries Supabase if available
  Future<Map<String, dynamic>> getAdminDashboardData() async {
    int totalUsersCount = _registeredUsersList.length;
    int activeDriversCount = _registeredUsersList.where((u) => u.role == UserRole.driver).length;
    int activeCustomersCount = _registeredUsersList.where((u) => u.role == UserRole.customer).length;

    if (isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        
        // Query user tables and check length
        final usersRes = await client.from('profiles').select();
        totalUsersCount = usersRes.length;
        
        final driversRes = await client.from('profiles').select().eq('role', 'driver');
        activeDriversCount = driversRes.length;
        
        final customersRes = await client.from('profiles').select().eq('role', 'customer');
        activeCustomersCount = customersRes.length;
      } catch (e) {
        // Fallback silently if query fails
      }
    }

    await Future.delayed(const Duration(milliseconds: 1000));
    return {
      'totalUsers': totalUsersCount,
      'activeDrivers': activeDriversCount,
      'activeCustomers': activeCustomersCount,
      'dailyRevenue': 4850.50 + _random.nextInt(1200),
      'systemAlerts': [
        {'type': 'Warning', 'message': 'High driver demand in Sector B', 'time': '10 mins ago'},
        {'type': 'Info', 'message': 'System database backups completed', 'time': '1 hr ago'},
        {'type': 'Warning', 'message': 'High latency on authentication endpoint', 'time': '3 hrs ago'},
        {'type': 'Info', 'message': 'New driver registration pending approval', 'time': '4 hrs ago'},
      ],
    };
  }

  // Fetch list of users for administration
  Future<List<UserModel>> getAdminUsers() async {
    if (isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        final res = await client.from('profiles').select();
        return (res as List).map((u) => UserModel.fromJson(u as Map<String, dynamic>)).toList();
      } catch (e) {
        // Fallback silently if query fails
      }
    }
    await Future.delayed(AppConstants.apiMockDelay);
    return List.from(_registeredUsersList);
  }

  // Update a user role (Admin accounts cannot be modified; only Driver and Customer roles can be set)
  Future<bool> updateUserRole(String userId, UserRole role) async {
    if (role == UserRole.admin) return false;

    if (isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        final check = await client.from('profiles').select('role').eq('id', userId).maybeSingle();
        if (check != null && (check['role'] == 'admin' || check['role'] == 'customer')) {
          return false; // Customer and Admin roles cannot be changed
        }
        await client.from('profiles').update({'role': role.name}).eq('id', userId);
        return true;
      } catch (e) {
        // Fallback silently if query fails
      }
    }
    await Future.delayed(AppConstants.apiMockDelay);
    final index = _registeredUsersList.indexWhere((u) => u.id == userId);
    if (index != -1) {
      if (_registeredUsersList[index].role == UserRole.admin || _registeredUsersList[index].role == UserRole.customer) {
        return false; // Customer and Admin roles cannot be changed
      }
      final oldUser = _registeredUsersList[index];
      _registeredUsersList[index] = UserModel(
        id: oldUser.id,
        name: oldUser.name,
        email: oldUser.email,
        role: role,
      );
      return true;
    }
    return false;
  }

  // Permanently delete a user account from Supabase and local cache
  Future<bool> deleteUserAccount(String userId) async {
    if (isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        try {
          // Attempt RPC deletion first (removes from public.profiles and auth.users)
          await client.rpc('delete_user_by_admin', params: {'target_user_id': userId});
        } catch (_) {
          // Fallback to direct profiles table deletion
          await client.from('profiles').delete().eq('id', userId);
        }
      } catch (e) {
        debugPrint('Supabase delete user error: $e');
      }
    }
    _registeredUsersList.removeWhere((u) => u.id == userId);
    return true;
  }

  // Create a new Customer, Driver, or Administrator account directly from Admin Panel without public sign-up
  Future<UserModel?> createUserAccount({
    required String name,
    required String email,
    required UserRole role,
    String? password,
    String? phone,
    String? address,
  }) async {
    String assignedId = 'usr_${DateTime.now().millisecondsSinceEpoch}';

    if (isSupabaseConfigured) {
      if (password != null && password.isNotEmpty) {
        final signupUri = Uri.parse('${AppConstants.supabaseUrl}/auth/v1/signup');
        final response = await http.post(
          signupUri,
          headers: {
            'apikey': AppConstants.supabaseAnonKey,
            'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'email': email.trim(),
            'password': password.trim(),
            'data': {
              'name': name.trim(),
              'role': role.name,
              if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
              if (address != null && address.isNotEmpty) 'address': address.trim(),
            },
          }),
        );

        final dynamic responseBody = jsonDecode(response.body);
        if (response.statusCode == 200 || response.statusCode == 201) {
          if (responseBody is Map<String, dynamic>) {
            final authUserId = (responseBody['id'] as String?) ??
                (responseBody['user'] is Map ? (responseBody['user'] as Map)['id'] as String? : null);
            if (authUserId != null && authUserId.isNotEmpty) {
              assignedId = authUserId;
            }
          }
        } else {
          final errorMsg = responseBody is Map
              ? (responseBody['msg'] ?? responseBody['message'] ?? responseBody['error_description'])
              : null;
          final message = errorMsg?.toString() ?? 'Registration failed with status code ${response.statusCode}';
          if (message.toLowerCase().contains('already registered') || message.toLowerCase().contains('already exists')) {
            // Attempt to retrieve existing auth user UUID if credentials match
            try {
              final tokenUri = Uri.parse('${AppConstants.supabaseUrl}/auth/v1/token?grant_type=password');
              final tokenRes = await http.post(
                tokenUri,
                headers: {
                  'apikey': AppConstants.supabaseAnonKey,
                  'Authorization': 'Bearer ${AppConstants.supabaseAnonKey}',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({
                  'email': email.trim(),
                  'password': password.trim(),
                }),
              );
              if (tokenRes.statusCode == 200) {
                final tokenData = jsonDecode(tokenRes.body) as Map<String, dynamic>;
                final authUserId = (tokenData['user'] is Map ? (tokenData['user'] as Map)['id'] as String? : null) ??
                    (tokenData['id'] as String?);
                if (authUserId != null && authUserId.isNotEmpty) {
                  assignedId = authUserId;
                }
              }
            } catch (_) {}

            if (assignedId.startsWith('usr_')) {
              throw Exception(
                'Email ($email) already exists in Supabase Authentication (Authentication > Users). Please delete it in Supabase or use a different email.',
              );
            }
          } else {
            throw Exception(message);
          }
        }
      }

      final client = Supabase.instance.client;
      await client.from('profiles').upsert({
        'id': assignedId,
        'name': name.trim(),
        'email': email.trim(),
        'role': role.name,
        if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
        if (address != null && address.isNotEmpty) 'address': address.trim(),
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    final newUser = UserModel(
      id: assignedId,
      name: name.trim(),
      email: email.trim(),
      role: role,
    );

    _registeredUsersList.removeWhere((u) => u.email.toLowerCase() == email.trim().toLowerCase());
    _registeredUsersList.insert(0, newUser);
    return newUser;
  }
}
