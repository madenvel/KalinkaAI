import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'ai_search_pill.dart';

/// Header zone with status bar safe area and AI search pill.
class HeaderZone extends StatelessWidget {
  final VoidCallback? onSearchTap;

  const HeaderZone({super.key, this.onSearchTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: KalinkaColors.headerSurface,
        border: Border(
          bottom: BorderSide(color: KalinkaColors.borderDefault, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 2),
            blurRadius: 6,
            color: Color(0x40000000),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: AiSearchPill(onTap: onSearchTap),
        ),
      ),
    );
  }
}
