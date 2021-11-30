import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';
import 'package:quiver/strings.dart';
import '../../flutter_quill.dart';

/// HTML -> Delta
class Html2DeltaDecoder extends Converter<String, Delta> {
  @override
  Delta convert(String input) {
    var delta = Delta();
    final html = parse(input);

    html.body!.nodes
      ..removeWhere(
        (htmlNode) =>
            htmlNode is dom.Element &&
            htmlNode.localName == 'p' &&
            htmlNode.nodes.isEmpty,
      )
      ..forEach((htmlNode) => delta = _parseNode(htmlNode, delta));

    if (delta.isEmpty ||
        !(delta.last.data is String &&
            (delta.last.data as String).endsWith('\n'))) {
      delta = _appendNewLine(delta);
    }
    print(delta);
    return delta;
  }

  Delta _appendNewLine(Delta delta) {
    final operations = delta.toList();
    if (operations.isNotEmpty && operations.last.data is! Embeddable) {
      final lastOperation = operations.removeLast();
      operations.add(
        Operation.insert('${lastOperation.data}\n', lastOperation.attributes),
      );
      delta = Delta();
      operations.forEach(delta.push);
    } else {
      return delta..insert('\n');
    }
    return delta;
  }

  Delta _parseNode(
    dom.Node htmlNode,
    Delta delta, {
    bool? inList,
    Map<String, dynamic>? parentAttributes,
    Map<String, dynamic>? parentBlockAttributes,
  }) {
    final attributes = parentAttributes ?? <String, dynamic>{};
    final blockAttributes = parentBlockAttributes ?? <String, dynamic>{};

    if (htmlNode is dom.Element) {
      // The html node is an element
      final element = htmlNode;
      final elementName = htmlNode.localName;
      if (elementName == 'ul') {
        // Unordered list
        element.children.forEach((child) {
          delta = _parseElement(
            child,
            delta,
            listType: 'ul',
            inList: inList,
            parentAttributes: attributes,
            parentBlockAttributes: blockAttributes,
          );
        });
        return delta;
      } else if (elementName == 'ol') {
        // Ordered list
        element.children.forEach((child) {
          delta = _parseElement(
            child,
            delta,
            listType: 'ol',
            inList: inList,
            parentAttributes: attributes,
            parentBlockAttributes: blockAttributes,
          );
        });
        return delta;
      } else if (elementName == 'p') {
        // Paragraph
        final nodes = element.nodes;

        // TODO find a simpler way to express this
        if (nodes.length == 1 &&
            nodes.first is dom.Element &&
            (nodes.first as dom.Element).localName == 'br') {
          // The p tag looks like <p><br></p> so we should treat it as a blank
          // line
          return delta..insert('\n');
        } else {
          for (var i = 0; i < nodes.length; i++) {
            final currentNode = nodes[i];
            delta = _parseNode(
              currentNode,
              delta,
              parentAttributes: attributes,
              parentBlockAttributes: blockAttributes,
            );

            if (element.className != '' &&
                element.className.startsWith('ql-indent-')) {
              final indent =
                  int.parse(element.className.replaceAll('ql-indent-', ''));
              delta.insert('\n', {'indent': indent});
            }
          }
          if (delta.isEmpty ||
              !(delta.last.data is String &&
                  (delta.last.data as String).endsWith('\n'))) {
            delta = _appendNewLine(delta);
          }
          return delta;
        }
      } else if (elementName == 'br') {
        return delta..insert('\n');
      } else if (_supportedHTMLElements[elementName] == null) {
        // Not a supported element
        return delta;
      } else {
        // A supported element that isn't an ordered or unordered list
        delta = _parseElement(
          element,
          delta,
          inList: inList,
          parentAttributes: attributes,
          parentBlockAttributes: blockAttributes,
        );
        return delta;
      }
    } else if (htmlNode is dom.Text) {
      // The html node is text
      final text = htmlNode;
      _insertText(
        delta,
        text.text,
        attributes: attributes,
      );
      return delta;
    } else {
      // The html node isn't an element or text e.g. if it's a comment
      return delta;
    }
  }

