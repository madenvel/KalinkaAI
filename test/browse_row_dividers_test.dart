import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kalinka/data_model/data_model.dart';
import 'package:kalinka/providers/connection_settings_provider.dart';
import 'package:kalinka/widgets/search_cards/browse_item_rows.dart';

const _title = 'Title Here';

BrowseItem _track() => BrowseItem(
  id: 'kalinka:x:track:t',
  name: _title,
  canBrowse: false,
  canAdd: true,
  track: Track(id: 't', title: _title, duration: 100),
);

BrowseItem _album() => BrowseItem(
  id: 'kalinka:x:album:a',
  name: _title,
  canBrowse: true,
  canAdd: true,
  album: Album(id: 'a', title: _title),
);

BrowseItem _artist() => BrowseItem(
  id: 'kalinka:x:artist:r',
  name: _title,
  canBrowse: true,
  canAdd: false,
  artist: Artist(id: 'r', name: _title),
);

BrowseItem _playlist({bool canEdit = false}) => BrowseItem(
  id: 'kalinka:x:playlist:p',
  name: _title,
  canBrowse: true,
  canAdd: true,
  canEdit: canEdit,
  playlist: Playlist(id: 'p', name: _title, trackCount: 3),
);

BrowseItem _catalog() => BrowseItem(
  id: 'kalinka:x:catalog:c',
  name: _title,
  canBrowse: true,
  canAdd: false,
  catalog: Catalog(id: 'c', title: _title),
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpRows(WidgetTester tester, List<BrowseItem> items) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(width: 400, child: BrowseItemRows(items: items)),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The table in [BrowseItemRows.textInsetOf] is a list of measurements, and
  /// measurements go stale. Every row type is pumped and measured here, so a
  /// row that changes its artwork or its padding fails this rather than
  /// quietly drawing its hairline through its own thumbnail.
  group('the text inset a divider takes', () {
    final rows = {
      'a track': _track(),
      'an album': _album(),
      'an artist': _artist(),
      'a playlist': _playlist(),
      'a collection': _playlist(canEdit: true),
      'a catalog': _catalog(),
    };

    for (final entry in rows.entries) {
      testWidgets('${entry.key} is where its words start', (tester) async {
        await pumpRows(tester, [entry.value]);

        final rowLeft = tester.getTopLeft(find.byType(BrowseItemRows)).dx;
        final textLeft = tester.getTopLeft(find.text(_title).first).dx;

        expect(textLeft - rowLeft, BrowseItemRows.textInsetOf(entry.value));
      });
    }
  });

  testWidgets('a hairline starts where the row above it starts', (
    tester,
  ) async {
    await pumpRows(tester, [_album(), _track()]);

    final divider = find.byType(Divider);
    expect(divider, findsOneWidget);
    final rowLeft = tester.getTopLeft(find.byType(BrowseItemRows)).dx;
    // The album above it, not the track below — the hairline is the bottom
    // edge of the row it follows.
    expect(
      tester.getTopLeft(divider).dx - rowLeft,
      BrowseItemRows.textInsetOf(_album()),
    );
  });

  testWidgets('every list of rows is divided, with no way to opt out', (
    tester,
  ) async {
    await pumpRows(tester, [_track(), _track(), _track()]);

    expect(find.byType(Divider), findsNWidgets(2));
  });
}
