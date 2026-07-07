import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// In-app privacy policy.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _sections = <(String, String)>[
    (
      'What we collect',
      'Hosts: name, email, and the events you create. Guests: the display '
          'name you enter when joining and an optional phone number. '
          'Media: the photos and videos you choose to upload to an event.',
    ),
    (
      'How media is used',
      'Uploads are visible only to members of that event — the host and '
          'joined guests. Media is never used for advertising or shared with '
          'third parties. Automatic processing (thumbnails, duplicate '
          'detection, highlights) happens solely to improve your album.',
    ),
    (
      'Storage & retention',
      'Media is stored securely on Supabase infrastructure and is deleted '
          'when an event expires per its plan (30 days to 6 months) or when '
          'the host deletes the event.',
    ),
    (
      'Payments',
      'Payments are processed by Razorpay. AllPics never sees or stores your '
          'card, UPI, or banking details — only the order status and invoice.',
    ),
    (
      'Your rights',
      'Hosts can delete their account at any time from Settings, which '
          'permanently removes their profile, events, and all associated '
          'media. Guests can ask an event host to remove their uploads.',
    ),
    (
      'Contact',
      'Questions or data requests: privacy@allpics.app',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Last updated: July 2026',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.md),
          for (final (title, body) in _sections) ...[
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(body, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }
}