  void _insertText(Delta delta, String text,
      {Map<String, dynamic>? attributes}) {
    final texts = <String>[];

    final reg = RegExp(r'\[@-?\d+:.+?\]|\[:.+?\]|\[#.+?#\]');
    final matches = reg.allMatches(text);
    if (matches.isNotEmpty) {
      splitTextByMatches(text, matches, texts);
    } else {
      texts.addAll(text.split('\n'));
    }

    for (var i = 0; i < texts.length; i++) {
      final item = texts[i];
      if (isEmpty(item)) continue;
      if (item.length > 3) {
        if (item.startsWith('[@') && item.endsWith(']')) {
          final splitStrings = item.substring(2, item.length - 1).split(':');
          final userID = int.tryParse(splitStrings[0]);
          final userName = splitStrings[1];
          delta.insert(InlineEmbed.mention({userID!: userName}));
          continue;
        } else if (item.startsWith('[:') && item.endsWith(']')) {
          final emojiName = item.substring(2, item.length - 1);
          delta.insert(InlineEmbed.emoji(emojiName));
          continue;
        } else if (item.startsWith('[#') && item.endsWith('#]')) {
          final topicName = item.substring(2, item.length - 2);
          delta.insert(InlineEmbed.topic(topicName));
          continue;
        }
      }
      delta.insert(item, attributes);
    }
  }

  void splitTextByMatches(
      String text, Iterable<RegExpMatch> atMatches, List<String> texts) {
    final indexes = <int>[0];
    atMatches.forEach((m) => indexes
      ..add(m.start)
      ..add(m.end));
    indexes.add(text.length);

    for (var i = 0; i <= indexes.length - 2; i++) {
      final childText = text.substring(indexes[i], indexes[i + 1]);
      if (isNotBlank(childText)) {
        final childList = childText.split('\n');
        for (var j = 0; j < childList.length; ++j) {
          var item = childList[j];
          if (j > 0) item += '\n';
          texts.add(item);
        }
      }
    }
  }

  Delta _parseElement(
    dom.Element element,
    Delta delta, {
    required bool? inList,
    Map<String, dynamic>? parentAttributes,
    Map<String, dynamic>? parentBlockAttributes,
    String? listType,
  }) {
    final type = _supportedHTMLElements[element.localName];
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

      if (element.className != '' &&
          element.className.startsWith('ql-indent-')) {
        int indent = int.parse(element.className.replaceAll('ql-indent-', ''));
        blockAttributes[Attribute.indent.key] = indent;
      }

      element.nodes.forEach((node) {
        delta = _parseNode(
          node,
          delta,
          inList: element.localName == 'li',
          parentAttributes: attributes,
          parentBlockAttributes: blockAttributes,
        );
      });
      if (blockAttributes.isNotEmpty) {
        delta.insert('\n', blockAttributes);
      }
      return delta;
    } else if (type == _HtmlType.EMBED) {
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
        if (style != null) {
          final regex = RegExp(r'color:\s?(#[0-9a-fA-F]{6,8})');
          final regex1 = RegExp(r'color:\s?rgb\((\d+), (\d+), (\d+)\)');
          if (regex.hasMatch(style)) {
            final matches = regex.allMatches(style);
            if (matches.isNotEmpty) {
              final match = matches.first;
              if (match.groupCount == 1) {
                attributes[Attribute.color.key] = match.group(1);
              }
            }
          } else if (regex1.hasMatch(style)) {
            final matches = regex1.allMatches(style);
            if (matches.isNotEmpty) {
              final match = matches.first;
              if (match.groupCount == 3) {
                attributes[Attribute.color.key] = '#'
                    // ignore: lines_longer_than_80_chars
                    '${int.tryParse(match.group(1)!)!.toRadixString(16).padLeft(2, '0')}'
                    // ignore: lines_longer_than_80_chars
                    '${int.tryParse(match.group(2)!)!.toRadixString(16).padLeft(2, '0')}'
                    // ignore: lines_longer_than_80_chars
                    '${int.tryParse(match.group(3)!)!.toRadixString(16).padLeft(2, '0')}';
              }
            }
          }
        }
      }
      if (element.children.isEmpty) {
        // The element has no child elements i.e. this is the leaf element
        _insertText(
          delta,
          element.text,
          attributes: attributes,
        );
        if (attributes['a'] != null) {
          // It's a link
          if (inList == null || !inList) {
            delta.insert('\n');
          }
        }
      } else {
        // The element has child elements(subclass of node) and potentially
        // text(subclass of node)
        element.nodes.forEach(
          (node) {
            delta = _parseNode(
              node,
              delta,
              parentAttributes: attributes,
            );
          },
        );
      }
      return delta;
    }
  }

  final Map<String, _HtmlType> _supportedHTMLElements = {
    'hr': _HtmlType.EMBED,
    'li': _HtmlType.BLOCK,
    'h1': _HtmlType.BLOCK,
    'h2': _HtmlType.BLOCK,
    'h3': _HtmlType.BLOCK,
    'pre': _HtmlType.BLOCK,
    'div': _HtmlType.BLOCK,
    'img': _HtmlType.EMBED,
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
}

enum _HtmlType { BLOCK, INLINE, EMBED }
