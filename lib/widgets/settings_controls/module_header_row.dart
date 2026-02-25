import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Status of a module/device.
enum ModuleStatus { ready, error, disabled }

/// Rich header row for module/device cards with icon tile, status badge, and chevron.
class ModuleHeaderRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final ModuleStatus? status;
  final bool expanded;
  final VoidCallback onToggle;

  const ModuleHeaderRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.status,
    required this.expanded,
    required this.onToggle,
  });

  /// Determine icon and color based on module name.
  static (IconData, Color) iconForModule(String moduleName) {
    final name = moduleName.toLowerCase();
    if (name.contains('local') || name.contains('file')) {
      return (Icons.folder_outlined, KalinkaColors.accent);
    }
    if (name.contains('qobuz')) {
      return (Icons.music_note_outlined, KalinkaColors.gold);
    }
    if (name.contains('tidal')) {
      return (Icons.waves_outlined, const Color(0xFF4ADE80));
    }
    if (name.contains('spotify')) {
      return (Icons.music_note_outlined, const Color(0xFF1DB954));
    }
    return (Icons.extension_outlined, KalinkaColors.textSecondary);
  }

  /// Determine icon and color for a device.
  static (IconData, Color) iconForDevice(String deviceName) {
    return (Icons.speaker_outlined, KalinkaColors.textSecondary);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: const BoxDecoration(color: KalinkaColors.surfaceInput),
        child: Row(
          children: [
            // Icon tile
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 15, color: iconColor),
            ),
            const SizedBox(width: 10),
            // Module info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: KalinkaTextStyles.trayRowLabel.copyWith(
                      fontSize: 13,
                      letterSpacing: -0.01,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: KalinkaTextStyles.trayRowSublabel.copyWith(
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            // Status badge
            if (status != null && status != ModuleStatus.disabled)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: _badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _badgeColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  _badgeLabel,
                  style: KalinkaTextStyles.tagPill.copyWith(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: _badgeColor,
                  ),
                ),
              ),
            // Chevron
            AnimatedRotation(
              turns: expanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 220),
              child: const Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: KalinkaColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color get _badgeColor => switch (status) {
    ModuleStatus.ready => KalinkaColors.statusOnline,
    ModuleStatus.error => KalinkaColors.statusError,
    _ => KalinkaColors.textMuted,
  };

  String get _badgeLabel => switch (status) {
    ModuleStatus.ready => 'READY',
    ModuleStatus.error => 'ERROR',
    _ => '',
  };
}
