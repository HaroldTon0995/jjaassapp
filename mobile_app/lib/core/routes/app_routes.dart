import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/register_screen.dart';
import '../../screens/customer/customer_dashboard.dart';
import '../../screens/driver/driver_dashboard.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String customerDashboard = '/customer';
  static const String driverDashboard = '/driver';
  static const String adminDashboard = '/admin';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final routeName = settings.name ?? '';
    if (routeName.contains('code=') ||
        routeName.contains('login-callback')) {
      return MaterialPageRoute(builder: (_) => const LoginScreen());
    }
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case customerDashboard:
        return MaterialPageRoute(builder: (_) => const CustomerDashboard());
      case driverDashboard:
        return MaterialPageRoute(builder: (_) => const DriverDashboard());
      case adminDashboard:
        return MaterialPageRoute(
          builder: (ctx) => Scaffold(
            backgroundColor: AppTheme.lightBg,
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  margin: const EdgeInsets.all(24),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.gpp_bad_rounded,
                            color: Color(0xFFDC2626),
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Access Restricted',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.navyColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Admin accounts cannot log in to the mobile application. Only Customer and Driver accounts can log in here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            color: Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(ctx).pushNamedAndRemoveUntil(
                                AppRoutes.login,
                                (route) => false,
                              );
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
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}
