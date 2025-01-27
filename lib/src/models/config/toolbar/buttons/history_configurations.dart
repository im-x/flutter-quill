import 'package:flutter/foundation.dart' show immutable;

import '../../../../../flutter_quill.dart';

@immutable
class QuillToolbarHistoryButtonExtraOptions
    extends QuillToolbarBaseButtonExtraOptions {
  const QuillToolbarHistoryButtonExtraOptions({
    required this.canPressed,
    required super.controller,
    required super.context,
    required super.onPressed,
  });

  /// If it can redo or undo
  final bool canPressed;
}

@immutable
class QuillToolbarHistoryButtonOptions extends QuillToolbarBaseButtonOptions<
    QuillToolbarHistoryButtonOptions, QuillToolbarHistoryButtonExtraOptions> {
  const QuillToolbarHistoryButtonOptions({
    super.iconData,
    super.controller,
    super.iconTheme,
    super.afterButtonPressed,
    super.tooltip,
    super.childBuilder,
    this.iconSize,
    this.iconButtonFactor,
  });

  /// By default will use [globalIconSize]
  final double? iconSize;
  final double? iconButtonFactor;
}
