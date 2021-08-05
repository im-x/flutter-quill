import 'dart:collection';
import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';
import 'package:quiver/strings.dart';

import '../models/documents/attribute.dart';
import '../models/documents/document.dart';
import '../models/documents/nodes/block.dart';
import '../models/documents/nodes/embed.dart';
import '../models/documents/nodes/leaf.dart';
import '../models/documents/nodes/line.dart';
import '../models/documents/nodes/node.dart';
import '../models/documents/style.dart';
import '../models/quill_delta.dart';

const DeltaHtmlCodec html = DeltaHtmlCodec();

String htmlEncode(Delta delta) {
  return html.encode(delta);
}

Delta htmlDecode(String source) {
  return html.decode(source);
}

class DeltaHtmlCodec extends Codec<Delta, String> {
  const DeltaHtmlCodec();

  @override
  Converter<String, Delta> get decoder => _DeltaHtmlDecoder();

  @override
  Converter<Delta, String> get encoder => _DeltaHtmlEncoder();
}

/// Delta -> HTML
class _DeltaHtmlEncoder extends Converter<Delta, String> {
  static const kLink = 'a';
  static const kBold = 'strong';
  static const kItalic = 'em';
  static const kSpan = 'span';
  static const kParagraph = 'p';
  static const kLineBreak = 'br';
  static const kHeading1 = 'h1';
  static const kHeading2 = 'h2';
  static const kHeading3 = 'h3';
  static const kListItem = 'li';
  static const kUnorderedList = 'ul';
  static const kOrderedList = 'ol';
  static const kCode = 'code';
  static const kQuote = 'blockquote';
  static const kStrike = 's';

  StringBuffer? htmlBuffer;

  @override
  String convert(Delta input) {
    htmlBuffer = StringBuffer();
    try {
      Document.fromDelta(input).root.children.forEach(_parseNode);
    } catch (e) {
      rethrow;
    }

    return htmlBuffer!.toString();
  }

  void _parseNode(Node node) {
    if (node is Line) {
      _parseLineNode(node);
    } else if (node is Block) {
      _parseBlockNode(node);
    } else {
      throw UnsupportedError(
        '$node is not supported by _DeltaHtmlEncoder._parseNode',
      );
    }
  }

  /// Assumes that the style contains a heading
  String _getHeadingTag(Style style) {
    final level = style.value<int?>(Attribute.header);
    switch (level) {
      case 1:
        return kHeading1;
      case 2:
        return kHeading2;
      case 3:
        return kHeading3;
      default:
        throw UnsupportedError(
          'Unsupported heading level: $level, does your style contain a heading'
          ' attribute?',
        );
    }
  }

  void _parseLineNode(Line node) {
    final isHeading = node.style.contains(Attribute.header);
    final isList = node.style.containsSame(Attribute.ul) ||
        node.style.containsSame(Attribute.ol);
    final isNewLine = node.isEmpty && node.style.isEmpty && node.next != null;

    // Opening heading/paragraph tag
    String tag;
    if (isHeading) {
      tag = _getHeadingTag(node.style);
    } else if (isList) {
      tag = kListItem;
    } else {
      tag = kParagraph;
      // throw UnsupportedError('Unsupported LineNode style: ${node.style}');
    }

    if (isNewLine) {
      _writeTag(kParagraph);
      _writeTag(kLineBreak);
      _writeTag(kParagraph, close: true);
    } else if (node.isNotEmpty) {
      _writeTag(tag);
      node.children.cast<Leaf>().forEach(_parseLeafNode);
      _writeTag(tag, close: true);
    }
  }

  void _parseBlockNode(Block node) {
    String tag;
    if (node.style.containsSame(Attribute.ul)) {
      tag = kUnorderedList;
    } else if (node.style.containsSame(Attribute.ol)) {
      tag = kOrderedList;
    } else if (node.style.containsSame(Attribute.codeBlock)) {
      tag = kCode;
    } else if (node.style.containsSame(Attribute.blockQuote)) {
      tag = kQuote;
    } else {
      throw UnsupportedError('Unsupported BlockNode: $node');
    }
    _writeTag(tag);
    node.children.cast<Line>().forEach(_parseLineNode);
    _writeTag(tag, close: true);
  }

