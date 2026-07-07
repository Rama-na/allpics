import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../providers.dart';

/// Checkout flow state machine.
sealed class CheckoutState {
  const CheckoutState();
}

class CheckoutIdle extends CheckoutState {
  const CheckoutIdle();
}

class CheckoutProcessing extends CheckoutState {
  const CheckoutProcessing(this.planCode);

  final String planCode;
}

/// Payment accepted — the webhook applies the upgrade; the dashboard's
/// realtime stream reflects the new quota within moments.
class CheckoutSuccess extends CheckoutState {
  const CheckoutSuccess(this.planName);

  final String planName;
}

class CheckoutFailure extends CheckoutState {
  const CheckoutFailure(this.message);

  final String message;
}

class CheckoutController extends Notifier<CheckoutState> {
  @override
  CheckoutState build() => const CheckoutIdle();

  Future<void> purchase({
    required String eventId,
    required String planCode,
    String? prefillEmail,
  }) async {
    if (state is CheckoutProcessing) return;
    state = CheckoutProcessing(planCode);
    try {
      final order = await ref.read(paymentsRepositoryProvider).createOrder(
            eventId: eventId,
            planCode: planCode,
          );
      final result = await ref
          .read(checkoutGatewayProvider)
          .openCheckout(order: order, prefillEmail: prefillEmail);
      state = result.isSuccess
          ? CheckoutSuccess(order.planName)
          : CheckoutFailure(result.message ?? 'Payment failed.');
    } on AppException catch (e) {
      state = CheckoutFailure(e.message);
    }
  }

  void reset() => state = const CheckoutIdle();
}

final checkoutControllerProvider =
    NotifierProvider<CheckoutController, CheckoutState>(CheckoutController.new);
