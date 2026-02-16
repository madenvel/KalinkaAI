import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kai/providers/app_state_provider.dart';
import '../widgets/playbar.dart';
import '../widgets/expandable_queue.dart';
import '../providers/url_resolver.dart';

class MusicPlayerScreen extends ConsumerWidget {
  const MusicPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Main content layer: background + playbar
          Column(
            children: [
              // Main content area
              Expanded(child: _buildBackgroundContent(theme, ref)),
              // Playbar at bottom with color extending beyond safe area
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: SafeArea(top: false, child: const Playbar()),
              ),
            ],
          ),
          // Queue overlay: slides up from bottom, covers everything including playbar
          const Positioned.fill(child: ExpandableQueue()),
        ],
      ),
    );
  }

  Widget _buildBackgroundContent(ThemeData theme, WidgetRef ref) {
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
