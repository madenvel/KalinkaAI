import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kalinka/data_model/data_model.dart';
import 'package:kalinka/providers/source_modules_provider.dart';
import 'package:kalinka/widgets/source_badge.dart';

ModuleInfo _module(String name, String title, {bool builtin = false}) =>
    ModuleInfo(
      name: name,
      title: title,
      enabled: true,
      state: ModuleState.ready,
      builtin: builtin,
    );

final _twoSources = [
  _module('localfiles', 'Local Library'),
  _module('jamendo', 'Jamendo'),
];

Future<void> _pump(
  WidgetTester tester,
  List<ModuleInfo> modules,
  String entityId,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sourceModulesProvider.overrideWith((ref) => modules)],
      child: MaterialApp(
        home: Scaffold(body: SourceBadge(entityId: entityId)),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  /// The listener's own library used to be the unmarked default: no badge,
  /// on the theory that music without a badge was obviously theirs. It reads
  /// as a missing badge instead, so it is attributed like anywhere else.
  testWidgets('the local library is attributed like any other source', (
    tester,
  ) async {
    await _pump(tester, _twoSources, 'kalinka:localfiles:track:1');

    expect(find.text('L'), findsOneWidget);
  });

  testWidgets('a streaming source is attributed the same way', (tester) async {
    await _pump(tester, _twoSources, 'kalinka:jamendo:track:1');

    expect(find.text('J'), findsOneWidget);
  });

  testWidgets('with one source there is nothing to tell apart', (tester) async {
    await _pump(tester, [_twoSources.first], 'kalinka:localfiles:track:1');

    expect(find.byType(Text), findsNothing);
  });

  /// A collection is the app's own list, not a place the music came from.
  testWidgets('the server\'s own source stays unbadged', (tester) async {
    await _pump(tester, [
      ..._twoSources,
      _module('collections', 'Collections', builtin: true),
    ], 'kalinka:collections:playlist:1');

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('an id with no source in it badges nothing', (tester) async {
    await _pump(tester, _twoSources, 'not-an-entity-id');

    expect(find.byType(Text), findsNothing);
  });

  /// A choice in the source row and the badge on a row are the same mark at
  /// two sizes. Measured from both rather than asserted against a number, so
  /// a change to either shape fails here instead of drifting apart.
  testWidgets('a source choice is the badge shape, not a circle', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sourceModulesProvider.overrideWith((ref) => _twoSources)],
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const SourceLetter(source: 'jamendo'),
                SourceChoice(
                  label: 'J',
                  tint: const Color(0xFF5B8DEF),
                  selected: false,
                  onTap: () {},
                  semanticsLabel: 'Jamendo',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final badge = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(SourceLetter),
            matching: find.byType(Container),
          )
          .first,
    );
    final choice = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(SourceChoice),
        matching: find.byType(AnimatedContainer),
      ),
    );

    double roundness(Decoration d, double side) {
      final radius = ((d as BoxDecoration).borderRadius as BorderRadius);
      return radius.topLeft.x / side;
    }

    final badgeSide = tester.getSize(find.byType(SourceLetter)).height;
    expect(
      roundness(choice.decoration!, SourceChoice.side),
      closeTo(roundness(badge.decoration as Decoration, badgeSide), 0.005),
    );
    // A circle would round at half its side; this is a square with corners.
    expect(roundness(choice.decoration!, SourceChoice.side), lessThan(0.3));
  });

  /// The palette gives a screen at rest one crimson fill at most, and this
  /// row is chrome that stays up for the session. ALL is on by default, so a
  /// filled ALL would spend that budget on "nothing has been chosen".
  testWidgets('the choice that is on is outlined, never filled crimson', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sourceModulesProvider.overrideWith((ref) => _twoSources)],
        child: MaterialApp(
          home: Scaffold(
            body: SourceChoice(
              label: 'ALL',
              tint: null,
              selected: true,
              onTap: () {},
              semanticsLabel: 'All sources',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final decoration =
        tester
                .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                .decoration
            as BoxDecoration;

    expect(decoration.color!.a, lessThan(0.2), reason: 'a wash, not a fill');
    expect(decoration.border!.top.color.a, greaterThan(0.2));
  });

  /// [SourceLetter] is reached directly now that no source is exempt, so it
  /// answers for every one of them.
  testWidgets('the letter tile names the local library too', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sourceModulesProvider.overrideWith((ref) => _twoSources)],
        child: const MaterialApp(
          home: Scaffold(body: SourceLetter(source: 'localfiles')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('L'), findsOneWidget);
  });
}
