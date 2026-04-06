import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// "K" lettermark in Instrument Serif italic, positioned in the header.
class KalinkaWordmark extends StatelessWidget {
  const KalinkaWordmark({super.key});

  @override
  Widget build(BuildContext context) {
    return Text('K', style: KalinkaTextStyles.lettermark);
  }
}
