import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/kalinka_player_api_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/app_theme.dart';
import '../kalinka_button.dart';

enum _TestPhase { left, right, done }

/// Speaker test popup: lights up the left speaker for 2 seconds, then the
/// right, asking the server to play a tone on the matching channel at the
/// start of each segment. The visual sequence runs even when the server
/// can't play tones yet (endpoint added in a newer server release) — a
/// note explains that no sound will come out in that case.
class SpeakerTestDialog extends ConsumerStatefulWidget {
  const SpeakerTestDialog({super.key});

  @override
  ConsumerState<SpeakerTestDialog> createState() => _SpeakerTestDialogState();
}

class _SpeakerTestDialogState extends ConsumerState<SpeakerTestDialog>
    with SingleTickerProviderStateMixin {
  static const _segment = Duration(seconds: 2);

  _TestPhase _phase = _TestPhase.left;
  bool _unsupported = false;
  bool _toneFailed = false;
  Timer? _timer;
  int _runId = 0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _start() {
    final run = ++_runId;
    _timer?.cancel();
    setState(() {
      _phase = _TestPhase.left;
      _toneFailed = false;
    });
    _playTone('left');
    _timer = Timer(_segment, () {
      if (!mounted || run != _runId) return;
      setState(() => _phase = _TestPhase.right);
      _playTone('right');
      _timer = Timer(_segment, () {
        if (!mounted || run != _runId) return;
        setState(() => _phase = _TestPhase.done);
      });
    });
  }

  Future<void> _playTone(String channel) async {
    if (_unsupported) return;
    try {
      // Route through the user's (possibly still staged) device choice —
      // the staged ALSA selection isn't applied until the final restart.
      final device = ref
          .read(settingsProvider)
          .getEffective('base_config.output.alsa.device')
          ?.toString();
      await ref.read(kalinkaProxyProvider).testTone(channel, device: device);
    } on TestToneUnsupportedException {
      if (mounted) setState(() => _unsupported = true);
    } catch (_) {
      if (mounted) setState(() => _toneFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 340,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: KalinkaColors.surfaceRaised,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: KalinkaColors.borderDefault),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 48,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Testing output', style: KalinkaTextStyles.dialogTitle),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSpeaker('LEFT', _phase == _TestPhase.left),
                const SizedBox(width: 28),
                _buildSpeaker('RIGHT', _phase == _TestPhase.right),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 40,
              child: Center(
                child: Text(
                  switch (_phase) {
                    _TestPhase.left =>
                      'You should hear a tone from the left speaker.',
                    _TestPhase.right =>
                      'You should hear a tone from the right speaker.',
                    _TestPhase.done =>
                      'Heard both sides? You’re set. If not, pick a '
                          'different output device and test again.',
                  },
                  textAlign: TextAlign.center,
                  style: KalinkaTextStyles.dialogBody,
                ),
              ),
            ),
            if (_unsupported) ...[
              const SizedBox(height: 8),
              Text(
                'This server version can’t play test tones yet — '
                'update Kalinka server to hear them.',
                textAlign: TextAlign.center,
                style: KalinkaTextStyles.trayRowSublabel.copyWith(
                  color: KalinkaColors.statusPendingLight,
                ),
              ),
            ] else if (_toneFailed) ...[
              const SizedBox(height: 8),
              Text(
                'Could not reach the server to play the tone.',
                textAlign: TextAlign.center,
                style: KalinkaTextStyles.trayRowSublabel.copyWith(
                  color: KalinkaColors.statusPendingLight,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (_phase == _TestPhase.done) ...[
                  Expanded(
                    child: KalinkaButton(
                      label: 'Play again',
                      variant: KalinkaButtonVariant.neutral,
                      size: KalinkaButtonSize.compact,
                      fullWidth: true,
                      onTap: _start,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: KalinkaButton(
                    label: 'Close',
                    variant: _phase == _TestPhase.done
                        ? KalinkaButtonVariant.accent
                        : KalinkaButtonVariant.neutral,
                    size: KalinkaButtonSize.compact,
                    fullWidth: true,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeaker(String label, bool active) {
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: active
            ? KalinkaColors.accent.withValues(alpha: 0.12)
            : KalinkaColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? KalinkaColors.accent : KalinkaColors.borderDefault,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Icon(
        Icons.volume_up_rounded,
        size: 30,
        color: active ? KalinkaColors.accentTint : KalinkaColors.textMuted,
      ),
    );

    return Column(
      children: [
        active
            ? FadeTransition(opacity: _pulseAnimation, child: tile)
            : tile,
        const SizedBox(height: 8),
        Text(
          label,
          style: KalinkaTextStyles.sectionHeaderMuted.copyWith(
            color: active
                ? KalinkaColors.accentTint
                : KalinkaColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
