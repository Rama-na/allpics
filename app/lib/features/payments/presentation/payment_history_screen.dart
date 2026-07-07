import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/state_views.dart';
import '../domain/payment_models.dart';
import '../providers.dart';

/// The host's payment history with invoice numbers.
class PaymentHistoryScreen extends ConsumerWidget {
  const PaymentHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Payment history')),
      body: paymentsAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: error is AppException
              ? error.message
              : 'Could not load payments.',
          onRetry: () => ref.invalidate(paymentHistoryProvider),
        ),
        data: (payments) {
          if (payments.isEmpty) {
            return const EmptyView(
              icon: Icons.receipt_long_outlined,
              title: 'No payments yet',
              subtitle:
                  'Plan upgrades and their invoices appear here after purchase.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(paymentHistoryProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: payments.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) =>
                  _PaymentTile(payment: payments[index]),
            ),
          );
        },
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (Color color, IconData icon) = switch (payment.status) {
      PaymentStatus.captured => (theme.colorScheme.primary, Icons.check_circle_rounded),
      PaymentStatus.failed => (theme.colorScheme.error, Icons.error_rounded),
      PaymentStatus.refunded => (theme.colorScheme.tertiary, Icons.replay_rounded),
      _ => (theme.colorScheme.onSurfaceVariant, Icons.schedule_rounded),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text('${payment.planName} — ${payment.eventTitle}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          [
            DateFormat.yMMMd().add_jm().format(payment.createdAt),
            payment.status.label,
            if (payment.invoiceNumber != null)
              'Invoice ${payment.invoiceNumber}',
          ].join(' · '),
          maxLines: 2,
        ),
        trailing: Text(payment.amountLabel, style: theme.textTheme.titleMedium),
        onTap: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Payment details'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detail('Event', payment.eventTitle),
                _detail('Plan', payment.planName),
                _detail('Amount', payment.amountLabel),
                _detail('Status', payment.status.label),
                _detail('Date',
                    DateFormat.yMMMd().add_jm().format(payment.createdAt)),
                if (payment.invoiceNumber != null)
                  _detail('Invoice no.', payment.invoiceNumber!),
                if (payment.razorpayOrderId != null)
                  _detail('Order id', payment.razorpayOrderId!),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}
