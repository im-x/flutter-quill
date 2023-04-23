import 'package:flutter/material.dart';

import '../models/documents/nodes/embeddable.dart';

class QuillData {
  static double chatFontSizeScale = 1.3;
  static TextStyle chatFontStyle = const TextStyle(fontSize: 16);

  static double cursorWidth = 2;
  static double cursorHeight =
      (chatFontStyle.fontSize! * chatFontSizeScale).round().toDouble();

  static bool Function(InlineEmbed embed)? onInlineEmbedTap;
  static Widget Function(InlineEmbed embed, {bool canClick})?
      getInlineEmbedWidget;

  static String Function(int)? getUserDisplayName;

  static RegExp kHexColorRegex = RegExp(
    r'color:\s?(#[0-9a-fA-F]{6,8})',
  );

  static RegExp kRgbColorRegex = RegExp(
    r'color:\s?rgb\((\d+), (\d+), (\d+)\)',
  );

  static RegExp kInlineEmbedRegex = RegExp(
    r'\[@-?\d+:[\u4e00-\u9fa5A-Za-z0-9() _-]*?\]|\[:.+?\]|\[#.+?#\]|\[%.+?%\]',
  );
}
