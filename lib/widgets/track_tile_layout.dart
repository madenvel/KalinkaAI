import 'package:flutter/material.dart';

const double kTrackTileArtworkSize = 44;
const double kTrackTileVerticalPadding = 8;
const EdgeInsets kTrackTilePadding = EdgeInsets.symmetric(
  horizontal: 12,
  vertical: kTrackTileVerticalPadding,
);

/// Shared row scaffold for track-like tiles used across search and queue.
class TrackTileLayout extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget leading;
  final Widget content;
  final Widget? trailing;
  final double leadingStartSpacing;
  final double leadingContentSpacing;
  final double contentTrailingSpacing;
  final double trailingEndSpacing;

  const TrackTileLayout({
    super.key,
    required this.leading,
    required this.content,
    this.trailing,
    this.padding = kTrackTilePadding,
    this.leadingStartSpacing = 10,
    this.leadingContentSpacing = 10,
    this.contentTrailingSpacing = 8,
    this.trailingEndSpacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (leadingStartSpacing > 0) SizedBox(width: leadingStartSpacing),
          SizedBox(
            width: kTrackTileArtworkSize,
            height: kTrackTileArtworkSize,
            child: leading,
          ),
          SizedBox(width: leadingContentSpacing),
          Expanded(child: content),
          if (trailing != null) ...[
            SizedBox(width: contentTrailingSpacing),
            trailing!,
            if (trailingEndSpacing > 0) SizedBox(width: trailingEndSpacing),
          ],
        ],
      ),
    );
  }
}
