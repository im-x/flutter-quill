import 'package:flutter/material.dart';
import '../../../../common/structs/horizontal_spacing.dart';
import '../../../../document/attribute.dart';
import '../../../../document/nodes/block.dart';
import '../../default_styles.dart';

typedef LeadingBlockIndentWidth = HorizontalSpacing Function(
    Block block,
    BuildContext context,
    int count,
    LeadingBlockNumberPointWidth numberPointWidthDelegate);

typedef LeadingBlockNumberPointWidth = double Function(
    double fontSize, int count);

class TextBlockUtils {
  TextBlockUtils._();

  /// Get the horizontalSpacing using the default
  /// implementation provided by [Flutter Quill]
  static HorizontalSpacing defaultIndentWidthBuilder(
      Block block,
      BuildContext context,
      int count,
      LeadingBlockNumberPointWidth numberPointWidthBuilder) {
    final defaultStyles = QuillStyles.getStyles(context, false)!;
    final fontSize = defaultStyles.paragraph?.style.fontSize ?? 16;
    final attrs = block.style.attributes;

    final indent = attrs[Attribute.indent.key];
    var extraIndent = 0.0;
    if (indent != null && indent.value != null) {
      extraIndent = fontSize * indent.value;
    }

    if (attrs.containsKey(Attribute.blockQuote.key)) {
      return HorizontalSpacing(fontSize + extraIndent, 0);
    }

    var baseIndent = 0.0;

    if (attrs.containsKey(Attribute.list.key)) {
      baseIndent = fontSize * 1.35;
      if (attrs[Attribute.list.key] == Attribute.ol) {
        baseIndent = numberPointWidthBuilder(fontSize, count);
      } else if (attrs.containsKey(Attribute.codeBlock.key)) {
        baseIndent = numberPointWidthBuilder(fontSize, count);
      }
    }

    return HorizontalSpacing(baseIndent + extraIndent, 0);
  }

  /// Get the width for the number point leading using the default
  /// implementation provided by [Flutter Quill]
  static double defaultNumberPointWidthBuilder(double fontSize, int count,
      {bool isOL = false}) {
    final length = '$count'.length;
    switch (length) {
      case 1:
        return fontSize * 1.35;
      case 2:
        return fontSize * 1.5;
      case 3:
        return fontSize * 1.7;
      default:
        // 3 -> 2.5
        // 4 -> 3
        // 5 -> 3.5
        return fontSize * (length - (length - 2) / 2);
    }
  }
}
