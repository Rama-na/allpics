import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/upload_task.dart';

/// One row in the guest upload queue: name, size, progress, retry.
class UploadTaskTile extends StatelessWidget {
  const UploadTaskTile({super.key, required this.task, this.onRetry});

  final UploadTask task;
  final VoidCallback? onRetry;

  static String formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (IconData statusIcon, Color statusColor) = switch (task.status) {
      UploadTaskStatus.queued => (
          Icons.schedule_rounded,
          theme.colorScheme.onSurfaceVariant
        ),
      UploadTaskStatus.uploading => (
          Icons.cloud_upload_rounded,
          theme.colorScheme.primary
        ),
      UploadTaskStatus.success => (
          Icons.check_circle_rounded,
          AppColors.success
        ),
      UploadTaskStatus.failed => (
          Icons.error_rounded,
          theme.colorScheme.error
        ),
      UploadTaskStatus.blocked => (
          Icons.block_rounded,
          theme.colorScheme.error
        ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  task.kind == MediaKind.video
                      ? Icons.videocam_rounded
                      : Icons.photo_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.fileName,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        task.error ?? formatBytes(task.totalBytes),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: task.error != null
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (task.isRetryable && onRetry != null)
                  IconButton(
                    tooltip: 'Retry',
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                  )
                else
                  Icon(statusIcon, size: 22, color: statusColor),
              ],
            ),
            if (task.status == UploadTaskStatus.uploading) ...[
              const SizedBox(height: AppSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                child: LinearProgressIndicator(
                  value: task.progress > 0 ? task.progress : null,
                  minHeight: 6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
