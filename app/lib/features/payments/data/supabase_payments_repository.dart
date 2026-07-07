import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/app_exception.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/payment_models.dart';
import '../domain/payments_repository.dart';

/// Production [PaymentsRepository] backed by Supabase.
class SupabasePaymentsRepository implements PaymentsRepository {
  SupabasePaymentsRepository(this._client);

  final sb.SupabaseClient _client;
  static final _log = AppLogger.get('payments');

  @override
  Future<List<Plan>> fetchPlans() async {
    try {
      final rows = await _client
          .from('plans')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      return rows.map(Plan.fromMap).toList();
    } on sb.PostgrestException catch (e) {
      throw UnexpectedException(cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<RazorpayOrder> createOrder({
    required String eventId,
    required String planCode,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'razorpay-order',
        body: {'event_id': eventId, 'plan_code': planCode},
      );
      return RazorpayOrder.fromMap(res.data as Map<String, dynamic>);
    } on sb.FunctionException catch (e) {
      final details = e.details;
      String? message;
      String code = 'internal';
      if (details is Map<String, dynamic>) {
        final error = details['error'];
        if (error is Map<String, dynamic>) {
          code = (error['code'] as String?) ?? code;
          message = error['message'] as String?;
        }
      }
      _log.warning('order failed: $code (${e.status})');
      throw switch (code) {
        'not_configured' => const ValidationException(
            'Payments are not available yet — try again soon.'),
        'unauthorized' || 'forbidden' => AuthException(
            message ?? 'You cannot purchase for this event.'),
        _ => ValidationException(message ?? 'Could not start the payment.'),
      };
    } catch (e) {
      throw const NetworkException();
    }
  }

  @override
  Future<List<Payment>> fetchPayments() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw const AuthException('You need to sign in first.');
    try {
      final rows = await _client
          .from('payments')
          .select('*, plans(name), events(title)')
          .eq('host_id', uid)
          .order('created_at', ascending: false);
      return rows.map(Payment.fromMap).toList();
    } on sb.PostgrestException catch (e) {
      throw UnexpectedException(cause: e);
    } catch (e) {
      throw const NetworkException();
    }
  }
}
