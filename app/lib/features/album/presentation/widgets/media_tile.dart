import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../domain/album_item.dart';
import '../../providers.dart';

/// One cell in the album grid: thumbnail, video badge, favorite badge.
class MediaTile extends ConsumerWidget {
  const MediaTile({
    super.key,
    required this.item,
    required this.isFavorite,
    this.onTap,
  });

  final AlbumItem item;
  final bool isFavorite;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Videos have no renderable full-size path — only show an image when the
    // worker has produced a thumbnail; photos always render (thumb or full).
    final imagePath = item.isVideo ? item.thumbPath : item.previewPath;

    return Semantics(
      button: onTap != null,
      image: true,
      label:
          '${item.isVideo ? 'Video' : 'Photo'} by ${item.guestName}'
          '${isFavorite ? ', favourite' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Shared-element flight into the media viewer.
              Hero(
                tag: 'media-${item.id}',
                child: imagePath == null
                    ? Container(color: theme.colorScheme.surfaceContainerHighest)
                    : ref
                        .watch(mediaUrlProvider(imagePath))
                        .when(
                          data: (url) => Image.network(
                            url,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) =>
                                progress == null ? child : _placeholder(theme),
                            errorBuilder: (_, _, _) => _broken(theme),
                          ),
                          loading: () => _placeholder(theme),
                          error: (_, _) => _broken(theme),
                        ),
              ),
              if (item.isVideo)
                Center(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 34,
                      color: Colors.white,
                    ),
                  ),
                ),
              // Uploader name scrim
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                  child: Text(
                    item.guestName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (isFavorite)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 18,
                    color: Colors.redAccent,
                  ),
                ),
              if (!item.isReady)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) => Container(
    color: theme.colorScheme.surfaceContainerHighest,
    child: Icon(
      Icons.photo_outlined,
      size: 28,
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );

  Widget _broken(ThemeData theme) => Container(
    color: theme.colorScheme.surfaceContainerHighest,
    child: Icon(
      Icons.broken_image_outlined,
      size: 28,
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );
}
