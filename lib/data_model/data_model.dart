enum PlayerStateType { stopped, playing, paused, buffering, error }

enum BrowseType { album, artist, playlist, catalog, track, unknown }

extension PlayerStateTypeExtension on PlayerStateType {
  String toValue() {
    switch (this) {
      case PlayerStateType.stopped:
        return 'STOPPED';
      case PlayerStateType.playing:
        return 'PLAYING';
      case PlayerStateType.paused:
        return 'PAUSED';
      case PlayerStateType.buffering:
        return 'BUFFERING';
      case PlayerStateType.error:
        return 'ERROR';
    }
  }

  static PlayerStateType fromValue(String value) {
    switch (value) {
      case 'STOPPED':
        return PlayerStateType.stopped;
      case 'PLAYING':
        return PlayerStateType.playing;
      case 'PAUSED':
        return PlayerStateType.paused;
      case 'BUFFERING':
        return PlayerStateType.buffering;
      case 'ERROR':
        return PlayerStateType.error;
      default:
        throw Exception('Invalid PlayerStateType value: $value');
    }
  }
}

class AudioInfo {
  int sampleRate;
  int bitsPerSample;
  int channels;
  int durationMs;

  AudioInfo({
    this.sampleRate = 0,
    this.bitsPerSample = 0,
    this.channels = 0,
    this.durationMs = 0,
  });

  factory AudioInfo.fromJson(Map<String, dynamic> json) => AudioInfo(
    sampleRate: json["sample_rate"],
    bitsPerSample: json["bits_per_sample"],
    channels: json["channels"],
    durationMs: json["duration_ms"],
  );

  Map<String, dynamic> toJson() => {
    "sample_rate": sampleRate,
    "bits_per_sample": bitsPerSample,
    "channels": channels,
    "duration_ms": durationMs,
  };
}

class PlaybackMode {
  final bool repeatAll;
  final bool repeatSingle;
  final bool shuffle;

  PlaybackMode({
    required this.repeatAll,
    required this.repeatSingle,
    required this.shuffle,
  });

  static final empty = PlaybackMode(
    repeatAll: false,
    repeatSingle: false,
    shuffle: false,
  );

  factory PlaybackMode.fromJson(Map<String, dynamic> json) => PlaybackMode(
    repeatAll: json["repeat_all"],
    repeatSingle: json["repeat_single"],
    shuffle: json["shuffle"],
  );

  Map<String, dynamic> toJson() => {
    "repeat_all": repeatAll,
    "repeat_single": repeatSingle,
    "shuffle": shuffle,
  };
}

class PlaybackState {
  PlayerStateType? state;
  Track? currentTrack;
  int? index;
  int? position;
  String? message;
  AudioInfo? audioInfo;
  String? mimeType;
  int timestampNs = 0;

  PlaybackState({
    this.state,
    this.currentTrack,
    this.index = 0,
    this.position = 0,
    this.message,
    this.audioInfo,
    this.mimeType,
    this.timestampNs = 0,
  });

  static final PlaybackState empty = PlaybackState();

  factory PlaybackState.fromJson(Map<String, dynamic> json) => PlaybackState(
    state: json.containsKey('state')
        ? PlayerStateTypeExtension.fromValue(json["state"])
        : null,
    currentTrack: json["current_track"] == null
        ? null
        : Track.fromJson(json["current_track"]),
    index: json["index"],
    position: json["position"],
    message: json["message"],
    audioInfo: json["audio_info"] == null
        ? null
        : AudioInfo.fromJson(json["audio_info"]),
    mimeType: json["mime_type"],
    timestampNs: json["timestamp_ns"] ?? 0,
  );

  Map<String, dynamic> toJson() => {
    "state": state?.toValue(),
    "current_track": currentTrack?.toJson(),
    "index": index,
    "position": position,
    "message": message,
    "audio_info": audioInfo?.toJson(),
    "mime_type": mimeType,
    "timestamp_ns": timestampNs,
  };

  PlaybackState copyWith(PlaybackState other) {
    return PlaybackState(
      state: other.state ?? state,
      currentTrack: other.currentTrack ?? currentTrack,
      index: other.index ?? index,
      position: other.position ?? position,
      message: other.message ?? message,
      audioInfo: other.audioInfo ?? audioInfo,
      mimeType: other.mimeType ?? mimeType,
      timestampNs: other.timestampNs != 0 ? other.timestampNs : timestampNs,
    );
  }

