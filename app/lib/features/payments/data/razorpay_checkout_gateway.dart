import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/utils/app_logger.dart';
import '../domain/payment_models.dart';
import '../domain/payments_repository.dart';

/// [CheckoutGateway] backed by the Razorpay Flutter SDK (Android/iOS).
class RazorpayCheckoutGateway implements CheckoutGateway {
  static final _log = AppLogger.get('checkout');

  @override
  Future<CheckoutResult> openCheckout({
    required RazorpayOrder order,
    String? prefillEmail,
  }) async {
    final razorpay = Razorpay();
    final completer = Completer<CheckoutResult>();

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (dynamic response) {
      final r = response as PaymentSuccessResponse;
      _log.info('payment success ${r.paymentId}');
      if (!completer.isCompleted) {
        completer.complete(CheckoutResult.success(r.paymentId ?? ''));
      }
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (dynamic response) {
      final r = response as PaymentFailureResponse;
      _log.warning('payment error ${r.code}: ${r.message}');
      if (!completer.isCompleted) {
        completer.complete(
          r.code == Razorpay.PAYMENT_CANCELLED
              ? const CheckoutResult.cancelled()
              : CheckoutResult.failure(
                  'Payment failed. Nothing was charged — try again.'),
        );
      }
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (dynamic _) {
      // External wallets settle via webhook; treat as pending success UX.
      if (!completer.isCompleted) {
        completer.complete(const CheckoutResult.success(''));
      }
    });

    razorpay.open({
      'key': order.keyId,
      'order_id': order.orderId,
      'amount': order.amountInr,
      'currency': order.currency,
      'name': 'AllPics',
      'description': '${order.planName} plan — ${order.eventTitle}',
      if (prefillEmail != null) 'prefill': {'email': prefillEmail},
      'theme': {'color': '#6C5CE7'},
    });

    try {
      return await completer.future;
    } finally {
      razorpay.clear();
    }
  }
}
