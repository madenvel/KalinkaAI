import 'dart:async' show Timer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_model/data_model.dart';
import 'kalinka_player_api_provider.dart';

const _kRefreshInterval = Duration(hours: 12);

// Server art is generated lazily, so the first browse after a cold cache has no
// art yet. Re-fetch a bounded number of times to pick it up, then fall back to
// the slow refresh.
const _kArtPollInterval = Duration(seconds: 4);
const _kMaxArtPolls = 8;

const _kMaxCardsPerSource = 8;

// `_pollDriven` tells a self-scheduled poll apart from a fresh invalidation
// (start/reconnect/refresh) so the attempt counter resets on the latter.
int _artPolls = 0;
bool _pollDriven = false;

/// One advertisement card: a browsable category in a source's root catalog.
class CatalogCardPlan {
  final String id;
  final String title;
  final String? description;
  final String sourceName;
  final PreviewContentType? contentType;

  /// Semantic icon id from the catalog's preview_config (e.g. "popular",
  /// "new_releases"); the card maps it to a glyph, falling back to contentType.
  final String? icon;

  /// Unresolved background path (resolved against the base URL at render time).
  /// Null until the server has generated the art; the card is black until then.
  final String? artPath;

  const CatalogCardPlan({
    required this.id,
    required this.title,
    required this.sourceName,
    this.description,
    this.contentType,
    this.icon,
    this.artPath,
  });
}

/// All planned cards for one input source, in backend order.
class CatalogCardGroup {
  final String sourceName;
  final String sourceTitle;
  final List<CatalogCardPlan> cards;

  const CatalogCardGroup({
    required this.sourceName,
    required this.sourceTitle,
    required this.cards,
  });
}

String? _artPathOf(BrowseItem item) {
  final image = item.catalog?.image;
  if (image == null) return null;
  final path = image.large ?? image.small ?? image.thumbnail;
  return (path != null && path.isNotEmpty) ? path : null;
}

/// The card plans, grouped by source, each carrying its background URL from the
/// browse response — the whole payload the cards need, no second per-card fetch.
final catalogCardGroupsProvider = FutureProvider<List<CatalogCardGroup>>((
  ref,
) async {
  if (!_pollDriven) _artPolls = 0;
  _pollDriven = false;

  final api = ref.read(kalinkaProxyProvider);
  final root = await api.browse('', limit: 20);

  final groups = <CatalogCardGroup>[];
  for (final module in root.items) {
    if (!module.canBrowse) continue;

    String sourceName;
    try {
      sourceName = EntityId.fromString(module.id).source;
    } catch (_) {
      sourceName = module.name?.toLowerCase() ?? '';
    }
    if (sourceName.isEmpty) continue;

    final children = await api.browse(module.id, limit: 20);
    final cards = <CatalogCardPlan>[];
    for (final item in children.items) {
      final catalog = item.catalog;
      if (catalog == null || !item.canBrowse) continue;
      if (catalog.role == CatalogRole.hideOnHome) continue;

      cards.add(
        CatalogCardPlan(
          id: item.id,
          title: item.name ?? catalog.title,
          description: catalog.description ?? item.subname,
          sourceName: sourceName,
          contentType: catalog.previewConfig?.contentType,
          icon: catalog.previewConfig?.icon,
          artPath: _artPathOf(item),
        ),
      );
      if (cards.length >= _kMaxCardsPerSource) break;
    }

    if (cards.isNotEmpty) {
      groups.add(
        CatalogCardGroup(
          sourceName: sourceName,
          sourceTitle: module.name ?? sourceName,
          cards: cards,
        ),
      );
    }
  }

  final missingArt = groups.any(
    (group) => group.cards.any((card) => card.artPath == null),
  );
  final Duration delay;
  if (missingArt && _artPolls < _kMaxArtPolls) {
    _artPolls++;
    _pollDriven = true;
    delay = _kArtPollInterval;
  } else {
    delay = _kRefreshInterval;
  }
  final timer = Timer(delay, ref.invalidateSelf);
  ref.onDispose(timer.cancel);

  return groups;
});
