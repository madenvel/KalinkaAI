import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'connection_settings_provider.dart';

/// First-run state persisted across launches.
///
/// `oobeComplete` flips only when the user finishes the whole setup wizard
/// (final restart triggered). An interrupted run — app killed mid-wizard —
/// leaves it false and, because the wizard connects ephemerally, no stored
/// server either, so the next launch restarts setup from the beginning.
/// Backgrounding does not reset anything: the wizard's widget state stays
/// alive while the app is alive.
///
/// `coachMarksShown` flips after the one-time UI tour on the play queue.
class OnboardingStatus {
  final bool oobeComplete;
  final bool coachMarksShown;

  const OnboardingStatus({
    required this.oobeComplete,
    required this.coachMarksShown,
  });

  OnboardingStatus copyWith({bool? oobeComplete, bool? coachMarksShown}) {
    return OnboardingStatus(
      oobeComplete: oobeComplete ?? this.oobeComplete,
      coachMarksShown: coachMarksShown ?? this.coachMarksShown,
    );
  }
}

class OnboardingStatusNotifier extends Notifier<OnboardingStatus> {
  static const String sharedPrefOobeComplete = 'Kalinka.oobeComplete';
  static const String sharedPrefCoachMarksShown = 'Kalinka.coachMarksShown';

  /// Testing hook: `flutter run --dart-define=KALINKA_FORCE_OOBE=true`
  /// replays the setup wizard and the coach-mark tour on every launch,
  /// regardless of stored flags or a stored server. Finishing the wizard
  /// still behaves normally within the session; the next launch resets.
  static const bool forceOobe = bool.fromEnvironment('KALINKA_FORCE_OOBE');

  @override
  OnboardingStatus build() {
    if (forceOobe) {
      return const OnboardingStatus(
        oobeComplete: false,
        coachMarksShown: false,
      );
    }

    final prefs = ref.read(sharedPrefsProvider);
    var oobeComplete = prefs.getBool(sharedPrefOobeComplete) ?? false;

    // Upgrade path: installs that predate the wizard already have a server
    // stored. Treat them as set up — they only get the coach-mark tour.
    if (!oobeComplete && ref.read(connectionSettingsProvider).isSet) {
      oobeComplete = true;
      // Intentionally fire-and-forget: build() is synchronous and the
      // in-memory state already carries the answer. If the write never
      // lands, the next launch re-derives the same result from the stored
      // server, so a failure here is benign.
      prefs.setBool(sharedPrefOobeComplete, true).ignore();
    }

    return OnboardingStatus(
      oobeComplete: oobeComplete,
      coachMarksShown: prefs.getBool(sharedPrefCoachMarksShown) ?? false,
    );
  }

  Future<void> markOobeComplete() async {
    await ref
        .read(sharedPrefsProvider)
        .setBool(sharedPrefOobeComplete, true);
    state = state.copyWith(oobeComplete: true);
  }

  Future<void> markCoachMarksShown() async {
    await ref
        .read(sharedPrefsProvider)
        .setBool(sharedPrefCoachMarksShown, true);
    state = state.copyWith(coachMarksShown: true);
  }
}

final onboardingStatusProvider =
    NotifierProvider<OnboardingStatusNotifier, OnboardingStatus>(
      OnboardingStatusNotifier.new,
    );
