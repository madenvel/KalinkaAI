import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/toast_provider.dart';
import '../../theme/app_theme.dart';
import '../procedural_album_art.dart';

/// AI Suggestion Card — shape-breaking, always first in results.
/// Full-width, gradient border, grain texture, horizontal track chip strip.
class AiSuggestionCard extends ConsumerStatefulWidget {
  const AiSuggestionCard({super.key});

  @override
  ConsumerState<AiSuggestionCard> createState() => _AiSuggestionCardState();
}

class _AiSuggestionCardState extends ConsumerState<AiSuggestionCard> {
  bool _isLoading = false;
  bool _isConfirmed = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleAddAll() async {
    if (_isLoading || _isConfirmed) return;

    setState(() => _isLoading = true);

    try {
      final api = ref.read(kalinkaProxyProvider);
      // Placeholder track IDs — will be populated by AI search results
      final trackIds = List.generate(5, (i) => 'ai_track_$i');
      await api.add(trackIds);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isConfirmed = true;
      });

      _resetTimer?.cancel();
      _resetTimer = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) {
          setState(() => _isConfirmed = false);
        }
      });

      showSafeToast('${trackIds.length} AI tracks appended');
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      showSafeToast('Failed to add: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Placeholder data — will be populated by AI search results
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            KalinkaColors.accent.withValues(alpha: 0.32),
            KalinkaColors.gold.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: KalinkaColors.surfaceRaised,
          borderRadius: BorderRadius.circular(16.5),
        ),
        child: Stack(
          children: [
            // Grain texture overlay
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.5),
                child: CustomPaint(painter: _GrainPainter(seed: 42)),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: icon + label
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: KalinkaColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: KalinkaColors.accent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI \u00B7 GENERATED FOR THIS QUERY',
                              style: KalinkaTextStyles.aiCardLabel,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Viburnum Evening Session',
                              style: KalinkaTextStyles.aiPlaylistName,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Horizontal track chip strip (placeholder)
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 5,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        return _TrackChip(index: index);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Footer: metadata + Add all button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '5 tracks \u00B7 18 min',
                        style: KalinkaTextStyles.aiTrackChipDuration,
                      ),
                      GestureDetector(
                        onTap: _handleAddAll,
                        child: Opacity(
                          opacity: _isLoading ? 0.6 : 1.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: _isConfirmed
                                    ? KalinkaColors.actionConfirm
                                    : KalinkaColors.gold,
                                width: 1,
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: KalinkaColors.gold,
                                    ),
                                  )
                                : Text(
                                    _isConfirmed ? 'ADD ALL \u2713' : 'ADD ALL',
                                    style: KalinkaFonts.sans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.0,
                                      color: _isConfirmed
                                          ? KalinkaColors.actionConfirm
                                          : KalinkaColors.gold,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackChip extends StatelessWidget {
  final int index;

  const _TrackChip({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: KalinkaColors.surfaceInput,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KalinkaColors.borderSubtle, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: ProceduralAlbumArt(trackId: 'ai_track_$index', size: 24),
          ),
          const SizedBox(width: 6),
          Text('Track ${index + 1}', style: KalinkaTextStyles.aiTrackChip),
          const SizedBox(width: 4),
          Text('3:42', style: KalinkaTextStyles.aiTrackChipDuration),
        ],
      ),
    );
  }
}

/// Paints a subtle grain/noise texture overlay.
class _GrainPainter extends CustomPainter {
  final int seed;

  _GrainPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final paint = Paint();
    final dotCount = (size.width * size.height * 0.003).toInt();

    for (int i = 0; i < dotCount; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      paint.color = Colors.white.withValues(alpha: rng.nextDouble() * 0.04);
      canvas.drawCircle(Offset(x, y), 0.5 + rng.nextDouble() * 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter oldDelegate) => oldDelegate.seed != seed;
}
