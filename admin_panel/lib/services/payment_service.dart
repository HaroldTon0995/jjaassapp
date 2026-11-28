import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';

class PaymentResponse {
  final String orderId;
  final String paymentIntentId; // Holds Xendit charge ID (ewc:...), invoice ID (inv:...), or mock ID
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
  /// Initiates a GCash payment via Xendit through the secure Supabase Edge Function.
  Future<PaymentResponse> initiateGCashPayment({
    required String orderId,
    required double amount,
    required String role,
  }) async {
    final successUrl = kIsWeb
        ? Uri.base.origin
        : 'io.supabase.jjaassapp://payment-success?order_id=$orderId';
    final cancelUrl = kIsWeb
        ? Uri.base.origin
        : 'io.supabase.jjaassapp://payment-cancel?order_id=$orderId';

    if (AppConstants.isSupabaseConfigured) {
      try {
        final fnRes = await Supabase.instance.client.functions.invoke(
          'xendit-checkout',
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
            status: (data['status'] ?? 'PENDING').toString(),
            qrCodeUrl: getQrCodeUrl(checkoutUrl),
            isMock: false,
          );
        }
      } catch (e) {
        debugPrint('Xendit Edge Function initiate failed: $e');
      }
    }

    // Fallback to Safe In-App Test Mode if Edge Function is not yet deployed
    debugPrint('Using local sandbox simulation mode for payment.');
    return _mockInitiateGCashPayment(orderId, amount);
  }

  /// Polls Xendit status via Supabase Edge Function or checks the Supabase DB
  Future<bool> checkPaymentStatus(String identifier) async {
    if (identifier.startsWith('mock_') || identifier.startsWith('src_mock_')) {
      return false;
    }

    if (identifier.startsWith('ewc:') || identifier.startsWith('inv:')) {
      if (!AppConstants.isSupabaseConfigured) {
        return false;
      }
      try {
        final fnRes = await Supabase.instance.client.functions.invoke(
          'xendit-checkout',
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
        debugPrint('Xendit Edge Function status check failed: $e');
      }
      return false;
    }

    // Otherwise, check Supabase DB for Order ID status updates
    if (AppConstants.isSupabaseConfigured) {
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

  /// Helper to generate a QR Code link for any checkout URL.
  String getQrCodeUrl(String redirectUrl) {
    if (redirectUrl.isEmpty) {
      return 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=JJAASS-GCASH-PAYMENT';
    }
    return 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${Uri.encodeComponent(redirectUrl)}';
  }
}
