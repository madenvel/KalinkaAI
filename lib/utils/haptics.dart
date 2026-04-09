import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Platform-aware haptic utility.
///
/// iOS  — uses Flutter's HapticFeedback (CoreHaptics taptic engine, excellent).
/// Android — uses the `vibration` package with explicit duration+amplitude,
///           which drives the vibration motor directly and produces distinct
///           intensities on Android 8+ devices. Falls back gracefully on
///           older hardware that lacks amplitude control.
///           corkPop() additionally uses the native KaiMediaPlugin channel to
///           access VibrationEffect.Composition (API 31+) for OEM-tuned primitives.
class KalinkaHaptics {
  static const _nativeChannel = MethodChannel(
    'org.kalinka.kalinka/media_session',
  );
  // ── Single-shot impacts ────────────────────────────────────────────────────

  static void selectionClick() {
    if (Platform.isAndroid) {
      _nativeChannel.invokeMethod('hapticTick').catchError((_) {
        Vibration.vibrate(duration: 15, amplitude: 80);
      });
    } else {
      HapticFeedback.selectionClick();
    }
  }

  static void lightImpact() {
    if (Platform.isAndroid) {
      Vibration.vibrate(duration: 20, amplitude: 110);
    } else {
      HapticFeedback.lightImpact();
    }
  }

  static void mediumImpact() {
    if (Platform.isAndroid) {
      Vibration.vibrate(duration: 35, amplitude: 160);
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  static void heavyImpact() {
    if (Platform.isAndroid) {
      Vibration.vibrate(duration: 50, amplitude: 230);
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  // ── Multi-beat patterns ────────────────────────────────────────────────────

  /// Double-pulse: "connection issue" signature.
  ///
  /// On Android, a single vibrate(pattern:) call handles timing precisely.
  /// On iOS, two sequential HapticFeedback calls with a delay.
  static Future<void> doublePulse() async {
    if (Platform.isAndroid) {
      Vibration.vibrate(
        pattern: [0, 40, 100, 25],
        intensities: [0, 180, 0, 110],
      );
    } else {
      HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      HapticFeedback.lightImpact();
    }
  }

  /// Crescendo: soft then strong — "success / done" signature.
  ///
  /// On Android, a single pattern call with rising amplitude.
  /// On iOS, two sequential calls with a gap.
  static Future<void> successCrescendo() async {
    if (Platform.isAndroid) {
      Vibration.vibrate(
        pattern: [0, 30, 80, 70],
        intensities: [0, 100, 0, 230],
      );
    } else {
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 60));
      HapticFeedback.heavyImpact();
    }
  }

  /// Cork pop: sharp heavy burst then quick light settle — "action unlocked".
  ///
  /// Designed for the moment a swipe action crosses its activation threshold:
  /// a sudden release from resistance, like a cork coming out of a bottle.
  /// Decrescendo (strong→light), opposite of successCrescendo.
  ///
  /// On Android 11+ (API 31): uses VibrationEffect.Composition with
  /// PRIMITIVE_THUD (body) + PRIMITIVE_TICK at 40ms (resonance tail) via the
  /// native channel, giving OEM-tuned physically realistic primitives.
  /// Falls back to a stepped waveform envelope on API 26–30.
  ///
  /// On iOS, heavyImpact() alone produces a very good чпок via the Taptic
  /// Engine — no custom waveform needed.
  static Future<void> corkPop() async {
    if (Platform.isAndroid) {
      try {
        await _nativeChannel.invokeMethod('hapticCorkPop');
      } catch (_) {
        // Native channel unavailable — waveform envelope approximation.
        Vibration.vibrate(
          pattern: [0, 5, 5, 15, 10],
          intensities: [0, 180, 220, 80, 0],
        );
      }
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  /// Delete: crisp tick forewarning then heavy thud landing — "item removed".
  ///
  /// Reversal of corkPop: TICK first (light warning at threshold crossing),
  /// THUD second (weighty confirmation of removal). The asymmetry distinguishes
  /// destructive actions from additive ones at the motor level.
  ///
  /// On Android 11+ (API 31): PRIMITIVE_TICK → PRIMITIVE_THUD via native channel.
  /// Falls back to a reversed waveform envelope on API 26–30.
  ///
  /// On iOS: lightImpact → heavyImpact with a short gap mirrors the same feel.
  static Future<void> hapticDelete() async {
    if (Platform.isAndroid) {
      try {
        await _nativeChannel.invokeMethod('hapticDelete');
      } catch (_) {
        // Native channel unavailable — reversed waveform approximation.
        Vibration.vibrate(
          pattern: [0, 8, 20, 30],
          intensities: [0, 80, 0, 220],
        );
      }
    } else {
      HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 30));
      HapticFeedback.heavyImpact();
    }
  }
}
