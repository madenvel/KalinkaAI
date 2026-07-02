import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';

/// Minimal inline-markdown renderer.
///
/// Supports the markers the backend emits in status messages and field
/// descriptions:
///   * `**bold**`              → bold text
///   * `*italic*` / `_italic_` → italic text
///   * `` `code` ``            → monospace text, slightly tinted background
///   * `[label](url)`          → tappable link, opened externally
///
/// Newlines render as line breaks. Anything else is rendered literally.
/// Block-level constructs (lists, headings) are not supported — we don't
/// want to pull in a markdown package for a handful of inline markers.
class InlineMarkdown extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  const InlineMarkdown({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
  });

  @override
  State<InlineMarkdown> createState() => _InlineMarkdownState();
}

class _InlineMarkdownState extends State<InlineMarkdown> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  TapGestureRecognizer _linkRecognizer(String url) {
    final recognizer = TapGestureRecognizer()
      ..onTap = () {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      };
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();
    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;
    return Text.rich(
      TextSpan(children: _parse(widget.text, baseStyle)),
      style: baseStyle,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }

  static final _wordChar = RegExp(r'[A-Za-z0-9]');

  static bool _isSpace(String c) => c.trim().isEmpty;

  static bool _isWordChar(String c) => _wordChar.hasMatch(c);

  List<InlineSpan> _parse(String text, TextStyle baseStyle) {
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
      if (i + 1 < text.length && text[i] == '*' && text[i + 1] == '*') {
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

      // *italic* / _italic_. Guards keep stray markers literal: content
      // must not start/end with whitespace ("2 * 3 * 4"), and underscores
      // must sit on word boundaries (snake_case).
      if (text[i] == '*' || text[i] == '_') {
        final marker = text[i];
        final end = text.indexOf(marker, i + 1);
        if (end > i + 1 &&
            !_isSpace(text[i + 1]) &&
            !_isSpace(text[end - 1]) &&
            (marker == '*' ||
                ((i == 0 || !_isWordChar(text[i - 1])) &&
                    (end + 1 >= text.length || !_isWordChar(text[end + 1]))))) {
          flushBuffer();
          spans.add(
            TextSpan(
              text: text.substring(i + 1, end),
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          );
          i = end + 1;
          continue;
        }
      }

      // [label](url)
      if (text[i] == '[') {
        final mid = text.indexOf('](', i + 1);
        final end = mid == -1 ? -1 : text.indexOf(')', mid + 2);
        if (mid != -1 && end != -1) {
          flushBuffer();
          spans.add(
            TextSpan(
              text: text.substring(i + 1, mid),
              style: const TextStyle(
                color: KalinkaColors.accentTint,
                decoration: TextDecoration.underline,
                decorationColor: KalinkaColors.accentTint,
              ),
              recognizer: _linkRecognizer(text.substring(mid + 2, end)),
            ),
          );
          i = end + 1;
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
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
