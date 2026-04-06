import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_model/data_model.dart';
import '../../providers/browse_detail_provider.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/toast_provider.dart';
import '../../providers/url_resolver.dart';
import '../../theme/app_theme.dart';
import '../source_badge.dart';
import 'artist_section.dart';
import 'search_album_row.dart';

/// Expanded artist card shown when an artist tile is tapped in the strip.
/// Displays a header card (avatar + name + album count) and a list of albums
/// using [SearchAlbumRow].
class ExpandedArtistCard extends ConsumerStatefulWidget {
  final BrowseItem artist;
  final VoidCallback onClose;

  const ExpandedArtistCard({
    super.key,
    required this.artist,
    required this.onClose,
  });

  @override
  ConsumerState<ExpandedArtistCard> createState() => _ExpandedArtistCardState();
}

class _ExpandedArtistCardState extends ConsumerState<ExpandedArtistCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confirmCtrl;
  late final Animation<double> _confirmScale;
  late final Animation<Color?> _confirmColor;
  bool _confirmed = false;
  Timer? _resetTimer;

  @override
  void initState() {
    super.initState();
    _confirmCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _confirmScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.85), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.15), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _confirmCtrl, curve: Curves.easeInOut));
    _confirmColor = ColorTween(
      begin: KalinkaColors.accent,
      end: KalinkaColors.actionConfirm,
    ).animate(_confirmCtrl);
  }

  @override
  void dispose() {
    _confirmCtrl.dispose();
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleTopTracks() async {
    final api = ref.read(kalinkaProxyProvider);
    final name =
        widget.artist.artist?.name ?? widget.artist.name ?? 'Artist';
    try {
      await api.add([widget.artist.id]);
      if (!mounted) return;
      setState(() => _confirmed = true);
      _confirmCtrl.forward(from: 0);
      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) {
          setState(() => _confirmed = false);
          _confirmCtrl.reset();
        }
      });
      showSafeToast('Top 5 by $name appended');
    } catch (e) {
      showSafeToast('Failed to queue: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final artist = widget.artist;
    final name = artist.artist?.name ?? artist.name ?? 'Unknown';
    final albumCount = artist.artist?.albumCount;
    final imageUrl = artist.image?.small;
    final resolvedImageUrl =
        imageUrl == null ? null : ref.read(urlResolverProvider).abs(imageUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderCard(name, albumCount, resolvedImageUrl),
        const SizedBox(height: 12),
        _buildAlbumPicksLabel(),
        const SizedBox(height: 8),
        _buildAlbumsList(),
      ],
    );
  }

  Widget _buildHeaderCard(
    String name,
    int? albumCount,
    String? resolvedImageUrl,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: KalinkaColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: KalinkaColors.borderDefault),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ArtistAvatarWidget(
            artistId: widget.artist.id,
            resolvedImageUrl: resolvedImageUrl,
            size: 72,
            isActive: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: KalinkaTextStyles.trackRowTitle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    SourceBadge(
                      entityId: widget.artist.id,
                      size: SourceBadgeSize.small,
                    ),
                    if (albumCount != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '$albumCount albums',
                        style: KalinkaTextStyles.trackRowSubtitle.copyWith(
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                _buildActionRow(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    return Row(
      children: [
        AnimatedBuilder(
          animation: _confirmCtrl,
          builder: (context, child) {
            final color = _confirmed
                ? _confirmColor.value ?? KalinkaColors.accent
                : KalinkaColors.accent;
            return Transform.scale(
              scale: _confirmCtrl.isAnimating ? _confirmScale.value : 1.0,
              child: GestureDetector(
                onTap: _handleTopTracks,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.28)),
                  ),
                  child: Text(
                    _confirmed ? '\u2713 QUEUED' : '\u25B6 TOP',
                    style: KalinkaTextStyles.browseButtonLabel.copyWith(
                      color: color,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: widget.onClose,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: KalinkaColors.surfaceElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: KalinkaColors.borderDefault),
            ),
            child: Text(
              'CLOSE \u2227',
              style: KalinkaTextStyles.browseButtonLabel.copyWith(
                color: KalinkaColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumPicksLabel() {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text('ALBUM PICKS', style: KalinkaTextStyles.sectionLabel),
    );
  }

  Widget _buildAlbumsList() {
    final browseAsync = ref.watch(browseDetailProvider(widget.artist.id));

    return browseAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: KalinkaColors.accent,
            ),
          ),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Failed to load albums',
          style: KalinkaTextStyles.trackRowSubtitle,
        ),
      ),
      data: (browseList) {
        final albums =
            browseList.items.where((item) => item.canBrowse).toList();
        if (albums.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No albums found',
              style: KalinkaTextStyles.trackRowSubtitle,
            ),
          );
        }
        return Column(
          children: [
            for (int i = 0; i < albums.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: KalinkaColors.surfaceBase,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: KalinkaColors.borderSubtle),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: SearchAlbumRow(item: albums[i]),
                ),
              ),
          ],
        );
      },
    );
  }
}
