import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data_model/data_model.dart';
import 'collections_provider.dart';
import 'kalinka_player_api_provider.dart';

/// Every entry of a collection, in the order the server holds them. An edit
/// addresses the whole list — the server checks the two lists it is sent
/// against everything the collection holds — so a page of it could never be
/// committed.
final collectionEntriesProvider =
    FutureProvider.family<BrowseItemsList, String>((ref, id) async {
      ref.watch(collectionsRevisionProvider);
      final api = ref.read(kalinkaProxyProvider);
      return api.browse(id, limit: collectionEditLimit);
    });

/// How long a collection may be and still be edited here. Beyond it the list
/// is shown but not staged: an edit that named only the part it had loaded
/// would be refused by the server, and rightly.
const int collectionEditLimit = 1000;

/// A collection as the list that raised the gesture has it: what an edit is
/// seeded from the first time one is staged.
typedef HeldCollection = ({String name, List<String> entryIds});

/// One collection's staged edit, by entry id. Nothing is staged until the
/// user touches the collection, so a session that changed nothing carries
/// nothing to commit.
class CollectionEdit {
  /// The collection's name when the edit began, for what the session says
  /// about it later.
  final String name;

  /// The entries as they were read, in the order the server had them. Both
  /// what the staged lists are counted against and what the server matches
  /// its own list against when the edit lands.
  final List<String> original;

  /// The order the user has put them in — a removed entry keeps its place
  /// until Done, so putting it back puts it back where it was.
  final List<String> order;

  final Set<String> removing;

  /// The entries the user has dragged. Kept rather than derived: moving one
  /// row shifts every row after it, and only the one that was picked up is a
  /// change the user made.
  final Set<String> dragged;

  const CollectionEdit({
    required this.name,
    required this.original,
    required this.order,
    this.removing = const {},
    this.dragged = const {},
  });

  CollectionEdit copyWith({
    List<String>? order,
    Set<String>? removing,
    Set<String>? dragged,
  }) {
    return CollectionEdit(
      name: name,
      original: original,
      order: order ?? this.order,
      removing: removing ?? this.removing,
      dragged: dragged ?? this.dragged,
    );
  }

  /// What the collection would read as once the edit lands.
  List<String> get surviving => [
    for (final id in order)
      if (!removing.contains(id)) id,
  ];

  /// What it would read as if the removals were all that happened — the
  /// order a move is judged against.
  List<String> get _kept => [
    for (final id in original)
      if (!removing.contains(id)) id,
  ];

  /// The dragged entries that did not end up back where they started.
  Set<String> get moved {
    final was = _kept;
    final now = surviving;
    return {
      for (final id in dragged)
        if (was.indexOf(id) != now.indexOf(id)) id,
    };
  }

  /// Whether this entry is one of them.
  bool hasMoved(String entryId) => moved.contains(entryId);

  int get changes => removing.length + moved.length;
}

/// The screen-wide editing session: one mode covering every collection on the
/// listing, holding what each has staged until Done commits or Cancel drops
/// the lot.
class CollectionEditSession {
  final bool active;
  final Map<String, CollectionEdit> staged;

  const CollectionEditSession({this.active = false, this.staged = const {}});

  CollectionEdit? of(String collectionId) => staged[collectionId];

  int get changes =>
      staged.values.fold(0, (total, edit) => total + edit.changes);

  /// The collections with something to commit, in no particular order.
  Iterable<MapEntry<String, CollectionEdit>> get changed =>
      staged.entries.where((entry) => entry.value.changes > 0);
}

class CollectionEditNotifier extends Notifier<CollectionEditSession> {
  @override
  CollectionEditSession build() => const CollectionEditSession();

  void begin() => state = const CollectionEditSession(active: true);

  /// Ends the session, staged or not. Cancelling asks first; committing has
  /// already written.
  void end() => state = const CollectionEditSession();

  /// Drops one collection's staging, leaving the session running.
  void reset(String collectionId) {
    if (!state.staged.containsKey(collectionId)) return;
    state = CollectionEditSession(
      active: state.active,
      staged: {...state.staged}..remove(collectionId),
    );
  }

  /// Forgets what was committed while leaving anything that was not, so a
  /// refused edit stays on screen to be dealt with.
  void keepOnly(Set<String> collectionIds) {
    state = CollectionEditSession(
      active: state.active,
      staged: {
        for (final entry in state.staged.entries)
          if (collectionIds.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  void toggleRemoval(String collectionId, HeldCollection held, String entryId) {
    final edit = _staged(collectionId, held);
    final removing = {...edit.removing};
    if (!removing.remove(entryId)) removing.add(entryId);
    _put(collectionId, edit.copyWith(removing: removing));
  }

  /// [newIndex] is where the entry ends up, the removal already accounted
  /// for — what `onReorderItem` hands over.
  void reorder(
    String collectionId,
    HeldCollection held,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex == oldIndex) return;
    final edit = _staged(collectionId, held);
    final order = [...edit.order];
    final entryId = order.removeAt(oldIndex);
    order.insert(newIndex, entryId);
    _put(
      collectionId,
      edit.copyWith(order: order, dragged: {...edit.dragged, entryId}),
    );
  }

  CollectionEdit _staged(String collectionId, HeldCollection held) {
    final edit = state.staged[collectionId];
    if (edit != null) return edit;
    return CollectionEdit(
      name: held.name,
      original: held.entryIds,
      order: held.entryIds,
    );
  }

  void _put(String collectionId, CollectionEdit edit) {
    state = CollectionEditSession(
      active: state.active,
      staged: {...state.staged, collectionId: edit},
    );
  }
}

final collectionEditProvider =
    NotifierProvider<CollectionEditNotifier, CollectionEditSession>(
      CollectionEditNotifier.new,
    );
