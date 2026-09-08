import 'package:flutter/material.dart';

/// The cursor a clickable control shows. Material's own default is
/// `adaptiveClickable`, which is the plain arrow everywhere but web, so an
/// [InkWell] has to be told; one that cannot be tapped keeps the arrow.
MouseCursor clickCursor({required bool interactive}) =>
    interactive ? SystemMouseCursors.click : SystemMouseCursors.basic;