  PlaybackState copyWithFields({
    PlayerStateType? state,
    Track? currentTrack,
    int? index,
    int? position,
    String? message,
    AudioInfo? audioInfo,
    String? mimeType,
    int? timestampNs,
  }) {
    return PlaybackState(
      state: state ?? this.state,
      currentTrack: currentTrack ?? this.currentTrack,
      index: index ?? this.index,
      position: position ?? this.position,
      message: message ?? this.message,
      audioInfo: audioInfo ?? this.audioInfo,
      mimeType: mimeType ?? this.mimeType,
      timestampNs: timestampNs ?? this.timestampNs,
    );
  }
}

class DeviceVolume {
  final int currentVolume;
  final int maxVolume;
  final int volumeGain;
  final bool supported;

  DeviceVolume({
    required this.currentVolume,
    required this.maxVolume,
    required this.volumeGain,
    required this.supported,
  });

  factory DeviceVolume.fromJson(Map<String, dynamic> json) => DeviceVolume(
    currentVolume: json["current_volume"],
    maxVolume: json["max_volume"],
    volumeGain: json["volume_gain"],
    supported: json["supported"],
  );

  static final empty = DeviceVolume(
    currentVolume: 0,
    maxVolume: 0,
    volumeGain: 0,
    supported: false,
  );

  Map<String, dynamic> toJson() => {
    "volume": currentVolume,
    "max_volume": maxVolume,
    "volume_gain": volumeGain,
    "supported": supported,
  };

  DeviceVolume copyWith({
    int? currentVolume,
    int? maxVolume,
    int? volumeGain,
    bool? supported,
  }) {
    return DeviceVolume(
      currentVolume: currentVolume ?? this.currentVolume,
      maxVolume: maxVolume ?? this.maxVolume,
      volumeGain: volumeGain ?? this.volumeGain,
      supported: supported ?? this.supported,
    );
  }
}

class Track {
  String id;
  String title;
  int duration;
  Artist? performer;
  Album? album;
  String? playlistTrackId;

  Track({
    required this.id,
    required this.title,
    required this.duration,
    this.performer,
    this.album,
    this.playlistTrackId,
  });

  factory Track.fromJson(Map<String, dynamic> json) => Track(
    id: json["id"],
    title: json["title"],
    duration: json["duration"],
    performer: json["performer"] == null
        ? null
        : Artist.fromJson(json["performer"]),
    album: json["album"] == null ? null : Album.fromJson(json["album"]),
    playlistTrackId: json["playlist_track_id"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "title": title,
    "duration": duration,
    "performer": performer?.toJson(),
    "album": album?.toJson(),
    "playlist_track_id": playlistTrackId,
  };
}

class Album {
  final String id;
  final String title;
  final int? duration;
  final int? trackCount;
  final int? year;
  final AlbumImage? image;
  final Genre? genre;
  final Artist? artist;

  Album({
    required this.id,
    required this.title,
    this.duration,
    this.trackCount,
    this.year,
    this.image,
    this.genre,
    this.artist,
  });

