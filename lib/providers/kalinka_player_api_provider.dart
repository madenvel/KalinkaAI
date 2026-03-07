import 'dart:async' show Timer;
import 'dart:convert' show jsonEncode;

import 'package:dio/dio.dart' show BaseOptions, Dio, Headers, Options, Response;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_settings_provider.dart'
    show connectionSettingsProvider;
import '../data_model/data_model.dart'
    show
        BrowseItem,
        BrowseItemsList,
        DeviceVolume,
        FavoriteIds,
        GenreList,
        ModulesAndDevices,
        Playlist,
        SearchType,
        SearchTypeExtension,
        SeekStatusMessage,
        StatusMessage,
        TrackList;

abstract class KalinkaPlayerProxy {
  Future<StatusMessage> play([int? index]);
  Future<StatusMessage> next();
  Future<StatusMessage> previous();
  Future<StatusMessage> add(List<String> items, {int? index});
  Future<StatusMessage> remove(int index);
  Future<StatusMessage> move(int fromIndex, int toIndex);
  Future<StatusMessage> pause({bool paused = true});
  Future<StatusMessage> stop();
  Future<TrackList> listTracks({int offset = 0, int limit = 100});
  Future<StatusMessage> setPlaybackMode({
    bool? repeatOne,
    bool? repeatAll,
    bool? shuffle,
  });
  Future<BrowseItemsList> search(
    SearchType queryType,
    String query, {
    int offset = 0,
    int limit = 30,
  });
  Future<BrowseItemsList> browse(
    String id, {
    int offset = 0,
    int limit = 10,
    List<String>? genreIds,
  });
  Future<BrowseItemsList> browseItem(
    BrowseItem item, {
    int offset = 0,
    int limit = 10,
    List<String>? genreIds,
  });
  Future<BrowseItem> getMetadata(String id);
  Future<BrowseItemsList> getFavorite(
    SearchType queryType, {
    int offset = 0,
    int limit = 10,
    String filter = '',
  });
  Future<StatusMessage> addFavorite(String id);
  Future<StatusMessage> removeFavorite(String id);
  Future<FavoriteIds> getFavoriteIds();
  Future<void> clear();
  Future<void> setVolume(int volume);
  Future<DeviceVolume> getVolume();
  Future<GenreList> getGenres(String? source);
  Future<SeekStatusMessage> seek(int positionMs);
  Future<Playlist> playlistCreate(String name, String? description);
  Future<void> playlistDelete(String playlistId);
  Future<Playlist> playlistAddTracks(String playlistId, List<String> trackIds);
  Future<BrowseItemsList> playlistUserList(int offset, int limit);
  Future<Map<String, dynamic>> getSettings();
  Future<ModulesAndDevices> listModules();
  Future<void> saveSettings(Map<String, dynamic> settings);
  Future<void> restartServer();
  void close();
}

class KalinkaPlayerProxyImpl implements KalinkaPlayerProxy {
  KalinkaPlayerProxyImpl({required this.client});
  final Dio client;

  @override
  Future<StatusMessage> play([int? index]) async {
    return client
        .put(
          '/queue/play',
          queryParameters: index != null ? {'index': index} : null,
        )
        .then((response) {
          return statusMessageFromResponse(response);
        });
  }

  @override
  Future<StatusMessage> next() async {
    return client.put('/queue/next').then((response) {
      return statusMessageFromResponse(response);
    });
  }

  @override
  Future<StatusMessage> previous() async {
    return client.put('/queue/prev').then((response) {
      return statusMessageFromResponse(response);
    });
  }

  @override
  Future<StatusMessage> add(List<String> items, {int? index}) async {
    return client
        .post(
          '/queue/add',
          queryParameters: index != null ? {'index': index} : null,
          data: items,
          options: Options(contentType: Headers.jsonContentType),
        )
        .then((response) {
          return statusMessageFromResponse(response);
        });
  }

  @override
  Future<StatusMessage> remove(int index) async {
    return client.post('/queue/remove', queryParameters: {'index': index}).then(
      (response) {
        return statusMessageFromResponse(response);
      },
    );
  }

  @override
  Future<StatusMessage> move(int fromIndex, int toIndex) async {
    return client
        .put(
          '/queue/move',
          queryParameters: {'from_index': fromIndex, 'to_index': toIndex},
        )
        .then((response) {
          return statusMessageFromResponse(response);
        });
  }

  @override
  Future<StatusMessage> pause({bool paused = true}) async {
    return client.put('/queue/pause', queryParameters: {'paused': paused}).then(
      (response) {
        return statusMessageFromResponse(response);
      },
    );
  }

  @override
  Future<StatusMessage> stop() async {
    return client.put('/queue/stop').then((response) {
      return statusMessageFromResponse(response);
    });
  }

