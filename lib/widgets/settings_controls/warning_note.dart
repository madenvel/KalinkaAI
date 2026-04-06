import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Red-tinted warning note displayed above cards with dangerous settings.
class WarningNote extends StatelessWidget {
  final String message;

  const WarningNote({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: KalinkaColors.statusOffline.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: KalinkaColors.statusOffline.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: KalinkaColors.goldSubtle.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.warning_amber_outlined,
              size: 24,
              color: KalinkaColors.statusOffline,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: KalinkaTextStyles.trayRowSublabel.copyWith(
                fontSize: KalinkaTypography.baseSize + 2,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
