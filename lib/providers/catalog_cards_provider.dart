import 'dart:async' show Timer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_model/data_model.dart';
import 'kalinka_player_api_provider.dart';

/// How often the zero-state catalog cards re-fetch. They also refresh on app
/// start (first watch) and on reconnect (the section widget invalidates).
const _kRefreshInterval = Duration(hours: 12);

/// The card backgrounds are rendered server-side and generated lazily, so the
/// first browse after a cold cache returns cards with no art yet. Re-fetch a
/// few times at this cadence to pick the images up, then fall back to the slow
/// refresh. Bounded so a card the server can't illustrate doesn't poll forever.
const _kArtPollInterval = Duration(seconds: 4);
const _kMaxArtPolls = 8;

// Bound the number of cards per source so a huge root catalog can't fan out.
const _kMaxCardsPerSource = 8;

// Poll bookkeeping (module-level: the provider is a singleton). `_pollDriven`
// distinguishes a self-scheduled art poll from a fresh/external invalidation
// (app start, reconnect, 12-hour refresh), so the attempt counter resets when
// it should.
int _artPolls = 0;
bool _pollDriven = false;

/// One advertisement card: a browsable category in a source's root catalog.
/// Carries the card shell content plus the unresolved path of its server-
/// rendered background ([artPath], null until the backend has generated it).
class CatalogCardPlan {
  final String id;
  final String title;
  final String? description;
  final String sourceName;
  final PreviewContentType? contentType;

  /// Unresolved background image path (resolve against the server base URL at
  /// render time so a base change doesn't invalidate it). Null when the server
  /// hasn't produced the art yet — the card shows a black backdrop until then.
  final String? artPath;

  const CatalogCardPlan({
    required this.id,
    required this.title,
    required this.sourceName,
    this.description,
    this.contentType,
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

/// The card plans, grouped by source. Root browse lists the input sources;
/// each source's root catalog lists its categories, each already carrying the
/// URL of its backend-rendered background (or nothing, until generated). This
/// is the whole payload the cards need — there is no second per-card fetch.
final catalogCardGroupsProvider = FutureProvider<List<CatalogCardGroup>>((
  ref,
) async {
  // A fresh start / reconnect / slow refresh resets the art-poll budget; only
  // our own poll timer carries it forward.
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
