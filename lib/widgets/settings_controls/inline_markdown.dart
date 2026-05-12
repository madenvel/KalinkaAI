import 'package:flutter/material.dart';

/// Minimal inline-markdown renderer.
///
/// Supports the two markers the backend currently emits in status messages:
///   * `**bold**`   → bold text
///   * `` `code` `` → monospace text, slightly tinted background
///
/// Anything else is rendered literally. Block-level constructs (lists,
/// headings, links) are not supported — they're not used in module
/// status messages, and we don't want to pull in flutter_markdown for
/// what amounts to two emphasis markers.
class InlineMarkdown extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const InlineMarkdown({super.key, required this.text, this.style});

  @override
  Widget build(BuildContext context) {
    final baseStyle =
        style ?? DefaultTextStyle.of(context).style;
    return Text.rich(
      TextSpan(children: _parse(text, baseStyle)),
      style: baseStyle,
    );
  }

  static List<InlineSpan> _parse(String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    int i = 0;
    final buffer = StringBuffer();

    void flushBuffer() {
      if (buffer.isEmpty) return;
      spans.add(TextSpan(text: buffer.toString()));
      buffer.clear();
    }

    while (i < text.length) {
      // **bold**
      if (i + 1 < text.length &&
          text[i] == '*' &&
          text[i + 1] == '*') {
        final end = text.indexOf('**', i + 2);
        if (end != -1) {
          flushBuffer();
          spans.add(
            TextSpan(
              text: text.substring(i + 2, end),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          );
          i = end + 2;
          continue;
        }
      }

      // `code`
      if (text[i] == '`') {
        final end = text.indexOf('`', i + 1);
        if (end != -1) {
          flushBuffer();
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: baseStyle.color?.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  text.substring(i + 1, end),
                  style: baseStyle.copyWith(
                    fontFamily: 'monospace',
                    fontFamilyFallback: const ['Menlo', 'Courier New'],
                    fontSize: (baseStyle.fontSize ?? 14) - 0.5,
                  ),
                ),
              ),
            ),
          );
          i = end + 1;
          continue;
        }
      }

      buffer.write(text[i]);
      i++;
    }

    flushBuffer();
    return spans;
  }
}
