import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/recaptcha_widget.dart';
import '../../widgets/water_widgets.dart';
import '../../widgets/forgot_password_modal.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _captchaController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _random = Random();
  StreamSubscription<AuthState>? _authSub;

  Timer? _lockoutTimer;
  int _lockoutSeconds = 0;
  int _failedAttempts = 0;
  int _captchaA = 3;
  int _captchaB = 4;
  String _recaptchaToken = '';
  int _recaptchaResetCounter = 0;

  bool get _isLockedOut => _lockoutSeconds > 0;

  @override
  void initState() {
    super.initState();
    _generateCaptcha();
    try {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((
        data,
      ) async {
        if (data.event == AuthChangeEvent.signedIn && mounted) {
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          if (authProvider.currentUser != null) return;
          final ok = await authProvider.checkSession();
          if (!mounted) return;
          if (ok && authProvider.currentUser != null) {
            _routeToDashboard(authProvider.currentUser!.role);
          }
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _captchaController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _generateCaptcha() {
    _captchaA = _random.nextInt(9) + 1;
    _captchaB = _random.nextInt(9) + 1;
    _captchaController.clear();
    _recaptchaToken = '';
    _recaptchaResetCounter++;
  }

  Future<bool> _verifyRecaptchaToken() async {
    if (!AppConstants.isRecaptchaConfigured) return true;
    if (_recaptchaToken.isEmpty) {
      Helpers.showSnackBar(
        context,
        'Please complete the reCAPTCHA human verification first.',
        isError: true,
      );
      return false;
    }
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'verify-recaptcha',
        body: {'token': _recaptchaToken},
      );
      final data = res.data;
      final ok = data is Map && data['success'] == true;
      if (!ok && mounted) {
        setState(() => _generateCaptcha());
        Helpers.showSnackBar(
          context,
          'reCAPTCHA verification failed. Please try again.',
          isError: true,
        );
      }
      return ok;
    } catch (_) {
      if (mounted) {
        Helpers.showSnackBar(
          context,
          'Unable to verify reCAPTCHA. Please try again.',
          isError: true,
        );
      }
      return false;
    }
  }

  String _formatCountdown(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _startLockoutTimer(int seconds) {
    _lockoutTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _lockoutSeconds = seconds;
    });
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_lockoutSeconds <= 1) {
        timer.cancel();
        setState(() {
          _lockoutSeconds = 0;
          _failedAttempts = 0;
          _generateCaptcha();
        });
      } else {
        setState(() {
          _lockoutSeconds--;
        });
      }
    });
  }

  Map<String, int> _parseLockoutRpcResult(dynamic result) {
    if (result is List && result.isNotEmpty && result.first is Map) {
      final row = result.first as Map;
      return {
        'remaining': (row['remaining_seconds'] as num?)?.toInt() ?? 0,
        'attempts': (row['failed_attempts'] as num?)?.toInt() ?? 0,
      };
    }
    if (result is Map) {
      return {
        'remaining': (result['remaining_seconds'] as num?)?.toInt() ?? 0,
        'attempts': (result['failed_attempts'] as num?)?.toInt() ?? 0,
      };
    }
    return {'remaining': 0, 'attempts': 0};
  }

  Future<Map<String, int>> _checkLockoutStatus(String email) async {
    try {
      final res = await Supabase.instance.client.rpc(
        'check_login_lockout',
        params: {'p_email': email},
      );
      return _parseLockoutRpcResult(res);
    } catch (_) {
      return {'remaining': 0, 'attempts': _failedAttempts};
    }
  }

  Future<Map<String, int>> _recordFailedAttempt(String email) async {
    try {
      final res = await Supabase.instance.client.rpc(
        'record_failed_login',
        params: {'p_email': email},
      );
      return _parseLockoutRpcResult(res);
    } catch (_) {
      final nextAttempts = _failedAttempts + 1;
      return {
        'remaining': nextAttempts >= 3 ? 180 : 0,
        'attempts': nextAttempts,
      };
    }
  }

  Future<void> _resetLoginAttempts(String email) async {
    try {
      await Supabase.instance.client.rpc(
        'reset_login_attempts',
        params: {'p_email': email},
      );
    } catch (_) {}
  }

  Future<void> _showWrongPasswordDialog({int? attemptNumber}) async {
    final attemptSuffix = attemptNumber != null && attemptNumber > 0
        ? '\n\nAttempt $attemptNumber of 3'
        : '';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFFDC2626),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Login Failed',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.navyColor,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Invalid email or password. Please check your credentials and try again.$attemptSuffix',
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.45,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.navyColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (mounted && !_isLockedOut) {
      _passwordFocusNode.requestFocus();
    }
  }

  Future<void> _handleLogin() async {
    if (_isLockedOut) return;
    if (!_formKey.currentState!.validate()) return;

    if (AppConstants.isRecaptchaConfigured) {
      final recaptchaOk = await _verifyRecaptchaToken();
      if (!mounted || !recaptchaOk) return;
    }

    final email = _emailController.text.trim();
    final lockStatus = await _checkLockoutStatus(email);
    if (!mounted) return;

    final preRemaining = lockStatus['remaining'] ?? 0;
    if (preRemaining > 0) {
      setState(() {
        _failedAttempts = lockStatus['attempts'] ?? 3;
      });
      _startLockoutTimer(preRemaining);
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      email: email,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      await _resetLoginAttempts(email);
      if (!mounted) return;
      _lockoutTimer?.cancel();
      setState(() {
        _lockoutSeconds = 0;
        _failedAttempts = 0;
      });
      Helpers.showSnackBar(context, 'Login successful! Welcome back.');
      final user = authProvider.currentUser;
      if (user != null) {
        _routeToDashboard(user.role);
      }
    } else {
      final errMsg = (authProvider.errorMessage ?? '').toLowerCase();
      if (errMsg.contains('verify your gmail') ||
          errMsg.contains('email not confirmed')) {
        setState(() {
          _generateCaptcha();
        });
        Helpers.showSnackBar(
          context,
          authProvider.errorMessage!,
          isError: true,
        );
        return;
      }

      final failResult = await _recordFailedAttempt(email);
      if (!mounted) return;

      final remaining = failResult['remaining'] ?? 0;
      final attempts = failResult['attempts'] ?? (_failedAttempts + 1);

      setState(() {
        _failedAttempts = attempts;
        _generateCaptcha();
      });

      if (remaining > 0) {
        _startLockoutTimer(remaining);
      } else {
        await _showWrongPasswordDialog(attemptNumber: attempts);
      }
    }
  }

  Future<void> _showRoleRestrictionDialog(String message) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.gpp_bad_rounded,
                color: Color(0xFFDC2626),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Access Restricted',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.navyColor,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.45,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
            },
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text(
              'Back to Login',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.navyColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _routeToDashboard(UserRole role) async {
    switch (role) {
      case UserRole.customer:
        await Provider.of<AuthProvider>(context, listen: false).logout();
        if (!mounted) return;
        _showRoleRestrictionDialog(
          'Customer accounts cannot log in to the Admin Panel. Please use the Mobile App instead.',
        );
        break;
      case UserRole.driver:
        await Provider.of<AuthProvider>(context, listen: false).logout();
        if (!mounted) return;
        _showRoleRestrictionDialog(
          'Driver accounts cannot log in to the Admin Panel. Please use the Mobile App instead.',
        );
        break;
      case UserRole.admin:
        Navigator.of(context).pushReplacementNamed(AppRoutes.adminDashboard);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 700;

    Widget formContent() {
      return Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Full Brand Header matching JJAASS Water Market Logo
            Center(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.secondaryColor.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: const WaterDropletLogo(size: 76),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'JJAASS',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.navyColor,
                  letterSpacing: 2.2,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 1.8,
                    color: AppTheme.navyColor,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      'WATER MARKET',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.8,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                  Container(
                    width: 22,
                    height: 1.8,
                    color: AppTheme.navyColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Sign in to the Admin Management Console',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedText,
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_isLockedOut) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      color: Color(0xFFDC2626),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Account temporarily locked due to multiple failed attempts. Try again in ${_formatCountdown(_lockoutSeconds)}',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF991B1B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            CustomTextField(
              controller: _emailController,
              labelText: 'Email Address',
              hintText: 'Enter your email address',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLockedOut,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!Helpers.isValidEmail(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            CustomTextField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: Icons.lock_outlined,
              isPassword: true,
              enabled: !_isLockedOut,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 18,
                        color: AppTheme.navyColor,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Human Verification',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.navyColor,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'New challenge',
                        visualDensity: VisualDensity.compact,
                        onPressed: _isLockedOut
                            ? null
                            : () {
                                setState(() {
                                  _generateCaptcha();
                                });
                              },
                        icon: const Icon(
                          Icons.refresh_rounded,
                          size: 20,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (AppConstants.isRecaptchaConfigured)
                    RecaptchaWidget(
                      siteKey: AppConstants.recaptchaSiteKey,
                      resetTrigger: _recaptchaResetCounter,
                      onTokenChanged: (token) {
                        if (mounted) {
                          setState(() => _recaptchaToken = token);
                        }
                      },
                    )
                  else
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppTheme.secondaryColor.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: Text(
                            'What is $_captchaA + $_captchaB?',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.navyColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _captchaController,
                            enabled: !_isLockedOut,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              hintText: 'Answer',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            validator: (value) {
                              final parsed = int.tryParse(value?.trim() ?? '');
                              if (parsed == null) {
                                return 'Enter answer';
                              }
                              if (parsed != _captchaA + _captchaB) {
                                return 'Incorrect answer';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLockedOut
                    ? null
                    : () {
                        ForgotPasswordModal.show(
                          context,
                          initialEmail: _emailController.text.trim(),
                        );
                      },
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                return Column(
                  children: [
                    CustomButton(
                      text: _isLockedOut
                          ? 'Locked (${_formatCountdown(_lockoutSeconds)})'
                          : 'Sign In',
                      isLoading: auth.isLoading,
                      onPressed: _isLockedOut ? null : _handleLogin,
                      gradientColors: const [
                        AppTheme.navyColor,
                        AppTheme.primaryColor,
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.grey.shade300,
                            thickness: 1,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.mutedText,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.grey.shade300,
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: (auth.isLoading || _isLockedOut)
                            ? null
                            : () async {
                                final ok = await auth.signInWithGoogle();
                                if (!ok && context.mounted) {
                                  Helpers.showSnackBar(
                                    context,
                                    auth.errorMessage ??
                                        'Google Sign-In failed.',
                                    isError: true,
                                  );
                                }
                              },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFF4285F4).withValues(
                                  alpha: 0.12,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Text(
                                'G',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: Color(0xFF4285F4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.secondaryColor.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: AppTheme.navyColor,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Contact the system administrator for registration of new accounts.',
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.navyColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.lightBg,
      body: WaveBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Container(
              width: isDesktop ? 460 : double.infinity,
              constraints: const BoxConstraints(maxWidth: 460),
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 40 : 24,
                vertical: isDesktop ? 44 : 32,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.borderColor,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.navyColor.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: formContent(),
            ),
          ),
        ),
      ),
    );
  }
}
