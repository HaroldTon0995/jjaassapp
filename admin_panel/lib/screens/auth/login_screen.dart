import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/helpers.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
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
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
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
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Helpers.showSnackBar(context, 'Login successful! Welcome back.');
      final user = authProvider.currentUser;
      if (user != null) {
        _routeToDashboard(user.role);
      }
    } else {
      Helpers.showSnackBar(
        context,
        authProvider.errorMessage ?? 'Authentication failed.',
        isError: true,
      );
    }
  }

  void _routeToDashboard(UserRole role) {
    switch (role) {
      case UserRole.customer:
        Helpers.showSnackBar(
          context,
          'Customer accounts must use the Mobile App.',
          isError: true,
        );
        break;
      case UserRole.driver:
        Helpers.showSnackBar(
          context,
          'Driver accounts must use the Mobile App.',
          isError: true,
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
            const SizedBox(height: 28),
            CustomTextField(
              controller: _emailController,
              labelText: 'Email Address',
              hintText: 'Enter your email address',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
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
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: Icons.lock_outlined,
              isPassword: true,
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
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
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
                      text: 'Sign In',
                      isLoading: auth.isLoading,
                      onPressed: _handleLogin,
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
                        onPressed: auth.isLoading
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
