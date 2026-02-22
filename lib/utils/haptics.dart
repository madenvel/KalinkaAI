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
class KalinkaHaptics {
  // ── Single-shot impacts ────────────────────────────────────────────────────

  static void selectionClick() {
    if (Platform.isAndroid) {
      Vibration.vibrate(duration: 15, amplitude: 80);
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
}
