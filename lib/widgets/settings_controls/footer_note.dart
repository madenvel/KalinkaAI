import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Muted footer text displayed below the last card in a tab section.
class FooterNote extends StatelessWidget {
  final String text;

  const FooterNote({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Text(
        text,
        style: KalinkaTextStyles.trayRowSublabel.copyWith(
          fontSize: 10,
          color: KalinkaColors.textMuted,
          height: 1.7,
        ),
      ),
    );
  }
}
