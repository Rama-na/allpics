import 'package:allpics/features/payments/domain/payment_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Plan parses and formats prices/storage', () {
    final plan = Plan.fromMap({
      'id': 'p1',
      'code': 'premium',
      'name': 'Premium',
      'price_inr': 59900,
      'photo_limit': 1000,
      'storage_days': 180,
      'sort_order': 3,
    });
    expect(plan.priceLabel, '₹599');
    expect(plan.storageLabel, '6 months');
    expect(plan.isFree, isFalse);
  });

  test('free plan formatting', () {
    const plan = Plan(
        id: 'p0', code: 'free', name: 'Free', priceInr: 0, photoLimit: 10, storageDays: 30, sortOrder: 0);
    expect(plan.priceLabel, 'Free');
    expect(plan.storageLabel, '30 days');
  });

  test('Payment parses joined plan/event names and status', () {
    final payment = Payment.fromMap({
      'id': 'pay-1',
      'event_id': 'e1',
      'amount_inr': 15900,
      'status': 'captured',
      'created_at': '2026-07-01T10:00:00Z',
      'invoice_number': 'AP-2026-XYZ',
      'razorpay_order_id': 'order_1',
      'plans': {'name': 'Basic'},
      'events': {'title': 'Wedding'},
    });
    expect(payment.planName, 'Basic');
    expect(payment.eventTitle, 'Wedding');
    expect(payment.status, PaymentStatus.captured);
    expect(payment.amountLabel, '₹159');
  });

  test('unknown payment status falls back safely', () {
    expect(PaymentStatus.fromDb('weird'), PaymentStatus.created);
  });

  test('RazorpayOrder parses the Edge Function response', () {
    final order = RazorpayOrder.fromMap({
      'order_id': 'order_9',
      'amount': 29900,
      'currency': 'INR',
      'key_id': 'rzp_test_abc',
      'plan_name': 'Plus',
      'event_title': 'Goa',
    });
    expect(order.orderId, 'order_9');
    expect(order.keyId, 'rzp_test_abc');
    expect(order.amountInr, 29900);
  });
}
