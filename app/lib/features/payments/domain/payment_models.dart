/// A purchasable plan (mirrors the `plans` table; prices in paise).
class Plan {
  const Plan({
    required this.id,
    required this.code,
    required this.name,
    required this.priceInr,
    required this.photoLimit,
    required this.storageDays,
    required this.sortOrder,
  });

  final String id;
  final String code;
  final String name;

  /// Paise (₹159 == 15900).
  final int priceInr;
  final int photoLimit;
  final int storageDays;
  final int sortOrder;

  bool get isFree => priceInr == 0;

  String get priceLabel =>
      isFree ? 'Free' : '₹${(priceInr / 100).toStringAsFixed(0)}';

  String get storageLabel =>
      storageDays >= 180 ? '${storageDays ~/ 30} months' : '$storageDays days';

  factory Plan.fromMap(Map<String, dynamic> map) => Plan(
        id: map['id'] as String,
        code: map['code'] as String,
        name: map['name'] as String,
        priceInr: (map['price_inr'] as num).toInt(),
        photoLimit: (map['photo_limit'] as num).toInt(),
        storageDays: (map['storage_days'] as num).toInt(),
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      );
}

/// Payment lifecycle states (mirrors `payment_status`).
enum PaymentStatus {
  created('created', 'Started'),
  authorized('authorized', 'Authorized'),
  captured('captured', 'Paid'),
  failed('failed', 'Failed'),
  refunded('refunded', 'Refunded');

  const PaymentStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static PaymentStatus fromDb(String? value) => PaymentStatus.values
      .firstWhere((s) => s.dbValue == value, orElse: () => PaymentStatus.created);
}

/// A payment record with joined plan and event names for history display.
class Payment {
  const Payment({
    required this.id,
    required this.eventId,
    required this.eventTitle,
    required this.planName,
    required this.amountInr,
    required this.status,
    required this.createdAt,
    this.invoiceNumber,
    this.razorpayOrderId,
  });

  final String id;
  final String eventId;
  final String eventTitle;
  final String planName;
  final int amountInr;
  final PaymentStatus status;
  final DateTime createdAt;
  final String? invoiceNumber;
  final String? razorpayOrderId;

  String get amountLabel => '₹${(amountInr / 100).toStringAsFixed(0)}';

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
        id: map['id'] as String,
        eventId: map['event_id'] as String,
        eventTitle:
            ((map['events'] as Map<String, dynamic>?)?['title'] as String?) ??
                'Event',
        planName:
            ((map['plans'] as Map<String, dynamic>?)?['name'] as String?) ??
                'Plan',
        amountInr: (map['amount_inr'] as num).toInt(),
        status: PaymentStatus.fromDb(map['status'] as String?),
        createdAt: DateTime.parse(map['created_at'] as String),
        invoiceNumber: map['invoice_number'] as String?,
        razorpayOrderId: map['razorpay_order_id'] as String?,
      );
}

/// Order details returned by the `razorpay-order` Edge Function.
class RazorpayOrder {
  const RazorpayOrder({
    required this.orderId,
    required this.amountInr,
    required this.currency,
    required this.keyId,
    required this.planName,
    required this.eventTitle,
  });

  final String orderId;
  final int amountInr;
  final String currency;

  /// Public Razorpay key id — provided by the server, never bundled.
  final String keyId;
  final String planName;
  final String eventTitle;

  factory RazorpayOrder.fromMap(Map<String, dynamic> map) => RazorpayOrder(
        orderId: map['order_id'] as String,
        amountInr: (map['amount'] as num).toInt(),
        currency: (map['currency'] as String?) ?? 'INR',
        keyId: map['key_id'] as String,
        planName: (map['plan_name'] as String?) ?? '',
        eventTitle: (map['event_title'] as String?) ?? '',
      );
}
