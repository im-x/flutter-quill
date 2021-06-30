import 'package:flutter/material.dart';

class QuillData {
  static double chatFontSizeScale = 1.3;
  static TextStyle chatFontStyle = const TextStyle(fontSize: 16);

  static double cursorWidth = 2;
  static double cursorHeight =
      (chatFontStyle.fontSize! * chatFontSizeScale).round().toDouble();

  static bool Function(String type)? onInlineEmbedTap;
  static Widget Function(String type)? getInlineEmbedWidget;
}
