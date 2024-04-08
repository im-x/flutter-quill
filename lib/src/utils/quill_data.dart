import 'package:flutter/material.dart';

class QuillData {
  static double chatFontSizeScale = 1.3;
  static TextStyle chatFontStyle = const TextStyle(fontSize: 16);

  static double cursorWidth = 2;
  static double cursorHeight =
      (chatFontStyle.fontSize! * chatFontSizeScale).round().toDouble();

  static String Function(int)? getUserDisplayName;

  static RegExp kHexColorRegex = RegExp(
    r'color:\s?(#[0-9a-fA-F]{6,8})',
  );

  static RegExp kHexBackgroundColorRegex = RegExp(
    r'background-color:\s?(#[0-9a-fA-F]{6,8})',
  );

  static RegExp kRgbColorRegex = RegExp(
    r'(?<!-)color:\s?rgb\((\d+), (\d+), (\d+)\)',
  );

  static RegExp kBackgroundRgbColorRegex = RegExp(
    r'background-color:\s?rgb\((\d+), (\d+), (\d+)\)',
  );

  static RegExp kRgbBackgroundColorRegex = RegExp(
    r'background-color:\s?rgb\((\d+), (\d+), (\d+)\)',
  );

  static RegExp kInlineEmbedRegex = RegExp(
    r'\[@-?\d+:[\u4e00-\u9fa5A-Za-z0-9() _-]*?\]|\[:.+?\]|\[#.+?#\]|\[%.+?%\]',
  );

  static RegExp? kLinkRegex = RegExp(
    r"((?:(http|https|Http|Https|rtsp|Rtsp):\/\/(?:(?:[a-zA-Z0-9\$\-\_\.\+\!\*\'\(\)\,\;\?\&\=]|(?:\%[a-fA-F0-9]{2})){1,64}(?:\:(?:[a-zA-Z0-9\$\-\_\.\+\!\*\'\(\)\,\;\?\&\=]|(?:\%[a-fA-F0-9]{2})){1,25})?\@)?)?((?:(?:[a-zA-Z0-9][a-zA-Z0-9\-]{0,64}\.)+(?:(?:aero|arpa|asia|a[cdefgilmnoqrstuwxz])|(?:biz|b[abdefghijmnorstvwyz])|(?:cat|com|coop|c[acdfghiklmnoruvxyz])|d[ejkmoz]|(?:edu|e[cegrstu])|f[ijkmor]|(?:gov|g[abdefghilmnpqrstuwy])|h[kmnrtu]|(?:info|int|i[delmnoqrst])|(?:jobs|j[emop])|k[eghimnrwyz]|l[abcikrstuvy]|(?:mil|mobi|museum|m[acdghklmnopqrstuvwxyz])|(?:name|net|n[acefgilopruz])|(?:org|om)|(?:pro|p[aefghklmnrstwy])|qa|r[eouw]|s[abcdeghijklmnortuvyz]|(?:tel|travel|t[cdfghjklmnoprtvwz])|u[agkmsyz]|v[aceginu]|w[fs]|y[etu]|z[amw]))|(?:(?:25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9])\.(?:25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9]|0)\.(?:25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9]|0)\.(?:25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[0-9])))(?:\:\d{1,5})?)(\/(?:(?:[a-zA-Z0-9\;\/\?\:\@\&\=\#\~\-\.\+\!\*\'\(\)\,\_])|(?:\%[a-fA-F0-9]{2}))*)?(?:\b|$)",
  );

  static String Function(String value)? convertTextNodeToHtml;
  static String Function(String value)? convertHtmlToTextNode;
}
