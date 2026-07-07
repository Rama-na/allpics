import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_env.dart';
import '../../core/errors/app_exception.dart';
import '../auth/providers.dart';
import 'data/razorpay_checkout_gateway.dart';
import 'data/supabase_payments_repository.dart';
import 'domain/payment_models.dart';
import 'domain/payments_repository.dart';

/// Pre-provisioning fallback: the plan catalog still renders (static copy of
/// the seed data) so the UI is complete; purchases fail with a clear message.
class _UnconfiguredPaymentsRepository implements PaymentsRepository {
  const _UnconfiguredPaymentsRepository();

  @override
  Future<List<Plan>> fetchPlans() async => const [
        Plan(id: 'free', code: 'free', name: 'Free', priceInr: 0, photoLimit: 10, storageDays: 30, sortOrder: 0),
        Plan(id: 'basic', code: 'basic', name: 'Basic', priceInr: 15900, photoLimit: 100, storageDays: 30, sortOrder: 1),
        Plan(id: 'plus', code: 'plus', name: 'Plus', priceInr: 29900, photoLimit: 500, storageDays: 30, sortOrder: 2),
        Plan(id: 'premium', code: 'premium', name: 'Premium', priceInr: 59900, photoLimit: 1000, storageDays: 180, sortOrder: 3),
      ];

  @override
  Future<RazorpayOrder> createOrder({
    required String eventId,
    required String planCode,
  }) async =>
      throw const ValidationException(
          'Payments are not available yet — backend not configured.');

  @override
  Future<List<Payment>> fetchPayments() async => const [];
}

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  if (!AppEnv.isSupabaseConfigured) {
    return const _UnconfiguredPaymentsRepository();
  }
  return SupabasePaymentsRepository(ref.watch(supabaseClientProvider));
});

final checkoutGatewayProvider = Provider<CheckoutGateway>((ref) {
  return RazorpayCheckoutGateway();
});

final plansProvider = FutureProvider<List<Plan>>((ref) {
  return ref.watch(paymentsRepositoryProvider).fetchPlans();
});

final paymentHistoryProvider = FutureProvider<List<Payment>>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(paymentsRepositoryProvider).fetchPayments();
});
