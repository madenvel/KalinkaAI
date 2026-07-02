import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalinka/theme/app_theme.dart';
import 'package:kalinka/widgets/settings_controls/inline_markdown.dart';

void main() {
  Future<List<InlineSpan>> pumpAndParse(
    WidgetTester tester,
    String text,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: InlineMarkdown(text: text)),
      ),
    );
    final rich = tester.widget<Text>(
      find
          .descendant(
            of: find.byType(InlineMarkdown),
            matching: find.byType(Text),
          )
          .first,
    );
    final spans = <InlineSpan>[];
    rich.textSpan!.visitChildren((s) {
      spans.add(s);
      return true;
    });
    return spans;
  }

  TextSpan textSpanAt(List<InlineSpan> spans, int i) => spans[i] as TextSpan;

  testWidgets('plain text renders as a single literal span', (tester) async {
    final spans = await pumpAndParse(tester, 'plain text\nwith a newline');
    expect(spans, hasLength(1));
    expect(textSpanAt(spans, 0).text, 'plain text\nwith a newline');
  });

  testWidgets('bold and italic markers produce styled spans', (tester) async {
    final spans = await pumpAndParse(
      tester,
      'a **bold** and *italic* and _under_',
    );
    final bold = spans.whereType<TextSpan>().firstWhere(
      (s) => s.text == 'bold',
    );
    expect(bold.style?.fontWeight, FontWeight.w600);
    for (final text in ['italic', 'under']) {
      final span = spans.whereType<TextSpan>().firstWhere(
        (s) => s.text == text,
      );
      expect(span.style?.fontStyle, FontStyle.italic);
    }
  });

  testWidgets('stray markers stay literal', (tester) async {
    for (final input in ['2 * 3 * 4', 'snake_case and other_names', 'a ** b']) {
      final spans = await pumpAndParse(tester, input);
      expect(spans, hasLength(1), reason: input);
      expect(textSpanAt(spans, 0).text, input);
    }
  });

  testWidgets('link renders tinted, underlined, and tappable', (tester) async {
    final spans = await pumpAndParse(
      tester,
      'see [the docs](https://example.com) here',
    );
    final link = spans.whereType<TextSpan>().firstWhere(
      (s) => s.text == 'the docs',
    );
    expect(link.style?.color, KalinkaColors.accentTint);
    expect(link.style?.decoration, TextDecoration.underline);
    expect(link.recognizer, isA<TapGestureRecognizer>());
    expect((link.recognizer as TapGestureRecognizer).onTap, isNotNull);
  });

  testWidgets('unterminated link stays literal', (tester) async {
    final spans = await pumpAndParse(tester, 'array[0] and (parens)');
    expect(spans, hasLength(1));
    expect(textSpanAt(spans, 0).text, 'array[0] and (parens)');
  });
}
