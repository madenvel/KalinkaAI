import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'browse_detail_provider.dart';
import 'source_modules_provider.dart';

/// Which rows are unrolled, by entity id: a container (album, playlist,
/// catalog) showing its items, an artist showing its albums, and the "show
/// more" folds inside them. Held apart from any one screen's state so a row
/// reads the same wherever it is drawn.
class RowExpansion {
  final Set<String> unrolled;
  final Set<String> artists;
  final Set<String> artistMoreAlbums;
  final Set<String> albumMoreTracks;

  const RowExpansion({
    this.unrolled = const {},
    this.artists = const {},
    this.artistMoreAlbums = const {},
    this.albumMoreTracks = const {},
  });

  RowExpansion copyWith({
    Set<String>? unrolled,
    Set<String>? artists,
    Set<String>? artistMoreAlbums,
    Set<String>? albumMoreTracks,
  }) => RowExpansion(
    unrolled: unrolled ?? this.unrolled,
    artists: artists ?? this.artists,
    artistMoreAlbums: artistMoreAlbums ?? this.artistMoreAlbums,
    albumMoreTracks: albumMoreTracks ?? this.albumMoreTracks,
  );
}

class RowExpansionNotifier extends Notifier<RowExpansion> {
  @override
  RowExpansion build() => const RowExpansion();

  void toggleUnrolled(String id) {
    if (!state.unrolled.contains(id)) _reread(id);
    state = state.copyWith(unrolled: _toggled(state.unrolled, id));
  }

  /// Unrolls [id] whatever it was: opening a screen on one row must land it
  /// open, not flip whatever the last visit left behind. Arriving on it is
  /// opening it, so it is reread even if it was already unrolled.
  void unroll(String id) {
    _reread(id);
    state = state.copyWith(unrolled: {...state.unrolled, id});
  }

  /// Opening a collection rereads it: it may have changed since (another
  /// device, the queue). A source's album keeps its first answer.
  void _reread(String id) {
    if (ownedByServer(ref.read(builtinSourcesProvider), id)) {
      ref.invalidate(browseDetailProvider(id));
    }
  }

  void toggleArtist(String id) =>
      state = state.copyWith(artists: _toggled(state.artists, id));

  void revealArtistMoreAlbums(String artistId) => state = state.copyWith(
    artistMoreAlbums: {...state.artistMoreAlbums, artistId},
  );

  void revealAlbumMoreTracks(String albumId) => state = state.copyWith(
    albumMoreTracks: {...state.albumMoreTracks, albumId},
  );

  static Set<String> _toggled(Set<String> ids, String id) =>
      ids.contains(id) ? ({...ids}..remove(id)) : {...ids, id};
}

final rowExpansionProvider =
    NotifierProvider<RowExpansionNotifier, RowExpansion>(
      RowExpansionNotifier.new,
    );
