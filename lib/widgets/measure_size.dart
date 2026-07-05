import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Reports its child's size after each layout via [onChange]. Lets a sibling
/// (typically a scroll view) reserve space for a floating, variable-height
/// widget without a hard-coded guess — the content padding tracks the real
/// height as it grows or the safe-area/keyboard changes.
///
/// The callback is deferred to the post-frame so it can safely call setState.
class MeasureSize extends SingleChildRenderObjectWidget {
  final ValueChanged<Size> onChange;

  const MeasureSize({
    super.key,
    required this.onChange,
    required Widget super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _MeasureSizeRender(onChange);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _MeasureSizeRender).onChange = onChange;
  }
}

class _MeasureSizeRender extends RenderProxyBox {
  _MeasureSizeRender(this.onChange);

  ValueChanged<Size> onChange;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = size;
    if (_last == newSize) return;
    _last = newSize;
    // Layout is in progress; defer the setState-driving callback to post-frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(newSize));
  }
}
