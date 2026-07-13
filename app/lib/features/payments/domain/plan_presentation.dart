import 'payment_models.dart';

/// Marketing presentation for a [Plan] — bullets, emphasis, value framing.
/// Pure Dart so it stays unit-testable.
extension PlanPresentation on Plan {
  /// The plan we recommend to most hosts.
  bool get isPopular => code == 'plus';

  /// Per-upload value framing (e.g. "₹0.60/upload"); empty for the free plan.
  String get perUploadLabel {
    if (isFree || photoLimit == 0) return '';
    final rupees = priceInr / 100 / photoLimit;
    final label = rupees >= 1
        ? rupees.toStringAsFixed(1)
        : rupees.toStringAsFixed(2);
    return '₹$label/upload';
  }

  /// Plans that include the AI keepsakes (highlights reel + slideshow).
  bool get hasKeepsakes => code == 'plus' || code == 'premium';

  String get tagline => switch (code) {
    'free' => 'A whole party, free — keep it 7 days',
    'basic' => 'Perfect for birthdays and small parties',
    'plus' => 'The sweet spot for weddings and big days',
    'premium' => 'Every moment, kept for a full year',
    _ => '',
  };

  List<String> get bullets => [
    '$photoLimit photos & videos',
    'Album stays live for $storageLabel',
    'Unlimited guests, no guest accounts',
    'Videos up to 250 MB each',
    if (!isFree) 'Full-resolution downloads & AI cleanup',
    if (hasKeepsakes) 'AI highlights reel & slideshow',
    if (code == 'premium') 'Priority processing',
  ];
}
