import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as parser;
import 'package:quiver/strings.dart';
import '../../flutter_quill.dart';

enum _HtmlType {
  BLOCK,
  INLINE,
  EMBED,
}

final Map<String, _HtmlType> _kSupportedHTMLElements = {
  'hr': _HtmlType.EMBED,
  'img': _HtmlType.EMBED,

  'li': _HtmlType.BLOCK,
  'h1': _HtmlType.BLOCK,
  'h2': _HtmlType.BLOCK,
  'h3': _HtmlType.BLOCK,
  'pre': _HtmlType.BLOCK,
  'div': _HtmlType.BLOCK,
  'code': _HtmlType.BLOCK,
  'blockquote': _HtmlType.BLOCK,

  'i': _HtmlType.INLINE, // Italic
  'em': _HtmlType.INLINE,
  'b': _HtmlType.INLINE, // Bold,
  'strong': _HtmlType.INLINE,
  'a': _HtmlType.INLINE,
  'p': _HtmlType.INLINE,
  'span': _HtmlType.INLINE,
  's': _HtmlType.INLINE,
};

/// HTML -> Delta
class Html2DeltaDecoder extends Converter<String, Delta> {
  @override
  Delta convert(String input) {
    var delta = Delta();

    final html = parser.parse(input);
    final body = html.body;
    if (body == null) {
      return delta;
    }

    final nodes = body.nodes..removeWhere(isEmptyNode);
    for (final htmlNode in nodes) {
      delta = _parseNode(
        htmlNode: htmlNode,
        delta: delta,
      );
    }

    if (_checkNeedNewLine(delta)) {
      delta = _appendNewLine(delta);
    }

    return delta;
  }

  bool _checkNeedNewLine(Delta delta) {
    if (delta.isEmpty) {
      return true;
    }

    final lastData = delta.last.data;
    if (!(lastData is String && lastData.endsWith('\n'))) {
      return true;
    }

    return false;
  }

  bool isEmptyNode(dom.Node htmlNode) {
    if (htmlNode is! dom.Element) return false;
    if (htmlNode.localName != 'p') return false;
    if (htmlNode.nodes.isNotEmpty) return false;
    return true;
  }

  Delta _appendNewLine(Delta delta) {
    final operations = delta.toList();

    if (operations.isNotEmpty && operations.last.data is! Embeddable) {
      final lastOp = operations.removeLast();
      operations.add(Operation.insert('${lastOp.data}\n', lastOp.attributes));
      delta = Delta();
      operations.forEach(delta.push);
    } else {
      return delta..insert('\n');
    }

    return delta;
  }

  Delta _parseNode({
    required dom.Node htmlNode,
    required Delta delta,
    bool? inList,
    Map<String, dynamic>? parentAttributes,
    Map<String, dynamic>? parentBlockAttributes,
  }) {
    if (htmlNode is dom.Element) {
      final element = htmlNode;
      final elementName = htmlNode.localName;
      if (elementName == 'ul') {
        for (final element in element.children) {
          delta = _parseElement(
            element: element,
            delta: delta,
            listType: 'ul',
            inList: inList,
            parentAttributes: parentAttributes,
            parentBlockAttributes: parentBlockAttributes,
          );
        }
        return delta;
      } else if (elementName == 'ol') {
        for (final element in element.children) {
          delta = _parseElement(
            element: element,
            delta: delta,
            listType: 'ol',
            inList: inList,
            parentAttributes: parentAttributes,
            parentBlockAttributes: parentBlockAttributes,
          );
        }
        return delta;
      } else if (elementName == 'p') {
        final nodes = element.nodes;

        if (nodes.length == 1 &&
            nodes.first is dom.Element &&
            (nodes.first as dom.Element).localName == 'br') {
          return delta..insert('\n');
        } else {
          for (var i = 0; i < nodes.length; i++) {
            final currentNode = nodes[i];
            delta = _parseNode(
              htmlNode: currentNode,
              delta: delta,
              inList: inList,
              parentAttributes: parentAttributes,
              parentBlockAttributes: parentBlockAttributes,
            );

            final indent = _getIndent(element.className);
            if (indent > 0) {
              delta.insert('\n', {'indent': indent});
            }
          }

          if (_checkNeedNewLine(delta)) {
            delta = _appendNewLine(delta);
          }
          return delta;
        }
      } else if (elementName == 'br') {
        return delta..insert('\n');
      } else if (_kSupportedHTMLElements[elementName] == null) {
        return delta;
      } else {
        delta = _parseElement(
          element: element,
          delta: delta,
          inList: inList,
          parentAttributes: parentAttributes,
          parentBlockAttributes: parentBlockAttributes,
        );
        return delta;
      }
    } else if (htmlNode is dom.Text) {
      _insertText(
        delta: delta,
        text: htmlNode.text,
        attributes: parentAttributes,
      );
      return delta;
    } else {
      return delta;
    }
  }

