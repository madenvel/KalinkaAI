import 'dart:async' show Timer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_model/data_model.dart';
import 'kalinka_player_api_provider.dart';

/// How often the zero-state catalog cards re-fetch. They also refresh on app
/// start (first watch) and on reconnect (the section widget invalidates).
const _kRefreshInterval = Duration(hours: 12);

// Bound the per-source card row and the preview fetch so a module with a
// huge root catalog can't fan out into dozens of requests.
const _kMaxCardsPerSource = 8;
const _kPreviewFetchLimit = 8;

/// One planned advertisement card: a browsable category in a source's root
/// catalog. Carries everything needed to render the card shell and shimmer —
/// the preview strip content loads separately per card.
class CatalogCardPlan {
  final String id;
  final String title;
  final String? description;
  final String sourceName;
  final PreviewContentType? contentType;
  final PreviewType? previewType;

  const CatalogCardPlan({
    required this.id,
    required this.title,
    required this.sourceName,
    this.description,
    this.contentType,
    this.previewType,
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

/// How a card's preview strip is filled once its items are known.
enum CatalogCardFill {
  /// Three distinct cover images.
  arts,

  /// Item names over a seeded gradient — textual catalogs (sub-category
  /// indexes, TEXT_ONLY previews) that have no imagery by nature.
  textual,

  /// One abstract procedural rectangle — the category has fewer than three
  /// distinct covers (or none at all).
  procedural,
}

class CatalogCardPreview {
  final CatalogCardFill fill;

  /// Unresolved image paths (resolve against the server base URL at render
  /// time so a base change doesn't invalidate cached previews).
  final List<String> artPaths;
  final List<String> names;

  const CatalogCardPreview({
    required this.fill,
    this.artPaths = const [],
    this.names = const [],
  });

  static const procedural = CatalogCardPreview(
    fill: CatalogCardFill.procedural,
  );
}

/// Stage 1: the card plans, grouped by source. Root browse lists the input
/// sources; each source's root catalog lists its categories. Resolving this
/// tells the UI exactly how many cards each source gets, so the shimmer can
/// lay out the final grid before any preview data exists.
final catalogCardGroupsProvider = FutureProvider<List<CatalogCardGroup>>((
  ref,
) async {
  final timer = Timer(_kRefreshInterval, ref.invalidateSelf);
  ref.onDispose(timer.cancel);

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
          previewType: catalog.previewConfig?.type,
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
  return groups;
});

/// Stage 2: one category's preview strip, keyed by card id. Watches the
/// groups future, so the 12-hour refresh of the plans re-runs every preview
/// too; `when()` keeps showing the previous card during the refresh instead
/// of dropping back to shimmer.
final catalogCardPreviewProvider =
    FutureProvider.family<CatalogCardPreview, String>((ref, cardId) async {
      final groups = await ref.watch(catalogCardGroupsProvider.future);
      CatalogCardPlan? plan;
      for (final group in groups) {
        for (final card in group.cards) {
          if (card.id == cardId) plan = card;
        }
      }
      // Plan disappeared in a refresh — the card widget is about to go away.
      if (plan == null) return CatalogCardPreview.procedural;

      final api = ref.read(kalinkaProxyProvider);
      final list = await api.browse(cardId, limit: _kPreviewFetchLimit);

      final names = <String>[
        for (final item in list.items)
          if ((item.name ?? '').isNotEmpty) item.name!,
      ];

      // Distinct covers only: a single-album track list yields one path, not
      // three copies of it. Dedupe by path — local art URLs are keyed by
      // album, so same album ⇒ same path.
      final artPaths = <String>[];
      for (final item in list.items) {
        final image = item.image;
        final path = image?.thumbnail ?? image?.small ?? image?.large;
        if (path != null && path.isNotEmpty && !artPaths.contains(path)) {
          artPaths.add(path);
        }
      }

      final isTextual =
          plan.previewType == PreviewType.textOnly ||
          plan.contentType == PreviewContentType.catalog;
      if (isTextual && names.isNotEmpty) {
        return CatalogCardPreview(
          fill: CatalogCardFill.textual,
          names: names.take(3).toList(),
        );
      }
      if (artPaths.length >= 3) {
        return CatalogCardPreview(
          fill: CatalogCardFill.arts,
          artPaths: artPaths.take(3).toList(),
        );
      }
      return CatalogCardPreview.procedural;
    });
