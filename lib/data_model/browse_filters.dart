import 'data_model.dart' show SearchType;

/// How far one filter facet is supported by the data source behind a surface.
enum FacetSupport {
  /// Not applicable — the control is not rendered at all.
  hidden,

  /// Rendered, but inert and muted: nothing behind this surface can honour it
  /// yet (or the answer is fixed). A placeholder never reaches
  /// [BrowseFilterQuery.serverKey], so it can never trigger a refetch that
  /// would quietly come back unfiltered.
  unsupported,

  /// Live — the selection is part of the request.
  supported,
}

/// What a browsable surface can be filtered by. Facets the backend can honour
/// are [FacetSupport.supported]; the rest render as placeholders or not at all.
///
/// Derived per surface from the shape of the endpoint behind it. Keeping it a
/// descriptor rather than a pile of booleans on each screen is what lets one
/// form serve catalog pages, favourites, and whatever comes next.
class BrowseFilterCapabilities {
  /// Free-text filtering over the collection.
  final FacetSupport text;

  /// Filtering by entity kind. [unsupported] still renders [types] — a
  /// single-type collection reports what it holds rather than filtering it.
  final FacetSupport type;

  /// Entity kinds to render, in display order. Empty hides the row.
  final List<SearchType> types;

  /// The subset of [types] this collection actually contains. Others render
  /// dimmed; when [type] is [FacetSupport.unsupported] these read as selected.
  final Set<SearchType> presentTypes;

  final FacetSupport genre;

  /// Input-module name whose taxonomy fills the genre facet (`/genre/list`).
  /// Null asks for every enabled source's genres.
  final String? genreSource;

  const BrowseFilterCapabilities({
    this.text = FacetSupport.hidden,
    this.type = FacetSupport.hidden,
    this.types = const [],
    this.presentTypes = const {},
    this.genre = FacetSupport.hidden,
    this.genreSource,
  });

  /// True when nothing at all would render — callers skip the bar entirely.
  bool get isEmpty =>
      text == FacetSupport.hidden &&
      genre == FacetSupport.hidden &&
      (type == FacetSupport.hidden || types.isEmpty);

  /// The canonical entity-kind row. Order is the one the mockups use.
  static const allTypes = <SearchType>[
    SearchType.artist,
    SearchType.album,
    SearchType.track,
    SearchType.playlist,
  ];
}

/// The active filter selection — one request object rather than a widening
/// list of arguments, so the surfaces above it never learn how it travels.
/// Today each facet becomes a query parameter; a richer query language later
/// changes only the callers that build the request.
class BrowseFilterQuery {
  final String text;

  /// Null means "all kinds".
  final SearchType? type;

  final List<String> genreIds;

  const BrowseFilterQuery({
    this.text = '',
    this.type,
    this.genreIds = const [],
  });

  bool get isEmpty => text.isEmpty && type == null && genreIds.isEmpty;

  /// How many separate answers this query carries — the number on the filter
  /// button's badge, and the number of chips shown above the rows. Each genre
  /// counts on its own, because each is separately removable.
  int get activeCount =>
      (text.isEmpty ? 0 : 1) + (type == null ? 0 : 1) + genreIds.length;

  BrowseFilterQuery copyWith({
    String? text,
    SearchType? type,
    bool clearType = false,
    List<String>? genreIds,
  }) {
    return BrowseFilterQuery(
      text: text ?? this.text,
      type: clearType ? null : (type ?? this.type),
      genreIds: genreIds ?? this.genreIds,
    );
  }

  /// Identity of the part of this query the backend will actually see, under
  /// [capabilities]. Lists reload on this string alone — so touching an inert
  /// facet costs nothing, and a facet that starts being honoured begins
  /// triggering refetches the moment its capability flips.
  String serverKey(BrowseFilterCapabilities capabilities) {
    final parts = <String>[
      if (capabilities.text == FacetSupport.supported) 'q=$text',
      if (capabilities.type == FacetSupport.supported) 'k=${type?.name ?? ''}',
      if (capabilities.genre == FacetSupport.supported)
        'g=${genreIds.join(",")}',
    ];
    return parts.join('&');
  }
}
