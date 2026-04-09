import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalinka/widgets/gradient_progress_line.dart';

void main() {
  Widget buildLine(GradientProgressLineMode mode, {double progress = 0.5}) =>
      MaterialApp(
        home: Scaffold(
          body: GradientProgressLine(progress: progress, mode: mode),
        ),
      );

  testWidgets('normal mode renders CustomPaint directly without shimmer',
      (tester) async {
    await tester.pumpWidget(buildLine(GradientProgressLineMode.normal));
    await tester.pump();

    expect(find.byType(CustomPaint), findsOneWidget);
    expect(find.byType(AnimatedBuilder), findsNothing);
  });

  testWidgets('reconnecting mode wraps in AnimatedBuilder for shimmer',
      (tester) async {
    await tester.pumpWidget(buildLine(GradientProgressLineMode.reconnecting));
    await tester.pump();

    expect(find.byType(AnimatedBuilder), findsOneWidget);
    expect(find.byType(CustomPaint), findsOneWidget);
  });

  testWidgets('offline mode wraps in AnimatedBuilder for shimmer',
      (tester) async {
    await tester.pumpWidget(buildLine(GradientProgressLineMode.offline));
    await tester.pump();

    expect(find.byType(AnimatedBuilder), findsOneWidget);
    expect(find.byType(CustomPaint), findsOneWidget);
  });

  testWidgets('switching from reconnecting to normal removes AnimatedBuilder',
      (tester) async {
    await tester
        .pumpWidget(buildLine(GradientProgressLineMode.reconnecting));
    await tester.pump();
    expect(find.byType(AnimatedBuilder), findsOneWidget);

    await tester.pumpWidget(buildLine(GradientProgressLineMode.normal));
    await tester.pump();
    expect(find.byType(AnimatedBuilder), findsNothing);
  });

  testWidgets('switching from normal to offline adds AnimatedBuilder',
      (tester) async {
    await tester.pumpWidget(buildLine(GradientProgressLineMode.normal));
    await tester.pump();
    expect(find.byType(AnimatedBuilder), findsNothing);

    await tester.pumpWidget(buildLine(GradientProgressLineMode.offline));
    await tester.pump();
    expect(find.byType(AnimatedBuilder), findsOneWidget);
  });

  testWidgets('switching from offline to reconnecting keeps AnimatedBuilder',
      (tester) async {
    await tester.pumpWidget(buildLine(GradientProgressLineMode.offline));
    await tester.pump();
    expect(find.byType(AnimatedBuilder), findsOneWidget);

    await tester
        .pumpWidget(buildLine(GradientProgressLineMode.reconnecting));
    await tester.pump();
    expect(find.byType(AnimatedBuilder), findsOneWidget);
  });
}
