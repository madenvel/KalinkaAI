import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data_model/data_model.dart';
import '../../providers/collections_provider.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/toast_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/field_decoration.dart';
import '../../utils/haptics.dart';
import '../kalinka_bottom_sheet.dart';
import '../kalinka_button.dart';
import '../kalinka_dialog.dart';
import '../search_cards/collection_identity.dart';
import '../tap_highlight.dart';
import 'collection_name_sheet.dart';

/// What a sheet is about to save into a collection, and the words it asks
/// with.
///
/// [itemIds] may name tracks or anything that holds them — the server expands
/// a container through its own source, so a caller need not page one out. The
/// words come with the addition rather than from the sheet, so every entry
/// point says what it is saving in its own terms; make one factory per entry
/// point here, so no two call sites can drift apart in their wording.
class CollectionAddition {
  final List<String> itemIds;

  /// The sheet's own title.
  final String heading;

  /// What is being saved, under the title.
  final String summary;

  /// What making a new collection would do with it.
  final String createNote;

  /// How much is being saved, as the action names it: `12 tracks`. What
  /// becomes of it is asked in the sheet, so the verb is the sheet's and only
  /// the amount comes from here.
  final String amount;

  const CollectionAddition({
    required this.itemIds,
    required this.heading,
    required this.summary,
    required this.createNote,
    required this.amount,
  });

  /// The play queue as it stands, in the order it plays.
  factory CollectionAddition.queue(List<String> trackIds) {
    final tracks = _tracks(trackIds.length);
    return CollectionAddition(
      itemIds: trackIds,
      heading: 'SAVE QUEUE TO COLLECTION',
      summary: '$tracks from queue',
      createNote: 'Name it and add this queue',
      amount: tracks,
    );
  }
}

/// Asks which collection [addition] goes into, and how, then puts it there —
/// reporting through the shared toast. True when something landed.
Future<bool> showAddToCollectionSheet(
  BuildContext context,
  CollectionAddition addition,
) async {
  final landed = await showKalinkaBottomSheet<bool>(
    context: context,
    contentBuilder: (_) => _AddToCollectionSheet(addition: addition),
  );
  return landed ?? false;
}

String _tracks(int count) => '$count ${count == 1 ? 'track' : 'tracks'}';

String _nameOf(BrowseItem item) =>
    item.playlist?.name ?? item.name ?? 'the collection';

class _AddToCollectionSheet extends ConsumerStatefulWidget {
  final CollectionAddition addition;

  const _AddToCollectionSheet({required this.addition});