  @override
  Future<TrackList> listTracks({int offset = 0, int limit = 100}) async {
    return client
        .get(
          '/queue/list',
          queryParameters: {
            'offset': offset.toString(),
            'limit': limit.toString(),
          },
        )
        .then((response) {
          if (response.statusCode != 200) {
            throw Exception('Failed to list tracks');
          }

          return TrackList.fromJson(response.data);
        });
  }

  @override
  Future<StatusMessage> setPlaybackMode({
    bool? repeatOne,
    bool? repeatAll,
    bool? shuffle,
  }) async {
    return client
        .put(
          '/queue/mode',
          queryParameters: {
            if (repeatOne != null) 'repeat_single': repeatOne,
            if (repeatAll != null) 'repeat_all': repeatAll,
            if (shuffle != null) 'shuffle': shuffle,
          },
        )
        .then((response) {
          return statusMessageFromResponse(response);
        });
  }

  @override
  Future<BrowseItemsList> search(
    SearchType queryType,
    String query, {
    int offset = 0,
    int limit = 30,
  }) async {
    final url = '/search/${queryType.toStringValue()}/$query';
    return client
        .get(
          url,
          queryParameters: {
            'offset': offset.toString(),
            'limit': limit.toString(),
          },
        )
        .then((response) {
          if (response.statusCode != 200) {
            throw Exception('Failed to search for $queryType $query');
          }

          return BrowseItemsList.fromJson(response.data);
        });
  }

  @override
  Future<BrowseItemsList> browse(
    String id, {
    int offset = 0,
    int limit = 10,
    List<String>? genreIds,
  }) async {
    final normalizedId = id.trim();
    final endpoint = (normalizedId.isEmpty || normalizedId == 'root')
        ? '/browse'
        : '/browse/$normalizedId';

    return client
        .get(
          endpoint,
          queryParameters: {
            'offset': offset.toString(),
            'limit': limit.toString(),
            ...genreIds != null ? {'genre_ids': genreIds} : {},
          },
        )
        .then((response) {
          if (response.statusCode != 200) {
            throw Exception('Failed to browse $id, url=${response.realUri}');
          }

          return BrowseItemsList.fromJson(response.data);
        });
  }

  @override
  Future<BrowseItemsList> browseItem(
    BrowseItem item, {
    int offset = 0,
    int limit = 10,
    List<String>? genreIds,
  }) {
    if (item.canBrowse) {
      return browse(item.id, offset: offset, limit: limit, genreIds: genreIds);
    }

    return Future.value(BrowseItemsList(0, 0, 0, []));
  }

