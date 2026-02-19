import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data_model/data_model.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../theme/app_theme.dart';

/// Context menu for the + button (Mode A).
/// Shows Play Next, Append to Queue, Add to Playlist options.
class AddContextMenu extends ConsumerWidget {
  final BrowseItem item;
  final Offset anchorPosition;
  final VoidCallback? onConfirm;

  const AddContextMenu({
    super.key,
    required this.item,
    required this.anchorPosition,
    this.onConfirm,
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
    );
  }

  Widget _buildMenu(BuildContext context, WidgetRef ref) {
    final track = item.track;
    final title = track?.title ?? item.name ?? 'Unknown';
    final artist = track?.performer?.name ?? '';

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
            // Mini preview header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: KalinkaColors.miniPlayerSurface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: KalinkaTextStyles.trackRowTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (artist.isNotEmpty)
                          Text(
                            artist,
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
            const Divider(color: KalinkaColors.borderDefault, height: 1),
            // Play next
            _MenuItem(
              icon: Icons.playlist_play,
              iconColor: KalinkaColors.accent,
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
              label: 'Append to queue',
              sublabel: 'adds to end of queue',
              onTap: () async {
                Navigator.of(context).pop();
                final api = ref.read(kalinkaProxyProvider);
                await api.add([item.id]);
                onConfirm?.call();
              },
            ),
            // Add to playlist
            _MenuItem(
              icon: Icons.library_add,
              iconColor: KalinkaColors.textSecondary,
              label: 'Add to playlist…',
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
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
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
            Icon(icon, size: 18, color: iconColor),
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
