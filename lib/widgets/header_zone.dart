import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/search_state_provider.dart';
import '../theme/app_theme.dart';
import 'kalinka_search_bar.dart';

/// Header zone with status bar safe area and persistent search bar.
/// Delegates to [KalinkaSearchBar] for the actual search input.
class HeaderZone extends ConsumerWidget {
  const HeaderZone({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: KalinkaColors.headerSurface,
        border: Border(
          bottom: BorderSide(color: KalinkaColors.borderElevated, width: 1),
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
          child: KalinkaSearchBar(
            alwaysExpanded: false,
            onCancel: () {
              ref.read(searchStateProvider.notifier).deactivateSearch();
            },
            onActivate: () {
              ref.read(searchStateProvider.notifier).activateSearch();
            },
          ),
        ),
      ),
    );
  }
}
