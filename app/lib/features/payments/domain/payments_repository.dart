import 'payment_models.dart';

/// Payments backend contract.
abstract interface class PaymentsRepository {
  /// Active plan catalog, cheapest first.
  Future<List<Plan>> fetchPlans();

  /// Creates a Razorpay order for [planCode] on [eventId] (host-only).
  Future<RazorpayOrder> createOrder({
    required String eventId,
    required String planCode,
  });

  /// The signed-in host's payment history, newest first.
  Future<List<Payment>> fetchPayments();
}

/// Result of a checkout attempt.
class CheckoutResult {
  const CheckoutResult.success(this.paymentId)
      : isSuccess = true,
        message = null;

  const CheckoutResult.failure(this.message)
      : isSuccess = false,
        paymentId = null;

  const CheckoutResult.cancelled()
      : isSuccess = false,
        paymentId = null,
        message = 'Payment cancelled.';

  final bool isSuccess;
  final String? paymentId;
  final String? message;
}

/// Opens the platform checkout UI. Abstracted so tests (and unsupported
/// platforms) can substitute the Razorpay SDK.
abstract interface class CheckoutGateway {
  Future<CheckoutResult> openCheckout({
    required RazorpayOrder order,
    String? prefillEmail,
  });
}