  void _insertText({
    required Delta delta,
    required String text,
    Map<String, dynamic>? attributes,
  }) {
    final texts = <String>[];

    final matches = QuillData.kInlineEmbedRegex.allMatches(text);
    if (matches.isNotEmpty) {
      texts.addAll(_splitTextByMatches(text, matches));
    } else {
      texts.addAll(text.split('\n'));
    }

    for (var i = 0; i < texts.length; i++) {
      final item = texts[i];
      if (isEmpty(item)) {
        continue;
      }

      if (item.length > 3) {
        if (item.startsWith('[@') && item.endsWith(']')) {
          final splitStrings = item.substring(2, item.length - 1).split(':');
          try {
            final userID = int.tryParse(splitStrings[0]);
            final userName = splitStrings[1];
            delta.insert(InlineEmbed.mention({userID!: userName}));
          } catch (e) {
            delta.insert(item, attributes);
          }
          continue;
        } else if (item.startsWith('[:') && item.endsWith(']')) {
          final emojiName = item.substring(2, item.length - 1);
          delta.insert(InlineEmbed.emoji(emojiName));
          continue;
        } else if (item.startsWith('[#') && item.endsWith('#]')) {
          final topicName = item.substring(2, item.length - 2);
          delta.insert(InlineEmbed.topic(topicName));
          continue;
        } else if (item.startsWith('[%') && item.endsWith('%]')) {
          final editName = item.substring(2, item.length - 2);
          delta.insert(InlineEmbed.edit(editName));
          continue;
        }
      }
      delta.insert(item, attributes);
    }
  }

  List<String> _splitTextByMatches(
    String text,
    Iterable<RegExpMatch> atMatches,
  ) {
    final texts = <String>[];
    final indexes = <int>[0];
    atMatches.forEach(
      (m) => indexes
        ..add(m.start)
        ..add(m.end),
    );
    indexes.add(text.length);

    for (var i = 0; i <= indexes.length - 2; i++) {
      final childText = text.substring(indexes[i], indexes[i + 1]);
      if (isBlank(childText)) {
        continue;
      }

      final childList = childText.split('\n');
      for (var j = 0; j < childList.length; ++j) {
        var item = childList[j];
        if (j > 0) item += '\n';
        texts.add(item);
      }
    }

    return texts;
  }

