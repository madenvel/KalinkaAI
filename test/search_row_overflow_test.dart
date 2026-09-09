import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kalinka/data_model/data_model.dart';
import 'package:kalinka/providers/connection_settings_provider.dart';
import 'package:kalinka/providers/source_modules_provider.dart';
import 'package:kalinka/widgets/search_cards/search_album_row.dart';
import 'package:kalinka/widgets/search_cards/search_artist_row.dart';

/// A row's second line carries a badge and a subtitle side by side. Neither
/// `maxLines` nor `ellipsis` constrains a `Text` inside a `Row` — only a flex
/// parent does — so a subtitle without one lays out at its full width and
/// runs off the end of the row instead of trailing off.
///
/// Narrow, because the failure is a width one: a phone in a large text scale,
/// or a split view.
const _narrow = 260.0;

final _twoSources = [
  ModuleInfo(
    name: 'localfiles',
    title: 'Local Library',
    enabled: true,
    state: ModuleState.ready,
  ),
  ModuleInfo(
    name: 'jamendo',
    title: 'Jamendo',
    enabled: true,
    state: ModuleState.ready,
  ),
];

BrowseItem _artist() => BrowseItem(
  id: 'kalinka:jamendo:artist:1',
  name: 'A Band With Quite A Long Name Indeed',
  canBrowse: true,
  canAdd: false,
  artist: Artist(
    id: 'kalinka:jamendo:artist:1',
    name: 'A Band With Quite A Long Name Indeed',
    albumCount: 128,
  ),
);

BrowseItem _album() => BrowseItem(
  id: 'kalinka:jamendo:album:1',
  name: 'An Album With Quite A Long Name Indeed',
  canBrowse: true,
  canAdd: true,
  album: Album(
    id: 'kalinka:jamendo:album:1',
    title: 'An Album With Quite A Long Name Indeed',
    artist: Artist(
      id: 'kalinka:jamendo:artist:1',
      name: 'A Band With Quite A Long Name Indeed',
    ),
  ),
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpNarrow(WidgetTester tester, Widget row) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          sourceModulesProvider.overrideWith((ref) => _twoSources),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(width: _narrow, child: row),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('an artist subtitle trails off rather than running over', (
    tester,
  ) async {
    await pumpNarrow(tester, SearchArtistRow(item: _artist()));

    expect(tester.takeException(), isNull);
  });

  testWidgets('an album subtitle does the same', (tester) async {
    await pumpNarrow(tester, SearchAlbumRow(item: _album()));

    expect(tester.takeException(), isNull);
  });
}
