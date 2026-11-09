import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/helpers.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordModal extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordModal({super.key, this.initialEmail});

  static Future<void> show(BuildContext context, {String? initialEmail}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ForgotPasswordModal(initialEmail: initialEmail),
    );
  }

  @override
  State<ForgotPasswordModal> createState() => _ForgotPasswordModalState();
}

class _ForgotPasswordModalState extends State<ForgotPasswordModal> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _step = 1; // 1 = Request OTP, 2 = Verify OTP & Set New Password
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Brute-force protection: 5 failed attempts = 5-minute lockout
  static int _failedAttempts = 0;
  static DateTime? _lockoutUntil;
  Timer? _countdownTimer;
  int _secondsRemaining = 0;

  bool get _isLockedOut => _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);

  String _formatSeconds(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _checkLockout() {
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      _secondsRemaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
      _startCountdown();
    } else {
      _lockoutUntil = null;
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final diff = _lockoutUntil != null ? _lockoutUntil!.difference(DateTime.now()).inSeconds : 0;
      if (diff <= 0) {
        timer.cancel();
        setState(() {
          _lockoutUntil = null;
          _failedAttempts = 0;
          _secondsRemaining = 0;
        });
      } else {
        setState(() {
          _secondsRemaining = diff;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _checkLockout();
    if (widget.initialEmail != null && widget.initialEmail!.trim().isNotEmpty) {
      _emailController.text = widget.initialEmail!.trim();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    if (_isLockedOut) {
      Helpers.showSnackBar(
        context,
        'Security lockout active. Please wait ${_formatSeconds(_secondsRemaining)} before trying again.',
        isError: true,
      );
      return;
    }

    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      Helpers.showSnackBar(
        context,
        'Please enter a valid email address.',
        isError: true,
      );
      return;
    }

    // Role verification: Only Customer and Driver accounts can reset on the mobile app
    if (AppConstants.isSupabaseConfigured) {
      try {
        final client = Supabase.instance.client;
        final profile = await client
            .from('profiles')
            .select('role')
            .eq('email', email)
            .maybeSingle();

        if (profile != null) {
          final role = profile['role']?.toString().toLowerCase();
          if (role == 'admin') {
            if (!mounted) return;
            Helpers.showSnackBar(
              context,
              'Administrator accounts must be reset via the Admin Management Console.',
              isError: true,
            );
            return;
          }
        }
      } catch (e) {
        debugPrint('Mobile role check error: $e');
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.sendPasswordResetOtp(email);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Helpers.showSnackBar(
        context,
        'A 6-digit verification code has been sent to $email.',
      );
      setState(() => _step = 2);
    } else {
      Helpers.showSnackBar(
        context,
        auth.errorMessage ?? 'Failed to send verification code.',
        isError: true,
      );
    }
  }

  Future<void> _handleResetPassword() async {
    if (_isLockedOut) {
      Helpers.showSnackBar(
        context,
        'Security lockout active. Please wait ${_formatSeconds(_secondsRemaining)} before trying again.',
        isError: true,
      );
      return;
    }

    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    final pass = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (otp.length < 6) {
      Helpers.showSnackBar(
        context,
        'Please enter the full verification code.',
        isError: true,
      );
      return;
    }

    if (pass.length < 6) {
      Helpers.showSnackBar(
        context,
        'New password must be at least 6 characters long.',
        isError: true,
      );
      return;
    }

    if (pass != confirm) {
      Helpers.showSnackBar(
        context,
        'Passwords do not match.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.resetPasswordWithOtp(
      email: email,
      otp: otp,
      newPassword: pass,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _failedAttempts = 0;
      _lockoutUntil = null;
      _countdownTimer?.cancel();
      Navigator.of(context).pop();
      Helpers.showSnackBar(
        context,
        'Password reset successful! You can now sign in with your new password.',
      );
    } else {
      _failedAttempts++;
      if (_failedAttempts >= 5) {
        _lockoutUntil = DateTime.now().add(const Duration(minutes: 5));
        _secondsRemaining = 300;
        _startCountdown();
        Helpers.showSnackBar(
          context,
          'Too many failed attempts! Security lockout activated for 5 minutes.',
          isError: true,
        );
      } else {
        final remaining = 5 - _failedAttempts;
        Helpers.showSnackBar(
          context,
          '${auth.errorMessage ?? 'Invalid verification code.'} ($remaining attempt${remaining == 1 ? '' : 's'} remaining before 5-minute lockout).',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: AppTheme.primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reset Password',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F2B5C),
                          ),
                        ),
                        Text(
                          _step == 1
                              ? 'Enter your registered email'
                              : 'Step 2 of 2: Verify & update',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 24),

              if (_isLockedOut) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock_rounded, color: Colors.red, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Security Lockout Active',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 13),
                            ),
                            Text(
                              '5 failed attempts reached. Try again in ${_formatSeconds(_secondsRemaining)}.',
                              style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_step == 1) ...[
                const Text(
                  'We will send a 6-digit verification code to your email to verify your identity (zero cost).',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: 'Registered Email',
                    hintText: 'e.g. user@gmail.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Send Verification Code',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded, size: 16),
                          ],
                        ),
                ),
              ] else ...[
                Text(
                  'Code sent to ${_emailController.text}. Enter the verification code and choose a new password:',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Verification OTP Code',
                    counterText: '',
                    prefixIcon: const Icon(Icons.pin_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _obscureConfirm = !_obscureConfirm);
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => setState(() => _step = 1),
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleResetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Save & Reset Password',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

