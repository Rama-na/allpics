import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../events/domain/my_event.dart';
import '../../providers.dart';
import '../controllers/active_event_controller.dart';

/// "Posting to: `<event>`" pill over the viewfinder; tap to switch between
/// the user's live, postable events.
class EventContextChip extends ConsumerWidget {
  const EventContextChip({super.key, required this.active});

  final MyEvent active;

  Future<void> _switchEvent(BuildContext context, WidgetRef ref) async {
    final postable = ref.read(postableEventsProvider);
    if (postable.length < 2) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                'Post to which event?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final candidate in postable)
              ListTile(
                leading: Icon(
                  candidate.isHost
                      ? Icons.workspace_premium_rounded
                      : Icons.group_rounded,
                ),
                title: Text(candidate.event.title),
                subtitle: Text(candidate.isHost ? 'Hosting' : 'Joined'),
                trailing: candidate.event.id == active.event.id
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.of(context).pop(candidate.event.id),
              ),
          ],
        ),
      ),
    );
    if (selected != null) {
      ref.read(activeEventControllerProvider.notifier).select(selected);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canSwitch = ref.watch(postableEventsProvider).length > 1;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Semantics(
        button: canSwitch,
        label: 'Posting to ${active.event.title}',
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          onTap: canSwitch ? () => _switchEvent(context, ref) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.send_rounded, size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Posting to: ${active.event.title}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                if (canSwitch) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more_rounded,
                      size: 16, color: Colors.white70),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
