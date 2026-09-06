import 'dart:convert';

import 'data_model.dart'
    show FilterKind, FilterSpec, SearchType, SearchTypeExtension;

/// The field id every source uses for the entity kind — the one values
/// field a consumer may recognise by name rather than by vocabulary.
const kTypeFieldId = 'type';

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

  /// The catalog whose vocabulary fills the genre facet, and the field id it
  /// is filled from. Null where there is no genre facet to fill.
  final ({String catalogId, String field})? genreVocabulary;

  /// The genre field as its source declared it — the id the request addresses
  /// it by, and the combination the source honours.
  final FilterSpec? genreField;

  /// The free-text field as its source declared it; its label says what that
  /// source matches, which differs between sources.
  final FilterSpec? textField;

  /// The entity-kind field as its source declared it. Only a listing that
  /// mixes kinds has one.
  final FilterSpec? typeField;

  const BrowseFilterCapabilities({
    this.text = FacetSupport.hidden,
    this.type = FacetSupport.hidden,
    this.types = const [],
    this.presentTypes = const {},
    this.genre = FacetSupport.hidden,
    this.genreVocabulary,
    this.genreField,
    this.textField,
    this.typeField,
  });

  /// What a surface offers, from what its source declared for it. A facet the
  /// source did not declare is hidden: the app never decides for itself what a
  /// source can honour, so a control is shown only where it will be.
  factory BrowseFilterCapabilities.fromSpecs(
    List<FilterSpec> specs, {
    required String catalogId,
    List<SearchType> types = const [],
  }) {
    FilterSpec? find(bool Function(FilterSpec) test) {
      for (final spec in specs) {
        if (test(spec)) return spec;
      }
      return null;
    }

    final textField = find((s) => s.kind == FilterKind.text);
    // `type` is the one values field every source spells the same way, so it
    // is matched by id; any other is the vocabulary the genre facet fills from.
    final typeField = find(
      (s) => s.kind == FilterKind.choice && s.id == kTypeFieldId,
    );
    final genreField = find(
      (s) => s.kind == FilterKind.choice && s.id != kTypeFieldId,
    );
    return BrowseFilterCapabilities(
      text: textField == null ? FacetSupport.hidden : FacetSupport.supported,
      type: typeField == null || types.isEmpty
          ? FacetSupport.hidden
          : FacetSupport.supported,
      types: typeField == null ? const [] : types,
      presentTypes: typeField == null ? const {} : types.toSet(),
      genre: genreField == null ? FacetSupport.hidden : FacetSupport.supported,
      genreVocabulary: genreField == null
          ? null
          : (catalogId: catalogId, field: genreField.id),
      genreField: genreField,
      textField: textField,
      typeField: typeField,
    );
  }

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
  ///
  /// It is [encoded] itself rather than a parallel encoding of the same
  /// facets, so the key and the request can never disagree about what travels.
  String serverKey(BrowseFilterCapabilities capabilities) =>
      encoded(capabilities) ?? '';

  /// The filter as the server's document — field id to selector — or null when
  /// nothing this surface declared is constrained.
  ///
  /// Only facets the surface declared travel, and a values field carries the
  /// operation its source said it honours, so chips never imply a union a
  /// source will not perform.
  String? encoded(BrowseFilterCapabilities capabilities) {
    final fields = <String, dynamic>{};

    final textField = capabilities.textField;
    if (textField != null &&
        capabilities.text == FacetSupport.supported &&
        text.isNotEmpty) {
      fields[textField.id] = {'contains': text};
    }

    final typeField = capabilities.typeField;
    final type = this.type;
    if (typeField != null &&
        capabilities.type == FacetSupport.supported &&
        type != null) {
      fields[typeField.id] = {
        typeField.defaultOp.name: [type.toStringValue()],
      };
    }

    final genreField = capabilities.genreField;
    if (genreField != null &&
        capabilities.genre == FacetSupport.supported &&
        genreIds.isNotEmpty) {
      fields[genreField.id] = {genreField.defaultOp.name: genreIds};
    }

    return fields.isEmpty ? null : jsonEncode(fields);
  }
}