  factory Album.fromJson(Map<String, dynamic> json) => Album(
    id: json["id"],
    title: json["title"],
    duration: json["duration"],
    trackCount: json["track_count"],
    year: json["year"],
    image: json["image"] == null ? null : AlbumImage.fromJson(json["image"]),
    genre: json["genre"] == null ? null : Genre.fromJson(json["genre"]),
    artist: json["artist"] == null ? null : Artist.fromJson(json["artist"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "title": title,
    "duration": duration,
    "track_count": trackCount,
    "year": year,
    "image": image?.toJson(),
    "genre": genre?.toJson(),
    "artist": artist?.toJson(),
  };
}

class AlbumImage {
  final String? small;
  final String? thumbnail;
  final String? large;

  AlbumImage({this.small, this.thumbnail, this.large});

  factory AlbumImage.fromJson(Map<String, dynamic> json) => AlbumImage(
    small: json["small"],
    thumbnail: json["thumbnail"],
    large: json["large"],
  );

  Map<String, dynamic> toJson() => {
    "small": small,
    "thumbnail": thumbnail,
    "large": large,
  };
}

class Artist {
  final String id;
  final String name;
  final AlbumImage? image;
  final int? albumCount;

  Artist({required this.id, required this.name, this.image, this.albumCount});

  factory Artist.fromJson(Map<String, dynamic> json) => Artist(
    id: json["id"],
    name: json["name"],
    image: json["image"] == null ? null : AlbumImage.fromJson(json["image"]),
    albumCount: json["album_count"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "image": image?.toJson(),
    "album_count": albumCount,
  };
}

class Owner {
  final String name;
  final String id;

  Owner({required this.name, required this.id});

  factory Owner.fromJson(Map<String, dynamic> json) =>
      Owner(name: json["name"], id: json["id"]);

  Map<String, dynamic> toJson() => {"name": name, "id": id};
}

class Playlist {
  final String id;
  final String name;
  final Owner? owner;
  final AlbumImage? image;
  final String? description;
  final int? trackCount;

  Playlist({
    required this.id,
    required this.name,
    this.owner,
    this.image,
    this.description,
    this.trackCount,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
    id: json["id"],
    name: json["name"],
    owner: json["owner"] == null ? null : Owner.fromJson(json["owner"]),
    image: json["image"] == null ? null : AlbumImage.fromJson(json["image"]),
    description: json["description"],
    trackCount: json["track_count"],
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "owner": owner?.toJson(),
    "image": image?.toJson(),
    "description": description,
    "track_count": trackCount,
  };
}

enum PreviewType { imageText, textOnly, carousel, tile, tileNumbered, none }

extension PreviewTypeExtension on PreviewType {
  String toValue() {
    switch (this) {
      case PreviewType.imageText:
        return 'image';
      case PreviewType.textOnly:
        return 'text';
      case PreviewType.carousel:
        return 'carousel';
      case PreviewType.tile:
        return 'tile';
      case PreviewType.tileNumbered:
        return 'tile_numbered';
      case PreviewType.none:
        return 'none';
    }
  }

  static PreviewType fromValue(String value) {
    switch (value) {
      case 'image':
        return PreviewType.imageText;
      case 'text':
        return PreviewType.textOnly;
      case 'carousel':
        return PreviewType.carousel;
      case 'tile':
        return PreviewType.tile;
      case 'tile_numbered':
        return PreviewType.tileNumbered;
      case 'none':
        return PreviewType.none;
      default:
        throw Exception('Invalid PreviewType value: $value');
    }
  }
}

enum CardSize { small, large }

extension CardSizeExtension on CardSize {
  String toValue() {
    switch (this) {
      case CardSize.small:
        return 'small';
      case CardSize.large:
        return 'large';
    }
  }

  static CardSize fromValue(String value) {
    switch (value) {
      case 'small':
        return CardSize.small;
      case 'large':
        return CardSize.large;
      default:
        throw Exception('Invalid CardSize value: $value');
    }
  }
}

enum PreviewContentType { catalog, album, artist, playlist, track, unknown }

extension PreviewContentTypeExtension on PreviewContentType {
  String toValue() {
    switch (this) {
      case PreviewContentType.catalog:
        return 'catalog';
      case PreviewContentType.album:
        return 'album';
      case PreviewContentType.artist:
        return 'artist';
      case PreviewContentType.playlist:
        return 'playlist';
      case PreviewContentType.track:
        return 'track';
      case PreviewContentType.unknown:
        return 'unknown';
    }
  }

  static PreviewContentType fromValue(String value) {
    switch (value) {
      case 'catalog':
        return PreviewContentType.catalog;
      case 'album':
        return PreviewContentType.album;
      case 'artist':
        return PreviewContentType.artist;
      case 'playlist':
        return PreviewContentType.playlist;
      case 'track':
        return PreviewContentType.track;
      default:
        throw Exception('Invalid PreviewContentType value: $value');
    }
  }

  static PreviewContentType fromBrowseType(BrowseType type) {
    switch (type) {
      case BrowseType.album:
        return PreviewContentType.album;
      case BrowseType.artist:
        return PreviewContentType.artist;
      case BrowseType.playlist:
        return PreviewContentType.playlist;
      case BrowseType.catalog:
        return PreviewContentType.catalog;
      case BrowseType.track:
        return PreviewContentType.track;
      default:
        return PreviewContentType.unknown;
    }
  }

  static PreviewContentType fromSearchType(SearchType type) {
    switch (type) {
      case SearchType.album:
        return PreviewContentType.album;
      case SearchType.artist:
        return PreviewContentType.artist;
      case SearchType.playlist:
        return PreviewContentType.playlist;
      case SearchType.track:
        return PreviewContentType.track;
      default:
        return PreviewContentType.unknown; // Default for invalid search type
    }
  }
}

class Preview {
  final int? itemsCount;
  final PreviewType type;
  final PreviewContentType? contentType;
  final int? rowsCount;
  final CardSize? cardSize;

  Preview({
    this.itemsCount,
    required this.type,
    this.contentType,
    this.rowsCount,
    this.cardSize,
  });

  factory Preview.fromJson(Map<String, dynamic> json) => Preview(
    itemsCount: json["items_count"],
    type: PreviewTypeExtension.fromValue(json["type"]),
    contentType: json["content_type"] == null
        ? null
        : PreviewContentTypeExtension.fromValue(json["content_type"]),
    rowsCount: json["rows_count"],
    cardSize: json["card_size"] == null
        ? null
        : CardSizeExtension.fromValue(json["card_size"]),
  );

  Map<String, dynamic> toJson() => {
    "items_count": itemsCount,
    "type": type.toValue(),
    "content_type": contentType?.toValue(),
    "rows_count": rowsCount,
    "card_size": cardSize?.toValue(),
  };

  Preview copyWith({
    int? itemsCount,
    PreviewType? type,
    PreviewContentType? contentType,
    int? rowsCount,
    CardSize? cardSize,
  }) {
    return Preview(
      itemsCount: itemsCount ?? this.itemsCount,
      type: type ?? this.type,
      contentType: contentType ?? this.contentType,
      rowsCount: rowsCount ?? this.rowsCount,
      cardSize: cardSize ?? this.cardSize,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Preview &&
        other.itemsCount == itemsCount &&
        other.type == type &&
        other.contentType == contentType &&
        other.rowsCount == rowsCount &&
        other.cardSize == cardSize;
  }

  @override
  int get hashCode =>
      Object.hash(itemsCount, type, contentType, rowsCount, cardSize);
}

class Catalog {
  final String id;
  final String title;
  final AlbumImage? image;
  final String? description;
  final bool canGenreFilter;
  final Preview? previewConfig;

  Catalog({
    required this.id,
    required this.title,
    required this.canGenreFilter,
    this.image,
    this.description,
    this.previewConfig,
  });

  static final empty = Catalog(
    id: '',
    title: '',
    canGenreFilter: false,
    image: null,
    description: null,
    previewConfig: null,
  );

  factory Catalog.fromJson(Map<String, dynamic> json) => Catalog(
    id: json["id"],
    title: json["title"],
    image: json["image"] == null ? null : AlbumImage.fromJson(json["image"]),
    description: json["description"],
    canGenreFilter: json["can_genre_filter"],
    previewConfig: json["preview_config"] == null
        ? null
        : Preview.fromJson(json["preview_config"]),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "title": title,
    "image": image?.toJson(),
    "description": description,
    "can_genre_filter": canGenreFilter,
    "preview_config": previewConfig?.toJson(),
  };

  Catalog copyWith({
    String? id,
    String? title,
    AlbumImage? image,
    String? description,
    bool? canGenreFilter,
    Preview? previewConfig,
  }) {
    return Catalog(
      id: id ?? this.id,
      title: title ?? this.title,
      image: image ?? this.image,
      description: description ?? this.description,
      canGenreFilter: canGenreFilter ?? this.canGenreFilter,
      previewConfig: previewConfig ?? this.previewConfig,
    );
  }
}

class BrowseItemsList {
  int offset;
  int limit;
  int total;
  List<BrowseItem> items;

  BrowseItemsList(this.offset, this.limit, this.total, this.items);

  factory BrowseItemsList.fromJson(Map<String, dynamic> json) =>
      BrowseItemsList(
        json["offset"],
        json["limit"],
        json["total"],
        List<BrowseItem>.from(json["items"].map((x) => BrowseItem.fromJson(x))),
      );

  factory BrowseItemsList.empty() => BrowseItemsList(0, 0, 0, []);
}

class TrackList {
  int offset;
  int limit;
  int total;
  List<Track> items;

  TrackList(this.offset, this.limit, this.total, this.items);

  factory TrackList.fromJson(Map<String, dynamic> json) => TrackList(
    json["offset"],
    json["limit"],
    json["total"],
    List<Track>.from(json["items"].map((x) => Track.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "offset": offset,
    "limit": limit,
    "total": total,
    "items": List<dynamic>.from(items.map((x) => x.toJson())),
  };
}

enum EntityType { catalog, album, artist, playlist, track, label, genre, user }

extension EntityTypeExtension on EntityType {
  String toValue() {
    switch (this) {
      case EntityType.catalog:
        return 'catalog';
      case EntityType.album:
        return 'album';
      case EntityType.artist:
        return 'artist';
      case EntityType.playlist:
        return 'playlist';
      case EntityType.track:
        return 'track';
      case EntityType.label:
        return 'label';
      case EntityType.genre:
        return 'genre';
      case EntityType.user:
        return 'user';
    }
  }

  static EntityType fromValue(String value) {
    switch (value) {
      case 'catalog':
        return EntityType.catalog;
      case 'album':
        return EntityType.album;
      case 'artist':
        return EntityType.artist;
      case 'playlist':
        return EntityType.playlist;
      case 'track':
        return EntityType.track;
      case 'label':
        return EntityType.label;
      case 'genre':
        return EntityType.genre;
      case 'user':
        return EntityType.user;
      default:
        throw Exception('Invalid EntityType value: $value');
    }
  }
}

class EntityId {
  final String id;
  final EntityType type;
  final String source;

  EntityId({required this.id, required this.type, required this.source});

  factory EntityId.fromString(String fullId) {
    final parts = fullId.split(':');
    if (parts.length != 4 || parts[0] != 'kalinka') {
      throw Exception('Invalid full_id format: $fullId');
    }
    return EntityId(
      id: parts[3],
      type: EntityTypeExtension.fromValue(parts[2]),
      source: parts[1],
    );
  }
}

class BrowseItem {
  final String id;
  final String? name;
  final String? subname;
  final bool canBrowse;
  final bool canAdd;
  final int timestamp;

  final Track? track;
  final Album? album;
  final Artist? artist;
  final Playlist? playlist;
  final Catalog? catalog;
  final List<BrowseItem>? sections;

  const BrowseItem({
    required this.id,
    this.name,
    this.subname,
    required this.canBrowse,
    required this.canAdd,
    this.timestamp = 0,
    this.track,
    this.album,
    this.artist,
    this.playlist,
    this.catalog,
    this.sections,
  });

  static final empty = BrowseItem(
    id: '',
    name: null,
    subname: null,
    canBrowse: false,
    canAdd: false,
    timestamp: 0,
    track: null,
    album: null,
    artist: null,
    playlist: null,
    catalog: null,
    sections: null,
  );

  BrowseItem copyWith({
    String? id,
    String? name,
    String? subname,
    bool? canBrowse,
    bool? canAdd,
    int? timestamp,
    Track? track,
    Album? album,
    Artist? artist,
    Playlist? playlist,
    Catalog? catalog,
    List<BrowseItem>? sections,
  }) {
    return BrowseItem(
      id: id ?? this.id,
      name: name ?? this.name,
      subname: subname ?? this.subname,
      canBrowse: canBrowse ?? this.canBrowse,
      canAdd: canAdd ?? this.canAdd,
      timestamp: timestamp ?? this.timestamp,
      track: track ?? this.track,
      album: album ?? this.album,
      artist: artist ?? this.artist,
      playlist: playlist ?? this.playlist,
      catalog: catalog ?? this.catalog,
      sections: sections ?? this.sections,
    );
  }

  AlbumImage? get image {
    if (album != null) {
      return album?.image;
    } else if (artist != null) {
      return artist?.image;
    } else if (playlist != null) {
      return playlist?.image;
    } else if (catalog != null) {
      return catalog?.image;
    } else if (track != null) {
      return track?.album?.image;
    }
    return null;
  }

  int? get duration {
    if (track != null) {
      return track?.duration;
    } else if (album != null) {
      return album?.duration;
    }
    return null;
  }

  int? get trackCount {
    if (album != null) {
      return album?.trackCount;
    } else if (playlist != null) {
      return playlist?.trackCount;
    }
    return null;
  }

  bool get canFavorite {
    return album != null || track != null || artist != null || playlist != null;
  }

  BrowseType get browseType {
    if (album != null) {
      return BrowseType.album;
    } else if (artist != null) {
      return BrowseType.artist;
    } else if (playlist != null) {
      return BrowseType.playlist;
    } else if (catalog != null) {
      return BrowseType.catalog;
    } else if (track != null) {
      return BrowseType.track;
    }
    return BrowseType.unknown;
  }

  String? get description {
    if (catalog != null) {
      return catalog?.description;
    } else if (playlist != null) {
      return playlist?.description;
    }

    return null;
  }

  factory BrowseItem.fromJson(Map<String, dynamic> json) => BrowseItem(
    id: json["id"],
    name: json["name"],
    subname: json["subname"],
    canBrowse: json["can_browse"],
    canAdd: json["can_add"],
    timestamp: json["timestamp"] ?? 0,
    track: json["track"] == null ? null : Track.fromJson(json["track"]),
    album: json["album"] == null ? null : Album.fromJson(json["album"]),
    artist: json["artist"] == null ? null : Artist.fromJson(json["artist"]),
    playlist: json["playlist"] == null
        ? null
        : Playlist.fromJson(json["playlist"]),
    catalog: json["catalog"] == null ? null : Catalog.fromJson(json["catalog"]),
    sections: json["sections"] == null
        ? null
        : List<BrowseItem>.from(
            json["sections"].map((x) => BrowseItem.fromJson(x)),
          ),
  );

  Map<String, dynamic> toJson() => {
    "id": id,
    "name": name,
    "subname": subname,
    "can_browse": canBrowse,
    "can_add": canAdd,
    "timestamp": timestamp,
    "track": track?.toJson(),
    "album": album?.toJson(),
    "artist": artist?.toJson(),
    "playlist": playlist?.toJson(),
    "catalog": catalog?.toJson(),
    "sections": sections == null
        ? null
        : List<dynamic>.from(sections!.map((x) => x.toJson())),
  };
}

enum SearchType { invalid, track, album, artist, playlist }

extension SearchTypeExtension on SearchType {
  String toStringValue() {
    switch (this) {
      case SearchType.track:
        return 'track';
      case SearchType.album:
        return 'album';
      case SearchType.artist:
        return 'artist';
      case SearchType.playlist:
        return 'playlist';
      default:
        throw Exception('Invalid SearchType');
    }
  }

  static SearchType fromStringValue(String value) {
    switch (value) {
      case 'track':
        return SearchType.track;
      case 'album':
        return SearchType.album;
      case 'artist':
        return SearchType.artist;
      case 'playlist':
        return SearchType.playlist;
      default:
        throw Exception('Invalid SearchType value: $value');
    }
  }

  static SearchType fromBrowseType(BrowseType value) {
    switch (value) {
      case BrowseType.track:
        return SearchType.track;
      case BrowseType.album:
        return SearchType.album;
      case BrowseType.artist:
        return SearchType.artist;
      case BrowseType.playlist:
        return SearchType.playlist;
      default:
        throw Exception('Invalid SearchType value: $value');
    }
  }
}

class Volume {
  final int maxVolume;
  int currentVolume;

  Volume({this.maxVolume = 0, this.currentVolume = 0});

  factory Volume.fromJson(Map<String, dynamic> json) => Volume(
    maxVolume: json["max_volume"],
    currentVolume: json["current_volume"],
  );

  Map<String, dynamic> toJson() => {
    "max_volume": maxVolume,
    "current_volume": currentVolume,
  };
}

class FavoriteIds {
  List<String> albums;
  List<String> tracks;
  List<String> artists;
  List<String> playlists;

  FavoriteIds({
    required this.albums,
    required this.tracks,
    required this.artists,
    required this.playlists,
  });

  factory FavoriteIds.fromJson(Map<String, dynamic> json) => FavoriteIds(
    albums: json["albums"] == null
        ? []
        : List<String>.from(json["albums"]!.map((x) => x)),
    tracks: json["tracks"] == null
        ? []
        : List<String>.from(json["tracks"]!.map((x) => x)),
    artists: json["artists"] == null
        ? []
        : List<String>.from(json["artists"]!.map((x) => x)),
    playlists: json["playlists"] == null
        ? []
        : List<String>.from(json["playlists"]!.map((x) => x)),
  );

  Map<String, dynamic> toJson() => {
    "albums": List<dynamic>.from(albums.map((x) => x)),
    "tracks": List<dynamic>.from(tracks.map((x) => x)),
    "artists": List<dynamic>.from(artists.map((x) => x)),
    "playlists": List<dynamic>.from(playlists.map((x) => x)),
  };
}

class GenreList {
  final int offset;
  final int limit;
  final int total;
  final List<Genre> items;

  GenreList({
    required this.offset,
    required this.limit,
    required this.total,
    required this.items,
  });

  factory GenreList.fromJson(Map<String, dynamic> json) => GenreList(
    offset: json["offset"],
    limit: json["limit"],
    total: json["total"],
    items: json["items"] == null
        ? []
        : List<Genre>.from(json["items"]!.map((x) => Genre.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "offset": offset,
    "limit": limit,
    "total": total,
    "items": List<dynamic>.from(items.map((x) => x.toJson())),
  };
}

class Genre {
  final String id;
  final String name;

  Genre({required this.id, required this.name});

  factory Genre.fromJson(Map<String, dynamic> json) =>
      Genre(id: json["id"], name: json["name"]);

  Map<String, dynamic> toJson() => {"id": id, "name": name};
}

class FavoriteAdded {
  final String id;

  FavoriteAdded({required this.id});

  factory FavoriteAdded.fromJson(Map<String, dynamic> json) =>
      FavoriteAdded(id: json["id"]);

  Map<String, dynamic> toJson() => {"id": id};
}

class FavoriteRemoved {
  final String id;

  FavoriteRemoved({required this.id});

  factory FavoriteRemoved.fromJson(Map<String, dynamic> json) =>
      FavoriteRemoved(id: json["id"]);

  Map<String, dynamic> toJson() => {"id": id};
}

class StatusMessage {
  final String? message;

  StatusMessage({this.message});

  factory StatusMessage.fromJson(Map<String, dynamic> json) =>
      StatusMessage(message: json["message"]);

  Map<String, dynamic> toJson() => {"message": message};
}

class SeekStatusMessage extends StatusMessage {
  final int? positionMs;

  SeekStatusMessage({this.positionMs, super.message});

  factory SeekStatusMessage.fromJson(Map<String, dynamic> json) =>
      SeekStatusMessage(
        positionMs: json["position_ms"],
        message: json["message"],
      );

  @override
  Map<String, dynamic> toJson() => {
    "position_ms": positionMs,
    "message": message,
  };
}

enum ModuleState { ready, disabled, error }

class ModuleStateExtension {
  static String toValue(ModuleState state) {
    switch (state) {
      case ModuleState.ready:
        return 'ready';
      case ModuleState.disabled:
        return 'disabled';
      case ModuleState.error:
        return 'error';
    }
  }

  static ModuleState fromValue(String value) {
    switch (value) {
      case 'ready':
        return ModuleState.ready;
      case 'disabled':
        return ModuleState.disabled;
      case 'error':
        return ModuleState.error;
      default:
        throw Exception('Invalid ModuleState value: $value');
    }
  }
}

class ModuleInfo {
  final String name;
  final String title;
  final bool enabled;
  final ModuleState state;

  ModuleInfo({
    required this.name,
    required this.title,
    required this.enabled,
    required this.state,
  });

  factory ModuleInfo.fromJson(Map<String, dynamic> json) => ModuleInfo(
    name: json["name"],
    title: json["title"],
    enabled: json["enabled"],
    state: ModuleStateExtension.fromValue(json["state"]),
  );

  Map<String, dynamic> toJson() => {
    "name": name,
    "title": title,
    "enabled": enabled,
    "state": ModuleStateExtension.toValue(state),
  };
}

class ModulesAndDevices {
  final List<ModuleInfo> inputModules;
  final List<ModuleInfo> devices;

  ModulesAndDevices({required this.inputModules, required this.devices});

  factory ModulesAndDevices.fromJson(Map<String, dynamic> json) =>
      ModulesAndDevices(
        inputModules: json["input_modules"] == null
            ? []
            : List<ModuleInfo>.from(
                json["input_modules"].map((x) => ModuleInfo.fromJson(x)),
              ),
        devices: json["devices"] == null
            ? []
            : List<ModuleInfo>.from(
                json["devices"].map((x) => ModuleInfo.fromJson(x)),
              ),
      );

  Map<String, dynamic> toJson() => {
    "input_modules": List<dynamic>.from(inputModules.map((x) => x.toJson())),
    "devices": List<dynamic>.from(devices.map((x) => x.toJson())),
  };

  ModulesAndDevices copyWith({
    List<ModuleInfo>? inputModules,
    List<ModuleInfo>? devices,
  }) {
    return ModulesAndDevices(
      inputModules: inputModules != null
          ? inputModules
                .map(
                  (m) => ModuleInfo(
                    name: m.name,
                    title: m.title,
                    enabled: m.enabled,
                    state: m.state,
                  ),
                )
                .toList()
          : this.inputModules
                .map(
                  (m) => ModuleInfo(
                    name: m.name,
                    title: m.title,
                    enabled: m.enabled,
                    state: m.state,
                  ),
                )
                .toList(),
      devices: devices != null
          ? devices
                .map(
                  (m) => ModuleInfo(
                    name: m.name,
                    title: m.title,
                    enabled: m.enabled,
                    state: m.state,
                  ),
                )
                .toList()
          : this.devices
                .map(
                  (m) => ModuleInfo(
                    name: m.name,
                    title: m.title,
                    enabled: m.enabled,
                    state: m.state,
                  ),
                )
                .toList(),
    );
  }
}

enum SearchMode { ai, local, remote, hybrid }

enum QueueAction { insertNext, append, replace }

sealed class SearchResultItem {
  const SearchResultItem();
}

class TrackResult extends SearchResultItem {
  final Track track;
  const TrackResult(this.track);
}

class AlbumResult extends SearchResultItem {
  final Album album;
  const AlbumResult(this.album);
}

class StageStatus {
  final int total;
  final int done;
  final int pending;
  final int inProgress;
  final int failed;
  final double coveragePct;

  const StageStatus({
    required this.total,
    required this.done,
    required this.pending,
    required this.inProgress,
    required this.failed,
    required this.coveragePct,
  });

  factory StageStatus.fromJson(Map<String, dynamic> json) => StageStatus(
        total: (json['total'] ?? 0) as int,
        done: (json['done'] ?? 0) as int,
        pending: (json['pending'] ?? 0) as int,
        inProgress: (json['in_progress'] ?? 0) as int,
        failed: (json['failed'] ?? 0) as int,
        coveragePct: ((json['coverage_pct'] ?? 0) as num).toDouble(),
      );
}

class IndexerStatus {
  final Map<String, Map<String, StageStatus>> modules;

  const IndexerStatus(this.modules);

  factory IndexerStatus.fromJson(Map<String, dynamic> json) => IndexerStatus({
        for (final m in json.entries)
          m.key: {
            for (final s in (m.value as Map).entries)
              s.key as String:
                  StageStatus.fromJson(Map<String, dynamic>.from(s.value as Map)),
          },
      });

  bool get isEmpty => modules.isEmpty;

  bool get isComplete {
    if (modules.isEmpty) return true;
    for (final stages in modules.values) {
      for (final s in stages.values) {
        if (s.pending > 0 || s.inProgress > 0) return false;
      }
    }
    return true;
  }

  double? get minCoveragePct {
    double? m;
    for (final stages in modules.values) {
      for (final s in stages.values) {
        if (m == null || s.coveragePct < m) m = s.coveragePct;
      }
    }
    return m;
  }

  /// Aggregate completion across every stage: sum(done) / sum(total).
  /// Unlike [minCoveragePct] this doesn't stick at 0% when a downstream
  /// stage hasn't started yet — it reflects overall pipeline progress.
  double? get overallCoveragePct {
    int done = 0;
    int total = 0;
    for (final stages in modules.values) {
      for (final s in stages.values) {
        done += s.done;
        total += s.total;
      }
    }
    if (total == 0) return null;
    return (done / total) * 100;
  }
}
