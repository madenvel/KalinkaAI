import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data_model/data_model.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/url_resolver.dart';
import '../../theme/app_theme.dart';
import '../procedural_album_art.dart';

/// Context menu for the + button (Mode A and long-press escape hatch).
/// Shows Play Next, Append to Queue, and optionally Add to Playlist.
class AddContextMenu extends ConsumerWidget {
  final BrowseItem item;
  final Offset anchorPosition;
  final VoidCallback? onConfirm;

  /// When false, the "Add to playlist…" option is hidden.
  /// Set to false for album-level, artist top-tracks, and playlist-level menus.
  final bool showAddToPlaylist;

  const AddContextMenu({
    super.key,
    required this.item,
    required this.anchorPosition,
    this.onConfirm,
    this.showAddToPlaylist = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenSize = MediaQuery.of(context).size;

    // Position menu near the anchor, constrained to screen
    double top = anchorPosition.dy - 80;
    double left = anchorPosition.dx - 200;
    if (top < 60) top = 60;
    if (left < 16) left = 16;
    if (left + 220 > screenSize.width - 16) {
      left = screenSize.width - 236;
    }

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        child: Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOutQuart,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.92 + 0.08 * value,
                    alignment: Alignment.topRight,
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: _buildMenu(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context, WidgetRef ref) {
    final track = item.track;
    final album = item.album;
    final playlist = item.playlist;
    final artist = item.artist;

    // Determine title and descriptor for the preview header
    final title =
        track?.title ??
        album?.title ??
        playlist?.name ??
        artist?.name ??
        item.name ??
        'Unknown';
    final descriptor =
        track?.performer?.name ??
        (album != null
                ? (album.trackCount != null ? '${album.trackCount} tracks' : '')
                : '') +
            (playlist != null
                ? (playlist.trackCount != null
                      ? '${playlist.trackCount} tracks'
                      : '')
                : '');

    // Resolve thumbnail URL
    final urlResolver = ref.read(urlResolverProvider);
    final imageUrl = item.image?.small ?? item.image?.thumbnail;
    final resolvedImageUrl = imageUrl != null
        ? urlResolver.abs(imageUrl)
        : null;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: KalinkaColors.inputSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KalinkaColors.borderElevated, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: resolvedImageUrl != null
                          ? Image.network(
                              resolvedImageUrl,
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => ProceduralAlbumArt(
                                trackId: item.id,
                                size: 38,
                              ),
                            )
                          : ProceduralAlbumArt(trackId: item.id, size: 38),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: KalinkaTextStyles.trackRowTitle.copyWith(
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (descriptor.isNotEmpty)
                          Text(
                            descriptor,
                            style: KalinkaTextStyles.trackRowSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.07)),
            // Play next
            _MenuItem(
              icon: Icons.playlist_play,
              iconColor: KalinkaColors.accent,
              iconBackground: KalinkaColors.accent.withValues(alpha: 0.12),
              label: 'Play next',
              sublabel: 'inserts after current track',
              onTap: () async {
                Navigator.of(context).pop();
                final api = ref.read(kalinkaProxyProvider);
                await api.add([item.id]);
                onConfirm?.call();
              },
            ),
            // Append to queue
            _MenuItem(
              icon: Icons.playlist_add,
              iconColor: KalinkaColors.gold,
              iconBackground: KalinkaColors.gold.withValues(alpha: 0.10),
              label: 'Append to queue',
              sublabel: 'adds to end of queue',
              onTap: () async {
                Navigator.of(context).pop();
                final api = ref.read(kalinkaProxyProvider);
                await api.add([item.id]);
                onConfirm?.call();
              },
            ),
            // Add to playlist (only for single tracks)
            if (showAddToPlaylist)
              _MenuItem(
                icon: Icons.library_add,
                iconColor: KalinkaColors.textSecondary,
                iconBackground: KalinkaColors.pillSurface,
                label: 'Add to playlist\u2026',
                sublabel: 'save for later',
                onTap: () {
                  Navigator.of(context).pop();
                  // Placeholder for playlist add
                },
              ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: KalinkaTextStyles.trackRowTitle),
                  Text(sublabel, style: KalinkaTextStyles.aiTrackChipDuration),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
