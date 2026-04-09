import 'package:flutter/material.dart';

/// Horizontal breadcrumb navigation bar for browse drill-down.
class PathBar extends StatelessWidget {
  final List<String> segments;
  final ValueChanged<int> onNavigate;

  const PathBar({super.key, required this.segments, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 36,
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              theme.colorScheme.surface,
              Colors.transparent,
              Colors.transparent,
              theme.colorScheme.surface,
            ],
            stops: const [0.0, 0.05, 0.95, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstOut,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: segments.length + 1,
          separatorBuilder: (context, index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              Icons.chevron_right,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          itemBuilder: (context, index) {
            final isLast = index == segments.length;
            if (index == 0) {
              return TextButton(
                onPressed: isLast ? null : () => onNavigate(-1),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: isLast
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
                child: const Text('Home'),
              );
            }
            final segment = segments[index - 1];
            return TextButton(
              onPressed: isLast ? null : () => onNavigate(index - 1),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: isLast
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
              child: Text(
                segment,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          },
        ),
      ),
    );
  }
}
