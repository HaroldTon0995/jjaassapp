import 'dart:math';

class AppConstants {
  // App general info
  static const String appName = 'JJAASSApp';

  // Role Names
  static const String roleCustomer = 'customer';
  static const String roleDriver = 'driver';
  static const String roleAdmin = 'admin';

  // Mock latencies and timings
  static const Duration apiMockDelay = Duration(milliseconds: 800);
  static const Duration splashDelay = Duration(seconds: 2);

  // Layout limits & Padding values
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double borderRadius = 12.0;

  // Shared Preferences or Storage Keys (if needed)
  static const String keyUserRole = 'user_role';
  static const String keyIsLoggedIn = 'is_logged_in';

  // Supabase Configuration
  // IMPORTANT: Replace these placeholders with your actual Supabase project credentials.
  static const String supabaseUrl = 'https://iahwdukcdgtrxomigjth.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlhaHdkdWtjZGd0cnhvbWlnanRoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM4OTI2NDMsImV4cCI6MjA5OTQ2ODY0M30.hsYowVzhwKSGdfaGn_Qlpz2dGQpky15dLNuXbmwV7V8';

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && !supabaseUrl.contains('YOUR_SUPABASE');

  // PayMongo Keys Configuration
  // Replace these with your actual keys from the PayMongo dashboard settings
  static const String paymongoSecretKey = 'sk_test_ktY7QC25rmHyB3Qt1jAnHtLt';
  static const String paymongoPublicKey = 'pk_test_Y2Rq8RD2whVztowJYaEaAo7p';

  // Gemini API Configuration for AquaBot Support
  // Get your free Gemini API key at: https://aistudio.google.com/app/apikey
  // You can paste your key here, pass --dart-define=GEMINI_API_KEY=your_key,
  // or set it directly inside the AquaBot chat header in the app.
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  // Mapbox Public Access Token for Maps & Directions API
  static const String mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
    defaultValue:
        'pk.eyJ1IjoiaGFyb2xkYm9yYm8wOTA4IiwiYSI6ImNtd2Z4N29yeTA3cGEyenB3a2Fxc2k3eXcifQ.x3vsYQm8-awub-o59syruQ',
  );

  static String mapboxTileUrl(int z, int x, int y, {bool satellite = false}) {
    final style = satellite ? 'satellite-streets-v12' : 'streets-v12';
    return 'https://api.mapbox.com/styles/v1/mapbox/$style/tiles/256/$z/$x/$y@2x?access_token=$mapboxAccessToken';
  }

  // Exact Business Origin Coordinates: 7R96+J8H, Bacacay, Albay
  static const String defaultStationPlusCode = '7R96+J8H, Bacacay, Albay';
  static const double defaultStationLat = 13.269063;
  static const double defaultStationLng = 123.810859;

  static String stationPlusCode = defaultStationPlusCode;
  static double stationLat = defaultStationLat;
  static double stationLng = defaultStationLng;

  static void updateStationOrigin({
    required double lat,
    required double lng,
    String? plusCode,
  }) {
    stationLat = lat;
    stationLng = lng;
    if (plusCode != null && plusCode.trim().isNotEmpty) {
      stationPlusCode = plusCode.trim();
    }
  }

  static void resetStationOrigin() {
    stationLat = defaultStationLat;
    stationLng = defaultStationLng;
    stationPlusCode = defaultStationPlusCode;
  }

  static double calculateDistanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lng2 - lng1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }
}