  Delta _parseElement({
    required dom.Element element,
    required Delta delta,
    required bool? inList,
    Map<String, dynamic>? parentAttributes,
    Map<String, dynamic>? parentBlockAttributes,
    String? listType,
  }) {
    final type = _kSupportedHTMLElements[element.localName];
    final attributes = parentAttributes ?? <String, dynamic>{};
    final blockAttributes = parentBlockAttributes ?? <String, dynamic>{};

    if (type == _HtmlType.BLOCK) {
      if (element.localName == 'blockquote') {
        blockAttributes[Attribute.blockQuote.key] = Attribute.blockQuote.value;
      } else if (element.localName == 'code' || element.localName == 'pre') {
        blockAttributes[Attribute.codeBlock.key] = Attribute.codeBlock.value;
      } else if (element.localName == 'li') {
        if (listType == 'ol') {
          blockAttributes[Attribute.ol.key] = Attribute.ol.value;
        } else {
          blockAttributes[Attribute.ul.key] = Attribute.ul.value;
        }
      } else if (element.localName == 'h1') {
        blockAttributes[Attribute.h1.key] = Attribute.h1.value;
      } else if (element.localName == 'h2') {
        blockAttributes[Attribute.h2.key] = Attribute.h2.value;
      } else if (element.localName == 'h3') {
        blockAttributes[Attribute.h3.key] = Attribute.h3.value;
      }

      final indent = _getIndent(element.className);
      if (indent > 0) {
        blockAttributes[Attribute.indent.key] = indent;
      }

      for (final node in element.nodes) {
        delta = _parseNode(
          htmlNode: node,
          delta: delta,
          inList: element.localName == 'li',
          parentAttributes: attributes,
          parentBlockAttributes: blockAttributes,
        );
      }

      if (blockAttributes.isNotEmpty) {
        delta.insert('\n', blockAttributes);
      }
      return delta;
    } else if (type == _HtmlType.EMBED) {
      if (element.id == 'undefined' && element.className == 'ql-emoji') {
        return delta;
      }
      if (element.className == 'ql-emoji') {
        return delta;
      }
      // Document document;
      // if (element.localName == 'img') {
      //   /* delta.insert('\n');
      //   document = Document.fromDelta(delta);
      //   final int index = document.length;
      //   document.format(index - 1, 0,
      //       Attribute.embed.image(element.attributes['src'])); */
      // }
      // if (element.localName == 'hr') {
      //   /*  delta.insert('\n');
      //   document = Document.fromDelta(delta);
      //   final int index = document.length;
      //   document.format(index - 1, 0, Attribute.embed.horizontalRule); */
      // }
      // return document.toDelta();
      return Document().toDelta();
    } else {
      if (element.localName == 'em' || element.localName == 'i') {
        attributes[Attribute.italic.key] = Attribute.italic.value;
      }
      if (element.localName == 'strong' || element.localName == 'b') {
        attributes[Attribute.bold.key] = Attribute.bold.value;
      }
      if (element.localName == 'a') {
        attributes[Attribute.link.key] = element.attributes['href'];
      }
      if (element.localName == 's') {
        attributes[Attribute.strikeThrough.key] = Attribute.strikeThrough.value;
      }
      if (element.localName == 'span') {
        final style = element.attributes['style'];
        final color = _getStyleHexColor(style);
        if (color != null) {
          attributes[Attribute.color.key] = color;
        }
      }

      if (element.children.isEmpty) {
        _insertText(
          delta: delta,
          text: element.text,
          attributes: attributes,
        );

        if (attributes[Attribute.link.key] != null) {
          delta.insert(' ');
          attributes.clear();
        }
      } else {
        for (final node in element.nodes) {
          delta = _parseNode(
            htmlNode: node,
            delta: delta,
            parentAttributes: attributes,
          );
        }
      }
      return delta;
    }
  }

  String? _getStyleHexColor(String? style) {
    if (style == null) {
      return null;
    }

    if (QuillData.kHexColorRegex.hasMatch(style)) {
      final matches = QuillData.kHexColorRegex.allMatches(style);
      if (matches.isEmpty) return null;

      final firstMatch = matches.first;
      if (firstMatch.groupCount != 1) return null;

      return firstMatch.group(1);
    }

    if (QuillData.kRgbColorRegex.hasMatch(style)) {
      final matches = QuillData.kRgbColorRegex.allMatches(style);
      if (matches.isEmpty) return null;

      final match = matches.first;
      if (match.groupCount != 3) return null;

      try {
        final color = '#'
            '${getHex(match.group(1)!)}'
            '${getHex(match.group(2)!)}'
            '${getHex(match.group(3)!)}';
        return color;
      } catch (e) {}
    }

    return null;
  }

  String getHex(String number) {
    try {
      return int.tryParse(number)!.toRadixString(16).padLeft(2, '0');
    } catch (e) {
      return '00';
    }
  }

  int _getIndent(String className) {
    if (className.isEmpty || !className.startsWith('ql-indent-')) {
      return 0;
    }
    try {
      if (className.contains(' ')) {
        className = className.split(' ')[0];
      }
      return int.parse(className.replaceAll('ql-indent-', ''));
      // ignore: empty_catches
    } catch (e) {}
    return 0;
  }
}
