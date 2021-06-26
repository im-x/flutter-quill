import 'package:flutter/material.dart';

class QuillData {
  static const chatFontSizeScale = 1.3;
  static const chatFontStyle = TextStyle(fontSize: 16);

  static const cursorWidth = 2.0;
  static final double cursorHeight =
      (chatFontStyle.fontSize! * chatFontSizeScale).round().toDouble();

  static bool Function(String type)? onInlineEmbedTap;
  static Widget Function(String type)? getInlineEmbedWidget;
}