  void _parseLeafNode(Leaf node) {
    final nodes = <Leaf>[];

    if (node is Text && node.style.contains(Attribute.link) == false) {
      final text = node.value;
      final regex = RegExp(
          r'([hH][tT]{2}[pP]://|[hH][tT]{2}[pP][sS]://|[wW]{3}.|[wW][aA][pP].|[fF][tT][pP].|[fF][iI][lL][eE].)[-A-Za-z0-9+&@#/%?=~_|!:,.;]+[-A-Za-z0-9+&@#/%=~_|]');

      final matches = regex.allMatches(text);
      if (matches.isNotEmpty) {
        final indexes = <int>[0];
        final matchStarts = HashSet();

        if (matches.length == 1) {
          final m = matches.first;
          if (m.start == 0 && m.end == text.length) {
            if (!node.style.attributes.containsKey(Attribute.link.key)) {
              node.style.attributes[Attribute.link.key] =
                  LinkAttribute(node.value);
            }
            nodes.add(node);
          }
        }

        if (nodes.isEmpty) {
          matches.forEach((m) {
            matchStarts.add(m.start);
            indexes..add(m.start)..add(m.end);
          });
          indexes.add(text.length);

          for (var i = 0; i <= indexes.length - 2; i++) {
            final startIndex = indexes[i];
            final nextIndex = indexes[i + 1];

            var childText = text.substring(startIndex, nextIndex);
            if (isNotBlank(childText)) {
              if (matchStarts.contains(nextIndex)) {
                childText += ' ';
              }

              final leaf = Text(childText)..applyStyle(node.style);
              if (matchStarts.contains(startIndex)) {
                leaf.style.attributes[Attribute.link.key] =
                    LinkAttribute(childText);
              }
              nodes.add(leaf);
            }
          }
        }
      }
    }

    if (nodes.isEmpty) {
      nodes.add(node);
    }

    for (final node in nodes) {
      //attribute
      bool isLink(Leaf leaf) => leaf.style.contains(Attribute.link);
      bool isBold(Leaf leaf) => leaf.style.containsSame(Attribute.bold);
      bool isItalic(Leaf leaf) => leaf.style.containsSame(Attribute.italic);
      bool isStrike(Leaf leaf) =>
          leaf.style.containsSame(Attribute.strikeThrough);

      //css style
      bool isColor(Leaf leaf) => leaf.style.contains(Attribute.color);

      if (node is Text) {
        // Open styles
        final tagsToOpen = <String>[];
        final tagsToOpenStyle = <String, String>{};
        if (isBold(node)) {
          tagsToOpen.add(kBold);
        }
        if (isItalic(node)) {
          tagsToOpen.add(kItalic);
        }
        if (isStrike(node)) {
          tagsToOpen.add(kStrike);
        }
        if (isColor(node)) {
          tagsToOpen.add(kSpan);
          tagsToOpenStyle[kSpan] =
              'color:${node.style.value<String?>(Attribute.color)}';
        }
        if (isLink(node)) {
          tagsToOpen.add(kLink);
          tagsToOpenStyle[kLink] = node.style.value<String?>(Attribute.link)!;
        }

        if (tagsToOpen.isNotEmpty) {
          _writeTagsOrdered(tagsToOpen, styles: tagsToOpenStyle);
        }

        // Write the content
        htmlBuffer!.write(node.value);

        if (tagsToOpen.isNotEmpty) {
          _writeTagsOrdered(tagsToOpen.reversed, close: true);
        }
      } else if (node is Embed) {
        bool isEmbed(Leaf node) => node.value is InlineEmbed;
        if (isEmbed(node)) {
          final inline = node.value as InlineEmbed;
          if (inline.type == InlineEmbed.emojiName) {
            htmlBuffer!.write('[:${(node.value as InlineEmbed).data}]');
          } else if (inline.type == InlineEmbed.mentionName) {
            if (inline.data is Map<int, String>) {
              final map = inline.data as Map<int, String>;
              if (map.isNotEmpty) {
                htmlBuffer!.write('[@${map.keys.last}:${map.values.last}]');
              }
            }
          }
        }
      } else {
        throw 'Unsupported LeafNode';
      }
    }
  }

  void _writeTag(String tag,
      {Map<String, String>? styles, bool close = false}) {
    if (close ||
        styles == null ||
        styles.isEmpty ||
        styles.containsKey(tag) == false) {
      htmlBuffer!.write(close ? '</$tag>' : '<$tag>');
    } else {
      if (tag == kSpan && styles.containsKey(kSpan)) {
        final str = styles[kSpan];
        htmlBuffer!.write('<$tag style="$str">');
      } else if (tag == kLink && styles.containsKey(kLink)) {
        final str = styles[kLink];
        htmlBuffer!.write('<$tag href="$str">');
      }
    }
  }

  void _writeTagsOrdered(Iterable<String> tags,
      {Map<String, String>? styles, bool close = false}) {
    tags.forEach((tag) {
      _writeTag(tag, styles: styles, close: close);
    });
  }
}

/// HTML -> Delta
class _DeltaHtmlDecoder extends Converter<String, Delta> {
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
    final attributes = parentAttributes ?? Map<String, dynamic>();
    final blockAttributes = parentBlockAttributes ?? Map<String, dynamic>();

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
            delta = _parseNode(
              nodes[i],
              delta,
              parentAttributes: attributes,
              parentBlockAttributes: blockAttributes,
            );
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

    final reg = RegExp(r'\[@\d+:.+?\]|\[:.+?\]');
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
        }
      }
      delta.insert(item, attributes);
    }
  }

  void splitTextByMatches(
      String text, Iterable<RegExpMatch> atMatches, List<String> texts) {
    final indexes = <int>[0];
    atMatches.forEach((m) => indexes..add(m.start)..add(m.end));
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
    final attributes = parentAttributes ?? Map<String, dynamic>();
    final blockAttributes = parentBlockAttributes ?? Map<String, dynamic>();

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
      element.nodes.forEach((node) {
        delta = _parseNode(
          node,
          delta,
          inList: element.localName == 'li',
          parentAttributes: attributes,
          parentBlockAttributes: blockAttributes,
        );
      });
      if (!blockAttributes.isEmpty) {
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
