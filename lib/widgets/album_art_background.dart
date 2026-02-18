import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state_provider.dart';
import '../providers/url_resolver.dart';

/// Displays the current track's album art centered with shadow and placeholder.
class AlbumArtBackground extends ConsumerWidget {
  const AlbumArtBackground({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final queueState = ref.watch(playerStateProvider);
    final currentTrack = queueState.currentTrack;
    final urlResolver = ref.read(urlResolverProvider);

    final imageUrl =
        currentTrack?.album?.image?.large ??
        currentTrack?.album?.image?.small ??
        currentTrack?.album?.image?.thumbnail;
    final resolvedImageUrl = imageUrl != null
        ? urlResolver.abs(imageUrl)
        : null;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: resolvedImageUrl != null
                    ? Image.network(
                        resolvedImageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildPlaceholder(theme);
                        },
                      )
                    : _buildPlaceholder(theme),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.album,
        size: 120,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
      ),
    );
  }
}
