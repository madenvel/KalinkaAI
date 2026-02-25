import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// List editor control for array-type settings (e.g. music folder paths).
///
/// Items are shown as editable text fields. "Add item" appends a blank entry
/// and focuses it. Remove buttons delete individual entries.
class SettingsListEditor extends StatefulWidget {
  final List<String> items;
  final ValueChanged<List<String>> onChanged;
  final String addHint;

  const SettingsListEditor({
    super.key,
    required this.items,
    required this.onChanged,
    this.addHint = 'Add item...',
  });

  @override
  State<SettingsListEditor> createState() => _SettingsListEditorState();
}

class _SettingsListEditorState extends State<SettingsListEditor> {
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];
  bool _focusNext = false;

  @override
  void initState() {
    super.initState();
    _buildControllers(widget.items);
  }

  @override
  void didUpdateWidget(SettingsListEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newLen = widget.items.length;
    final curLen = _controllers.length;

    if (newLen != curLen) {
      // Length changed (add/remove): rebuild all controllers from the new list.
      _disposeControllers();
      _buildControllers(widget.items);
      if (_focusNext && _controllers.isNotEmpty) {
        _focusNext = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _focusNodes.last.requestFocus();
        });
      }
    } else {
      // Same length: sync text only for fields that are NOT currently focused.
      // This lets an in-progress edit survive a provider rebuild while still
      // resetting values when an external change occurs (e.g. Discard).
      for (int i = 0; i < newLen; i++) {
        if (!_focusNodes[i].hasFocus && _controllers[i].text != widget.items[i]) {
          _controllers[i].text = widget.items[i];
        }
      }
    }
  }

  void _buildControllers(List<String> items) {
    for (final item in items) {
      _controllers.add(TextEditingController(text: item));
      _focusNodes.add(FocusNode());
    }
  }

  void _disposeControllers() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _controllers.clear();
    _focusNodes.clear();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _removeItem(int index) {
    final newItems = List<String>.from(widget.items)..removeAt(index);
    widget.onChanged(newItems);
  }

  void _addItem() {
    _focusNext = true;
    widget.onChanged(List<String>.from(widget.items)..add(''));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...List.generate(_controllers.length, (i) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: i < _controllers.length - 1 ? 6 : 0,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: KalinkaColors.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: KalinkaColors.borderDefault),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      style: KalinkaTextStyles.trayRowSublabel.copyWith(
                        fontSize: 11,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (_) {
                        widget.onChanged(
                          _controllers.map((c) => c.text).toList(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 7),
                  GestureDetector(
                    onTap: () => _removeItem(i),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: KalinkaColors.statusError.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 10,
                        color: KalinkaColors.statusError,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (_controllers.isNotEmpty) const SizedBox(height: 6),
        GestureDetector(
          onTap: _addItem,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 13, color: KalinkaColors.accent),
                const SizedBox(width: 4),
                Text(
                  'Add item',
                  style: KalinkaTextStyles.trayRowLabel.copyWith(
                    fontSize: 10,
                    color: KalinkaColors.accent,
                    letterSpacing: 0.03,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
