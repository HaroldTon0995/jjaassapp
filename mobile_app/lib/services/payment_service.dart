import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';

class PaymentResponse {
  final String orderId;
  final String paymentIntentId; // Holds link ID (link_xxxx), source ID (src_xxxx), or mock ID
  final String redirectUrl;
  final String status;
  final String? qrCodeUrl;
  final bool isMock;

  PaymentResponse({
    required this.orderId,
    required this.paymentIntentId,
    required this.redirectUrl,
    required this.status,
    this.qrCodeUrl,
    this.isMock = false,
  });

  factory PaymentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentResponse(
      orderId: json['order_id'] ?? '',
      paymentIntentId: json['payment_intent_id'] ?? '',
      redirectUrl: json['redirect_url'] ?? '',
      status: json['status'] ?? 'pending',
      qrCodeUrl: json['qr_code_url'],
      isMock: json['is_mock'] ?? false,
    );
  }
}

class PaymentService {
  final http.Client _client = http.Client();

  // Helper to construct basic auth header
  String _getAuthHeader(String key) {
    return 'Basic ${base64Encode(utf8.encode("$key:"))}';
  }

  /// Initiates a GCash / E-Wallet payment via Supabase Edge Function (PayMongo) or Public Key Sources API.
  Future<PaymentResponse> initiateGCashPayment({
    required String orderId,
    required double amount,
    required String role,
  }) async {
    final publicKey = AppConstants.paymongoPublicKey;
    final successUrl = kIsWeb
        ? Uri.base.origin
        : 'io.supabase.jjaassapp://payment-success?order_id=$orderId';
    final cancelUrl = kIsWeb
        ? Uri.base.origin
        : 'io.supabase.jjaassapp://payment-cancel?order_id=$orderId';

    // 1. Try secure Supabase Edge Function (holds PAYMONGO_SECRET_KEY server-side)
    if (AppConstants.isSupabaseConfigured) {
      try {
        final fnRes = await Supabase.instance.client.functions.invoke(
          'paymongo-checkout',
          body: {
            'action': 'initiate',
            'orderId': orderId,
            'amount': amount,
            'role': role,
            'successUrl': successUrl,
            'cancelUrl': cancelUrl,
          },
        );
        final data = fnRes.data;
        if (data is Map<String, dynamic> &&
            (data['redirect_url']?.toString().isNotEmpty ?? false)) {
          final checkoutUrl = data['redirect_url'].toString();
          return PaymentResponse(
            orderId: orderId,
            paymentIntentId: (data['payment_intent_id'] ?? '').toString(),
            redirectUrl: checkoutUrl,
            status: (data['status'] ?? 'active').toString(),
            qrCodeUrl: getQrCodeUrl(checkoutUrl),
            isMock: false,
          );
        }
      } catch (e) {
        debugPrint('PayMongo Edge Function initiate failed: $e');
      }
    }

    // 2. Fallback: PayMongo Sources API with Public Key (no secret key, no third-party CORS proxies)
    if (publicKey.isNotEmpty && !publicKey.contains('your_public_key_here')) {
      try {
        final amountInCentavos = (amount * 100).round();
        final response = await _client.post(
          Uri.parse('https://api.paymongo.com/v1/sources'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': _getAuthHeader(publicKey),
          },
          body: jsonEncode({
            'data': {
              'attributes': {
                'type': 'gcash',
                'amount': amountInCentavos,
                'currency': 'PHP',
                'redirect': {
                  'success': 'https://jjaass-water.web.app/payment-success?orderId=$orderId',
                  'failed': 'https://jjaass-water.web.app/payment-failed?orderId=$orderId'
                },
                'metadata': {
                  'orderId': orderId,
                }
              }
            }
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final json = jsonDecode(response.body);
          final sourceId = json['data']['id'];
          final checkoutUrl = json['data']['attributes']['redirect']['checkout_url'];
          final status = json['data']['attributes']['status'];

          return PaymentResponse(
            orderId: orderId,
            paymentIntentId: sourceId,
            redirectUrl: checkoutUrl,
            status: status,
            qrCodeUrl: getQrCodeUrl(checkoutUrl),
            isMock: false,
          );
        }
      } catch (e) {
        debugPrint('PayMongo Sources API error: $e');
      }
    }

    // 3. Fallback to Safe In-App Test Mode (Never opens invalid test-sources.paymongo.com URLs)
    debugPrint('Using local sandbox simulation mode for payment.');
    return _mockInitiateGCashPayment(orderId, amount);
  }

  /// Polls or checks PayMongo via Supabase Edge Function or checks the Supabase DB
  Future<bool> checkPaymentStatus(String identifier) async {
    // Mock Mode identifiers
    if (identifier.startsWith('mock_') || identifier.startsWith('src_mock_')) {
      return false;
    }

    // Check PayMongo Checkout Sessions, Links, or Sources via server-side Edge Function
    if (identifier.startsWith('cs_') ||
        identifier.startsWith('link_') ||
        identifier.startsWith('src_')) {
      if (!AppConstants.isSupabaseConfigured) {
        return false;
      }
      try {
        final fnRes = await Supabase.instance.client.functions.invoke(
          'paymongo-checkout',
          body: {
            'action': 'check_status',
            'identifier': identifier,
          },
        );
        final data = fnRes.data;
        if (data is Map && data['paid'] == true) {
          return true;
        }
      } catch (e) {
        debugPrint('PayMongo Edge Function status check failed: $e');
      }
      return false;
    }

    // Otherwise, check Supabase DB for Order ID status updates
    final isSupabaseConfigured = (AppConstants.supabaseUrl != 'YOUR_SUPABASE_PROJECT_URL' &&
        AppConstants.supabaseAnonKey != 'YOUR_SUPABASE_PROJECT_ANON_KEY');
    if (isSupabaseConfigured) {
      try {
        final supabase = Supabase.instance.client;
        final response = await supabase
            .from('orders')
            .select('paymentStatus')
            .eq('id', identifier)
            .single();

        return response['paymentStatus'] == 'Paid';
      } catch (e) {
        debugPrint('Error checking payment status from database: $e');
      }
    }

    return false;
  }

  Future<PaymentResponse> _mockInitiateGCashPayment(String orderId, double amount) async {
    await Future.delayed(AppConstants.apiMockDelay);
    final mockId = 'mock_${DateTime.now().millisecondsSinceEpoch}';

    return PaymentResponse(
      orderId: orderId,
      redirectUrl: '',
      paymentIntentId: mockId,
      status: 'pending',
      qrCodeUrl: 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=JJAASS-GCASH-PAYMENT-ORDER-$orderId',
      isMock: true,
    );
  }

  /// Helper to generate a helper QR Code link for any checkout URL.
  String getQrCodeUrl(String redirectUrl) {
    if (redirectUrl.isEmpty) {
      return 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=JJAASS-GCASH-PAYMENT';
    }
    return 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${Uri.encodeComponent(redirectUrl)}';
  }
}