  @override
  Future<BrowseItem> getMetadata(String id) async {
    return client.get('/get/$id').then((response) {
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to get metadata for $id, url=${response.realUri}',
        );
      }

      return BrowseItem.fromJson(response.data);
    });
  }

  @override
  Future<BrowseItemsList> getFavorite(
    SearchType queryType, {
    int offset = 0,
    int limit = 10,
    String filter = '',
  }) async {
    return client
        .get(
          '/favorite/list/${queryType.toStringValue()}',
          queryParameters: {
            'offset': offset.toString(),
            'limit': limit.toString(),
            'filter': filter,
          },
        )
        .then((response) {
          if (response.statusCode != 200) {
            throw Exception(
              'Failed to get favorite ${queryType.toStringValue()}, url=${response.realUri}',
            );
          }

          return BrowseItemsList.fromJson(response.data);
        });
  }

  @override
  Future<StatusMessage> addFavorite(String id) async {
    return client.put('/favorite/add/$id').then((response) {
      return statusMessageFromResponse(response);
    });
  }

  @override
  Future<StatusMessage> removeFavorite(String id) async {
    return client.delete('/favorite/remove/$id').then((response) {
      return statusMessageFromResponse(response);
    });
  }

  @override
  Future<FavoriteIds> getFavoriteIds() async {
    return client.get('/favorite/ids').then((response) {
      if (response.statusCode != 200) {
        throw Exception('Failed to get favorite ids, url=${response.realUri}');
      }

      return FavoriteIds.fromJson(response.data);
    });
  }

  @override
  Future<void> clear() async {
    return client.put('/queue/clear').then((response) {
      if (response.statusCode != 200) {
        throw Exception('Failed to clear queue, url=${response.realUri}');
      }
    });
  }

  @override
  Future<void> setVolume(int volume) async {
    return client
        .put(
          '/device/set_volume',
          queryParameters: {'volume': volume.toString()},
        )
        .then((response) {
          if (response.statusCode != 200) {
            throw Exception(
              'Failed to set volume to $volume, url=${response.realUri}',
            );
          }
        });
  }

  @override
  Future<DeviceVolume> getVolume() async {
    return client.get('/device/get_volume').then((response) {
      if (response.statusCode != 200) {
        throw Exception('Failed to get volume, url=${response.realUri}');
      }
      return DeviceVolume.fromJson(response.data);
    });
  }

  @override
  Future<GenreList> getGenres(String? source) async {
    return client
        .get(
          '/genre/list',
          queryParameters: source != null ? {'source': source} : null,
        )
        .then((response) {
          if (response.statusCode != 200) {
            throw Exception('Failed to get genres, url=${response.realUri}');
          }
          return GenreList.fromJson(response.data);
        });
  }

  @override
  Future<SeekStatusMessage> seek(int positionMs) async {
    return client
        .put(
          '/queue/current_track/seek',
          queryParameters: {'position_ms': positionMs.toString()},
        )
        .then((response) {
          if (response.statusCode != 200) {
            throw Exception('Request failed, url=${response.realUri}');
          }
          return SeekStatusMessage.fromJson(response.data);
        });
  }

  @override
  Future<Playlist> playlistCreate(String name, String? description) async {
    return client
        .post(
          '/playlist/create',
          queryParameters: {
            'name': name,
            if (description != null) 'description': description,
          },
        )
        .then((response) {
          if (response.statusCode != 200) {
            throw Exception(
              'Failed to create playlist, url=${response.realUri}',
            );
          }
          return Playlist.fromJson(response.data);
        });
  }

  @override
  Future<void> playlistDelete(String playlistId) async {
    return client
        .delete(
          '/playlist/delete',
          queryParameters: {'playlist_id': playlistId},
        )
        .then((response) {
          if (response.statusCode != 200) {
            throw Exception(
              'Failed to delete playlist, url=${response.realUri}, message=${response.statusMessage}',
            );
          }
        });
  }

  @override
  Future<Playlist> playlistAddTracks(
    String playlistId,
    List<String> trackIds,
  ) async {
    return client
        .post(
          '/playlist/add_tracks',
          queryParameters: {'playlist_id': playlistId},
          data: trackIds,
          options: Options(contentType: Headers.jsonContentType),
        )
        .then((response) {
          if (response.statusCode != 200) {
            throw Exception(
              'Failed to add tracks to playlist, url=${response.realUri}',
            );
          }
          return Playlist.fromJson(response.data);
        });
  }

  @override
  Future<BrowseItemsList> playlistUserList(int offset, int limit) async {
    return client
        .get(
          '/playlist/list',
          queryParameters: {'offset': offset, 'limit': limit},
        )
        .then((response) {
          if (response.statusCode != 200) {
            throw Exception(
              'Failed to list user playlists, url=${response.realUri}',
            );
          }
          return BrowseItemsList.fromJson(response.data);
        });
  }

  @override
  Future<Map<String, dynamic>> getSettings() async {
    return client.get('/server/config').then((response) {
      if (response.statusCode != 200) {
        throw Exception('Failed to get settings, url=${response.realUri}');
      }
      return response.data;
    });
  }

  @override
  Future<ModulesAndDevices> listModules() async {
    return client.get('/server/modules').then((response) {
      if (response.statusCode != 200) {
        throw Exception('Failed to list modules, url=${response.realUri}');
      }
      return ModulesAndDevices.fromJson(response.data);
    });
  }

  @override
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final String encodedSettings = jsonEncode(settings);
    final response = await client.put(
      '/server/config',
      options: Options(contentType: Headers.jsonContentType),
      data: encodedSettings,
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to save settings, status: ${response.statusCode}, body: ${response.data}',
      );
    }
  }

  @override
  Future<void> restartServer() async {
    return client.put('/server/restart').then((response) {
      if (response.statusCode != 200) {
        throw Exception('Failed to restart server, url=${response.realUri}');
      }
    });
  }

  StatusMessage statusMessageFromResponse(Response response) {
    if (response.statusCode != 200) {
      var url = response.realUri.toString();
      throw Exception('Request $url failed, url=$url');
    }
    return StatusMessage.fromJson(response.data);
  }

  @override
  Future<void> close() async {
    return client.close();
  }
}

final httpClientProvider = Provider<Dio>((ref) {
  final settings = ref.watch(connectionSettingsProvider);
  final baseUrl = settings.isSet
      ? settings.baseUrl.toString()
      : 'http://127.0.0.1:0';
  final dio = Dio(BaseOptions(baseUrl: baseUrl));
  return dio;
});

// The proxy instance itself (constructed once, disposed automatically)
final kalinkaProxyProvider = Provider<KalinkaPlayerProxy>((ref) {
  final httpClient = ref.watch(httpClientProvider);
  final proxy = KalinkaPlayerProxyImpl(client: httpClient);

  ref.onDispose(() async {
    await proxy.close();
  });

  // Keep alive if you navigate across screens frequently
  final link = ref.keepAlive();

  // Optional: release after some idle time
  Timer(const Duration(minutes: 10), link.close);

  return proxy;
});
