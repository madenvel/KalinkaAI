import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data_model/data_model.dart';
import 'connection_settings_provider.dart' show sharedPrefsProvider;

/// The two persistent add-to-queue modes.
enum AddMode { askEachTime, alwaysAppend }

/// Runtime state for the add-to-queue interaction model.
class AddModeState {
  /// Persistent preference — which mode the + button uses.
  final AddMode addMode;

  /// Persistent flag — true after the first-encounter prompt has been shown.
  final bool firstEncounterShown;

  /// Session-scoped — true after the "Hold for options" tooltip has been
  /// displayed once this session (Mode B only).
  final bool holdForOptionsTooltipShown;

  /// Session-scoped — non-null when a + tap was intercepted because the
  /// first-encounter prompt hasn't been shown yet.  The prompt widget
  /// reads this to know what item triggered it.
  final BrowseItem? firstEncounterTriggerItem;

  const AddModeState({
    this.addMode = AddMode.askEachTime,
    this.firstEncounterShown = false,
    this.holdForOptionsTooltipShown = false,
    this.firstEncounterTriggerItem,
  });

  AddModeState copyWith({
    AddMode? addMode,
    bool? firstEncounterShown,
    bool? holdForOptionsTooltipShown,
    BrowseItem? firstEncounterTriggerItem,
    bool clearTriggerItem = false,
  }) {
    return AddModeState(
      addMode: addMode ?? this.addMode,
      firstEncounterShown: firstEncounterShown ?? this.firstEncounterShown,
      holdForOptionsTooltipShown:
          holdForOptionsTooltipShown ?? this.holdForOptionsTooltipShown,
      firstEncounterTriggerItem: clearTriggerItem
          ? null
          : (firstEncounterTriggerItem ?? this.firstEncounterTriggerItem),
    );
  }
}

/// SharedPreferences keys.
const _addModeKey = 'Kalinka.addMode';
const _firstEncounterKey = 'Kalinka.firstEncounterShown';

class AddModeNotifier extends Notifier<AddModeState> {
  late SharedPreferences _prefs;

  @override
  AddModeState build() {
    _prefs = ref.read(sharedPrefsProvider);
    return _load();
  }

  AddModeState _load() {
    final modeString = _prefs.getString(_addModeKey);
    final addMode = modeString == 'alwaysAppend'
        ? AddMode.alwaysAppend
        : AddMode.askEachTime;
    final firstEncounterShown = _prefs.getBool(_firstEncounterKey) ?? false;
    return AddModeState(
      addMode: addMode,
      firstEncounterShown: firstEncounterShown,
    );
  }

  /// Set the persistent add mode.
  Future<void> setAddMode(AddMode mode) async {
    await _prefs.setString(
      _addModeKey,
      mode == AddMode.alwaysAppend ? 'alwaysAppend' : 'askEachTime',
    );
    state = state.copyWith(addMode: mode);
  }

  /// Mark the first-encounter prompt as shown (persisted).
  Future<void> markFirstEncounterShown() async {
    await _prefs.setBool(_firstEncounterKey, true);
    state = state.copyWith(firstEncounterShown: true, clearTriggerItem: true);
  }

  /// Mark the "Hold for options" tooltip as shown this session (not persisted).
  void markHoldTooltipShown() {
    state = state.copyWith(holdForOptionsTooltipShown: true);
  }

  /// Set the trigger item that caused the first-encounter prompt to show.
  void triggerFirstEncounter(BrowseItem item) {
    state = state.copyWith(firstEncounterTriggerItem: item);
  }

  /// Clear the trigger item (e.g. prompt dismissed without action).
  void clearFirstEncounterTrigger() {
    state = state.copyWith(clearTriggerItem: true);
  }
}

final addModeProvider = NotifierProvider<AddModeNotifier, AddModeState>(
  AddModeNotifier.new,
);
