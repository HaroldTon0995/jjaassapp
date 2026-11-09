import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

abstract class AuthRepository {
  Future<UserModel> login({required String email, required String password});
  Future<UserModel> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  });
  Future<void> logout();
  Future<UserModel?> getCurrentUser();
  Future<void> sendPasswordResetOtp(String email);
  Future<void> resetPasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  });
}

class MockAuthRepository implements AuthRepository {
  // Account store: normalized email -> Map of credentials and user model
  static final Map<String, Map<String, dynamic>> _userStore = {};

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));

    if (email.isEmpty || password.isEmpty) {
      throw Exception('Email and password cannot be empty.');
    }

    final normalizedEmail = email.trim().toLowerCase();
    final account = _userStore[normalizedEmail];

    if (account == null) {
      throw Exception(
        'No account found with this email. Please sign up first.',
      );
    }

    if (account['password'] != password) {
      throw Exception('Incorrect password. Please try again.');
    }

    return account['user'] as UserModel;
  }

  @override
  Future<UserModel> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      throw Exception('All fields are required.');
    }

    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    final normalizedEmail = email.trim().toLowerCase();
    if (_userStore.containsKey(normalizedEmail)) {
      throw Exception(
        'An account with this email already exists. Please log in.',
      );
    }

    final user = UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email.trim(),
      role: role,
    );

    _userStore[normalizedEmail] = {'user': user, 'password': password};

    ApiService.addMockUser(user);

    return user;
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    return null;
  }

  @override
  Future<void> sendPasswordResetOtp(String email) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final normalizedEmail = email.trim().toLowerCase();
    if (!_userStore.containsKey(normalizedEmail)) {
      throw Exception('No account found with this email address.');
    }
  }

  @override
  Future<void> resetPasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final normalizedEmail = email.trim().toLowerCase();
    if (!_userStore.containsKey(normalizedEmail)) {
      throw Exception('No account found with this email address.');
    }
    if (newPassword.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }
    _userStore[normalizedEmail]!['password'] = newPassword;
  }
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Login failed: User record is empty.');
    }

    try {
      // Query profiles table for user details
      final profile = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      return UserModel.fromJson(profile);
    } catch (e) {
      // Fallback if profiles table is not yet migrated
      return UserModel(
        id: user.id,
        name: email.split('@').first,
        email: email,
        role: UserRole.customer,
      );
    }
  }

  @override
  Future<UserModel> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Registration failed: User is empty.');
    }

    final newUser = UserModel(
      id: user.id,
      name: name,
      email: email,
      role: role,
    );

    try {
      // Insert user profile into profiles table
      await _client.from('profiles').insert(newUser.toJson());
    } catch (e) {
      debugPrint('Profiles table insert skipped: $e');
    }

    return newUser;
  }

  @override
  Future<void> logout() async {
    await _client.auth.signOut();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final session = _client.auth.currentSession;
      if (session == null) return null;
      final user = _client.auth.currentUser;
      if (user == null) return null;

      try {
        final profile = await _client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();
        return UserModel.fromJson(profile);
      } catch (e) {
        final email = user.email ?? '';
        return UserModel(
          id: user.id,
          name: email.split('@').first,
          email: email,
          role: UserRole.customer,
        );
      }
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> sendPasswordResetOtp(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty) {
      throw Exception('Please enter your email address.');
    }
    try {
      await _client.auth.resetPasswordForEmail(cleanEmail);
    } catch (e1) {
      debugPrint('Supabase resetPasswordForEmail error: $e1');
      try {
        await _client.auth.signInWithOtp(
          email: cleanEmail,
          shouldCreateUser: false,
        );
      } catch (e2) {
        debugPrint('Supabase signInWithOtp error: $e2');
        final errStr = '$e1 $e2'.toLowerCase();
        if (errStr.contains('magic link') ||
            errStr.contains('unexpected_failure') ||
            errStr.contains('500') ||
            errStr.contains('smtp') ||
            errStr.contains('error sending')) {
          throw Exception(
            'Unable to send verification email: ${e1.toString().replaceAll("Exception: ", "")}. Please check your Supabase Dashboard -> Authentication -> SMTP Settings.',
          );
        }
        throw Exception('Failed to send verification code: ${e2.toString().replaceAll("Exception: ", "")}');
      }
    }
  }

  @override
  Future<void> resetPasswordWithOtp({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim();
    final cleanOtp = otp.trim();
    if (cleanEmail.isEmpty || cleanOtp.isEmpty || newPassword.isEmpty) {
      throw Exception('All fields are required.');
    }
    if (newPassword.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    // Verify 6-digit email OTP (supports both recovery and email token types)
    AuthResponse response;
    try {
      response = await _client.auth.verifyOTP(
        email: cleanEmail,
        token: cleanOtp,
        type: OtpType.recovery,
      );
    } catch (_) {
      response = await _client.auth.verifyOTP(
        email: cleanEmail,
        token: cleanOtp,
        type: OtpType.email,
      );
    }

    if (response.session == null && response.user == null) {
      throw Exception('Invalid or expired 6-digit code. Please request a new one.');
    }

    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }
}
