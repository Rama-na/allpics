import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/upload_task.dart';
import '../controllers/upload_queue_controller.dart';
import 'upload_task_tile.dart';

/// The guest's upload panel: picker button, live queue with per-file
/// progress, retry actions, and quota-full messaging.
class UploadPanel extends ConsumerWidget {
  const UploadPanel({super.key, required this.eventId, required this.isFull});

  final String eventId;

  /// Whether the event album is already at its photo limit.
  final bool isFull;

  Future<void> _pickAndUpload(WidgetRef ref) async {
    final files = await ImagePicker().pickMultipleMedia();
    if (files.isEmpty) return;
    await ref
        .read(uploadQueueControllerProvider.notifier)
        .addFiles(eventId, files);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final queue = ref.watch(uploadQueueControllerProvider);
    final tasks =
        queue.tasks.where((t) => t.eventId == eventId).toList(growable: false);
    final blocked = isFull || queue.hasBlocked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (blocked)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Row(
              children: [
                Icon(Icons.photo_library_outlined,
                    color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'This album is full. Ask your host to upgrade the plan '
                    'to keep the photos coming.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          AppButton(
            label: 'Add photos & videos',
            icon: Icons.add_photo_alternate_rounded,
            onPressed: () => _pickAndUpload(ref),
          ),
        if (tasks.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${queue.successCount} of ${tasks.length} uploaded',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (queue.failedCount > 0)
                TextButton.icon(
                  onPressed: () => ref
                      .read(uploadQueueControllerProvider.notifier)
                      .retryAllFailed(),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text('Retry ${queue.failedCount}'),
                ),
              if (queue.successCount > 0 && !queue.isProcessing)
                TextButton(
                  onPressed: () => ref
                      .read(uploadQueueControllerProvider.notifier)
                      .clearCompleted(),
                  child: const Text('Clear done'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...tasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: UploadTaskTile(
                task: task,
                onRetry: task.isRetryable
                    ? () => ref
                        .read(uploadQueueControllerProvider.notifier)
                        .retry(task.id)
                    : null,
              ),
            ),
          ),
          if (queue.allDone && queue.failedCount == 0 && !queue.hasBlocked)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      'All uploads complete. Thank you!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        // Offline reassurance: queued tasks are persisted and resumed.
        if (tasks.any((t) => t.status == UploadTaskStatus.queued)) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Uploads resume automatically — you can keep using your phone.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