  @override
  ConsumerState<_AddToCollectionSheet> createState() =>
      _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends ConsumerState<_AddToCollectionSheet> {
  final _search = TextEditingController();
  String? _chosenId;

  /// Opting to drop what the collection holds. Starts off every time the
  /// sheet opens: adding is what saving means unless it is asked otherwise.
  bool _replace = false;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<BrowseItem> _matching(List<BrowseItem> items) {
    final needle = _search.text.trim().toLowerCase();
    if (needle.isEmpty) return items;
    return [
      for (final item in items)
        if (_nameOf(item).toLowerCase().contains(needle)) item,
    ];
  }

  BrowseItem? _chosen(List<BrowseItem> items) =>
      items.where((item) => item.id == _chosenId).firstOrNull;

  Future<void> _createAndSave() async {
    KalinkaHaptics.lightImpact();
    final made = await createCollectionByName(context, ref);
    if (made == null || !mounted) return;
    // Nothing to keep or drop in one just made, whatever the box says.
    await _save(made.id, made.name, replace: false, created: true);
  }

  Future<void> _saveToChosen(List<BrowseItem> items) async {
    final chosen = _chosen(items);
    if (chosen == null) return;
    if (!await _confirmed(chosen)) return;
    KalinkaHaptics.mediumImpact();
    await _save(chosen.id, _nameOf(chosen), replace: _replace);
  }

  /// Nothing keeps what a replace drops, so a collection with tracks in it is
  /// named back to the user before it loses them. Everything else goes ahead.
  Future<bool> _confirmed(BrowseItem chosen) async {
    final held = chosen.playlist?.trackCount ?? 0;
    if (!_replace || held == 0) return true;
    final go = await showKalinkaDialog<bool>(
      context: context,
      builder: (dialog) => KalinkaDialog(
        side: KalinkaDialogSide.right,
        icon: Icons.swap_horiz_rounded,
        iconColor: KalinkaColors.actionDelete,
        title: 'Replace ${_nameOf(chosen)}?',
        message: 'Its ${_tracks(held)} will be dropped. This cannot be undone.',
        actions: [
          KalinkaButton(
            label: 'Cancel',
            variant: KalinkaButtonVariant.neutral,
            fullWidth: true,
            onTap: () => Navigator.pop(dialog, false),
          ),
          KalinkaButton(
            label: 'Replace',
            fullWidth: true,
            onTap: () => Navigator.pop(dialog, true),
          ),
        ],
      ),
    );
    return go == true;
  }

  Future<void> _save(
    String id,
    String name, {
    required bool replace,
    bool created = false,
  }) async {
    setState(() => _busy = true);
    final toast = ref.read(toastProvider.notifier);
    try {
      final (landed, report) = await _write(id, name, replace, created);
      ref.read(collectionsRevisionProvider.notifier).bump();
      toast.show(report);
      if (mounted) Navigator.of(context).pop(landed > 0);
    } catch (e) {
      final what = replace ? 'replace' : 'add to';
      toast.show('Could not $what $name: $e', isError: true);
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The write itself, and what to say about how it went.
  Future<(int, String)> _write(
    String id,
    String name,
    bool replace,
    bool created,
  ) async {
    final api = ref.read(kalinkaProxyProvider);
    final ids = widget.addition.itemIds;
    if (replace) {
      final outcome = await api.replaceCollection(id, ids);
      return (outcome.added, '$name now holds ${_tracks(outcome.added)}');
    }
    final outcome = await api.addToCollection(id, ids);
    return (outcome.added, _report(name, outcome, created: created));
  }

  /// What ticking the box would cost, named against the collection it would
  /// cost it from.
  String _cost(BrowseItem? chosen) {
    if (chosen == null) return 'Remove what the collection holds first.';
    final held = chosen.playlist?.trackCount ?? 0;
    if (held == 0) return '${_nameOf(chosen)} is empty — nothing to remove.';
    return 'Remove all ${_tracks(held)} from ${_nameOf(chosen)} first.';
  }

  @override
  Widget build(BuildContext context) {
    final choices = ref.watch(collectionChoicesProvider);
    final items = choices.value ?? const <BrowseItem>[];
    final matching = _matching(items);
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    final amount = widget.addition.amount.toUpperCase();

    return Padding(
      // Clears the keyboard the search field raises.
      padding: EdgeInsets.only(bottom: insets),
      child: ConstrainedBox(
        // Everything but the list is a fixed height, so bounding the sheet is
        // what gives the list its own bound — however many there are, and
        // whatever room a keyboard has left.
        constraints: BoxConstraints(
          maxHeight: (MediaQuery.sizeOf(context).height - insets) * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(kSheetGutter, 16, 12, 14),
              child: _Head(addition: widget.addition),
            ),
            const SheetDivider(),
            SheetRow(
              icon: Icons.add_rounded,
              iconBackground: KalinkaColors.accentSubtle,
              iconColor: KalinkaColors.accentTint,
              label: 'Create new collection',
              sublabel: widget.addition.createNote,
              trailing: const SheetChevron(),
              onTap: _busy ? null : _createAndSave,
            ),
            const SheetDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kSheetGutter,
                14,
                kSheetGutter,
                12,
              ),
              child: TextField(
                controller: _search,
                style: KalinkaTextStyles.cardTitle,
                textInputAction: TextInputAction.search,
                decoration: kalinkaFieldDecoration(
                  hint: 'Find a collection',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: KalinkaColors.textMuted,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kSheetGutter,
                0,
                kSheetGutter,
                6,
              ),
              child: Text(
                choices.hasValue
                    ? 'YOUR COLLECTIONS · ${matching.length}'
                    : 'YOUR COLLECTIONS',
                style: KalinkaTextStyles.sectionLabel,
              ),
            ),
            Flexible(
              child: choices.when(
                data: (_) => _Choices(
                  items: matching,
                  chosenId: _chosenId,
                  onChoose: (id) => setState(() => _chosenId = id),
                  narrowed: _search.text.trim().isNotEmpty,
                ),
                loading: () =>
                    const _Filler(child: CircularProgressIndicator()),
                error: (e, _) => _Filler(
                  child: Text(
                    'Could not read your collections',
                    style: KalinkaTextStyles.trackRowSubtitle,
                  ),
                ),
              ),
            ),
            const SheetDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kSheetGutter,
                14,
                kSheetGutter,
                12,
              ),
              child: _ReplaceCheck(
                ticked: _replace,
                cost: _cost(_chosen(items)),
                onChanged: (ticked) => setState(() => _replace = ticked),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                kSheetGutter,
                0,
                kSheetGutter,
                8,
              ),
              child: KalinkaButton(
                label: _replace ? 'REPLACE WITH $amount' : 'ADD $amount',
                fullWidth: true,
                enabled: _chosenId != null && !_busy,
                onTap: () => _saveToChosen(items),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the add came to, in one line. A fresh collection had nothing to
/// already hold, so it is reported as made and filled in one breath.
String _report(
  String name,
  ({int added, int alreadyThere}) outcome, {
  required bool created,
}) {
  if (created) return '$name created with ${_tracks(outcome.added)}';
  if (outcome.added == 0) return 'Already in $name';
  final landed = 'Added ${_tracks(outcome.added)} to $name';
  if (outcome.alreadyThere == 0) return landed;
  return '$landed · ${outcome.alreadyThere} already there';
}

class _Head extends StatelessWidget {
  final CollectionAddition addition;

  const _Head({required this.addition});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(addition.heading, style: KalinkaTextStyles.sectionLabel),
              const SizedBox(height: 6),
              Text(addition.summary, style: KalinkaTextStyles.trackRowSubtitle),
            ],
          ),
        ),
        const SizedBox(width: 6),
        TapHighlight(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(
              Icons.close_rounded,
              size: 22,
              color: KalinkaColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// The one thing on the sheet that takes something away, so it is the one
/// thing drawn in red and the one thing that has to be asked for. Unticked,
/// saving adds; ticked, it leaves the collection holding only what is saved.
class _ReplaceCheck extends StatelessWidget {
  final bool ticked;

  /// What ticking it costs, named against the collection chosen above.
  final String cost;

  final ValueChanged<bool> onChanged;

  const _ReplaceCheck({
    required this.ticked,
    required this.cost,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: ticked,
      label: 'Replace collection contents',
      child: TapHighlight(
        onTap: () {
          KalinkaHaptics.selectionClick();
          onChanged(!ticked);
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ticked
                ? KalinkaColors.statusOfflineSurface
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: ticked
                  ? KalinkaColors.actionDelete
                  : KalinkaColors.borderDefault,
            ),
          ),
          child: Row(
            children: [
              _CheckBox(ticked: ticked),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Replace collection contents',
                      style: KalinkaTextStyles.trayRowLabel.copyWith(
                        color: ticked ? KalinkaColors.actionDelete : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(cost, style: KalinkaTextStyles.trayRowSublabel),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  final bool ticked;

  const _CheckBox({required this.ticked});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: ticked ? KalinkaColors.actionDelete : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ticked
              ? KalinkaColors.actionDelete
              : KalinkaColors.borderDefault,
        ),
      ),
      child: ticked
          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
          : null,
    );
  }
}

/// The collections to choose between. Sized to what it holds, up to the room
/// the sheet leaves it.
class _Choices extends StatelessWidget {
  final List<BrowseItem> items;
  final String? chosenId;
  final ValueChanged<String> onChoose;

  /// Whether the search field is holding something back, which is what tells
  /// an empty list apart from a library with nothing in it yet.
  final bool narrowed;

  const _Choices({
    required this.items,
    required this.chosenId,
    required this.onChoose,
    required this.narrowed,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _Filler(
        child: Text(
          narrowed
              ? 'No collection by that name'
              : 'No collections yet — make the first one above',
          textAlign: TextAlign.center,
          style: KalinkaTextStyles.trackRowSubtitle,
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: items.length,
      itemBuilder: (_, i) => _ChoiceRow(
        item: items[i],
        chosen: items[i].id == chosenId,
        onTap: () => onChoose(items[i].id),
      ),
    );
  }
}

/// Holds the list's place while there is nothing to put in it, so the sheet
/// does not resize under the pointer as it loads.
class _Filler extends StatelessWidget {
  final Widget child;

  const _Filler({required this.child});

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: 120, child: Center(child: child));
}

class _ChoiceRow extends StatelessWidget {
  final BrowseItem item;
  final bool chosen;
  final VoidCallback onTap;

  const _ChoiceRow({
    required this.item,
    required this.chosen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: chosen,
      label: _nameOf(item),
      child: TapHighlight(
        onTap: onTap,
        inset: kSheetGutter,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          // The 3px the edge takes comes out of the inset, so choosing a row
          // does not nudge its artwork sideways.
          padding: EdgeInsets.only(
            top: 8,
            bottom: 8,
            right: kSheetGutter,
            left: chosen ? kSheetGutter - 3 : kSheetGutter,
          ),
          decoration: BoxDecoration(
            color: chosen ? KalinkaColors.accent.withValues(alpha: 0.07) : null,
            border: chosen
                ? const Border(
                    left: BorderSide(color: KalinkaColors.accent, width: 3),
                  )
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: CollectionIdentity(item: item, chosen: chosen),
              ),
              const SizedBox(width: 10),
              _ChoiceMark(chosen: chosen),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceMark extends StatelessWidget {
  final bool chosen;

  const _ChoiceMark({required this.chosen});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: chosen ? KalinkaColors.accent : Colors.transparent,
        border: Border.all(
          color: chosen ? KalinkaColors.accent : KalinkaColors.borderDefault,
        ),
      ),
      child: chosen
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}
