import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalinka/widgets/kalinka_button.dart';

void main() {
  testWidgets('full-width button truncates a long label without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: KalinkaButton(
                label: 'Connect to Some Very Long Kalinka Server Name',
                fullWidth: true,
              ),
            ),
          ),
        ),
      ),
    );

    // Without the Flexible wrap the Row overflows and throws in debug.
    expect(tester.takeException(), isNull);
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.maxLines, 1);
  });

  testWidgets('intrinsic button lays out inside an unbounded Row', (
    tester,
  ) async {
    // Outer Rows give non-flex children infinite width — the label must
    // not be Flexible there or the inner Row asserts.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(children: [KalinkaButton(label: 'Try again')]),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Try again'), findsOneWidget);
  });
}
