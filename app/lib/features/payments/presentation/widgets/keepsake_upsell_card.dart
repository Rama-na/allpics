import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../events/domain/event.dart';
import '../../../events/providers.dart';
import '../../domain/plan_presentation.dart';
import '../../providers.dart';

/// The AI keepsakes surface on the host dashboard.
///
/// The worker already builds highlight albums and slideshow reels — this
/// card finally exposes them: locked (→ plans screen) below Plus, actionable
/// (enqueue RPC) on Plus/Premium.
class KeepsakeUpsellCard extends ConsumerStatefulWidget {
  const KeepsakeUpsellCard({super.key, required this.event});

  final Event event;

  @override
  ConsumerState<KeepsakeUpsellCard> createState() => _KeepsakeUpsellCardState();
}

class _KeepsakeUpsellCardState extends ConsumerState<KeepsakeUpsellCard> {
  final _queued = <String>{};
  String? _busyJob;

  Future<void> _enqueue(String jobType) async {
    setState(() => _busyJob = jobType);
    try {
      await ref
          .read(eventsRepositoryProvider)
          .enqueueKeepsakeJob(widget.event.id, jobType);
      if (!mounted) return;
      setState(() => _queued.add(jobType));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            jobType == 'highlights'
                ? 'Highlights queued — we\'ll pick the best shots shortly.'
                : 'Slideshow queued — your reel is being stitched.',
          ),
        ),
      );
    } on AppException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busyJob = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plans = ref.watch(plansProvider).value;
    final plan = plans?.where((p) => p.id == widget.event.planId).firstOrNull;
    // Until plans load, assume locked (free is the overwhelming default).
    final unlocked = plan?.hasKeepsakes ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'AI keepsakes',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (!unlocked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          size: 12,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Plus',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              unlocked
                  ? 'Turn the album into memories: a best-shots highlights '
                        'reel and a music-ready slideshow.'
                  : 'A best-shots highlights reel and a shareable slideshow, '
                        'built automatically from the album. Included with '
                        'Plus and Premium.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (unlocked)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _busyJob != null || _queued.contains('highlights')
                          ? null
                          : () => _enqueue('highlights'),
                      icon: const Icon(
                        Icons.auto_awesome_motion_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _queued.contains('highlights')
                            ? 'Highlights queued'
                            : 'Highlights',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _busyJob != null || _queued.contains('slideshow')
                          ? null
                          : () => _enqueue('slideshow'),
                      icon: const Icon(Icons.movie_rounded, size: 18),
                      label: Text(
                        _queued.contains('slideshow')
                            ? 'Slideshow queued'
                            : 'Slideshow',
                      ),
                    ),
                  ),
                ],
              )
            else
              FilledButton.tonalIcon(
                onPressed: () => context.pushNamed(
                  AppRoute.plans,
                  pathParameters: {'eventId': widget.event.id},
                ),
                icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                label: const Text('Unlock with Plus'),
              ),
          ],
        ),
      ),
    );
  }
}
