import 'package:flutter/widgets.dart';

import '../../providers/settings_binding.dart';

export '../../providers/settings_binding.dart'
    show EnumOptionSource, SettingsBinding;

/// Supplies the [SettingsBinding] the schema widgets below it render against.
///
/// Rebuild this with a fresh [binding] whenever the underlying store changes;
/// the subtree re-reads through [of].
class SettingsScope extends InheritedWidget {
  final SettingsBinding binding;

  const SettingsScope({super.key, required this.binding, required super.child});

  static SettingsBinding of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'No SettingsScope above this settings widget');
    return scope!.binding;
  }

  @override
  bool updateShouldNotify(SettingsScope oldWidget) =>
      !identical(oldWidget.binding, binding);
}
