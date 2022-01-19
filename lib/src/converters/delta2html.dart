// ignore_for_file: prefer_single_quotes

import 'dart:collection';
import 'dart:convert';

import 'package:quiver/strings.dart';
import '../../flutter_quill.dart';
import '../../models/documents/nodes/block.dart';
import '../../models/documents/nodes/node.dart';
import '../../models/documents/style.dart';
import '../models/documents/nodes/line.dart';

/// Delta -> HTML
class Delta2HtmlEncoder extends Converter<Delta, String> {
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
        '$node is not supported by DeltaHtmlEncoder._parseNode',
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
    var tag = '';
    if (isHeading) {
      tag = _getHeadingTag(node.style);
    } else if (isList) {
      tag = kListItem;
    } else {
      tag = kParagraph;
      // throw UnsupportedError('Unsupported LineNode style: ${node.style}');
    }

    var indent = 0;
    if (node.style.attributes.containsKey('indent')) {
      indent = (node.style.attributes['indent']?.value ?? 0) as int;
    }

    if (isNewLine) {
      _writeTag(kParagraph);
      _writeTag(kLineBreak);
      _writeTag(kParagraph, close: true);
    } else if (node.isNotEmpty) {
      _writeTag(tag, indent: indent);
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
      tag = '';
      // throw UnsupportedError('Unsupported BlockNode: $node');
    }
    if (tag != '') _writeTag(tag);
    node.children.cast<Line>().forEach(_parseLineNode);
    if (tag != '') _writeTag(tag, close: true);
  }

  void _parseLeafNode(Leaf node) {
    final nodes = <Leaf>[];

    if (node is Text && node.style.contains(Attribute.link) == false) {
      final text = node.value;
      final regex = RegExp(
          r'([hH][tT]{2}[pP]://|[hH][tT]{2}[pP][sS]://|[wW]{3}.|[wW][aA][pP].|[fF][tT][pP].|[fF][iI][lL][eE].)[-A-Za-z0-9+&@#/%?=~_|!:,.;]+[-A-Za-z0-9+&@#/%=~_|]');
      final regex2 = RegExp(
          r"((?:(http|https|Http|Https|rtsp|Rtsp):\/\/(?:(?:[a-zA-Z0-9\$\-\_\.\+\!\*\'\(\)\,\;\?\&\=]|(?:\%[a-fA-F0-9]{2})){1,64}(?:\:(?:[a-zA-Z0-9\$\-\_\.\+\!\*\'\(\)\,\;\?\&\=]|(?:\%[a-fA-F0-9]{2})){1,25})?\@)?)?((?:(?:[a-zA-Z0-9][a-zA-Z0-9\-]{0,64}\.)+(?:(?:aero|arpa|asia|a[cdefgilmnoqrstuwxz])|(?:biz|b[abdefghijmnorstvwyz])|(?:cat|com|coop|c[acdfghiklmnoruvxyz])|d[ejkmoz]|(?:edu|e[cegrstu])|f[ijkmor]|(?:gov|g[abdefghilmnpqrstuwy])|h[kmnrtu]|(?:info|int|i[delmnoqrst])|(?:jobs|j[emop])|k[eghimnrwyz]|l[abcikrstuvy]|(?:mil|mobi|museum|m[acdghklmnopqrstuvwxyz])|(?:name|net|n[acefgilopruz])|(?:org|om)|(?:pro|p[aefghklmnrstwy])|qa|r[eouw]|s[abcdeghijklmnortuvyz]|(?:tel|travel|t[cdfghjklmnoprtvwz])|u[agkmsyz]|v[aceginu]|w[fs]|y[etu]|z[amw]))|(?:(?:25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9])\.(?:25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9]|0)\.(?:25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[1-9]|0)\.(?:25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[1-9][0-9]|[0-9])))(?:\:\d{1,5})?)(\/(?:(?:[a-zA-Z0-9\;\/\?\:\@\&\=\#\~\-\.\+\!\*\'\(\)\,\_])|(?:\%[a-fA-F0-9]{2}))*)?(?:\b|$)");

      final matches = regex2.allMatches(text);
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
            indexes
              ..add(m.start)
              ..add(m.end);
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
          } else if (inline.type == InlineEmbed.topicName) {
            htmlBuffer!.write('[#${(node.value as InlineEmbed).data}#]');
          }
        }
      } else {
        throw 'Unsupported LeafNode';
      }
    }
  }

  void _writeTag(String tag,
      {Map<String, String>? styles, int indent = 0, bool close = false}) {
    if (close ||
        styles == null ||
        styles.isEmpty ||
        styles.containsKey(tag) == false) {
      if (indent != 0) {
        htmlBuffer!
            .write(close ? '</$tag>' : '<$tag class="ql-indent-$indent">');
      } else {
        htmlBuffer!.write(close ? '</$tag>' : '<$tag>');
      }
    } else {
      if (tag == kSpan && styles.containsKey(kSpan)) {
        final str = styles[kSpan];
        if (indent != 0) {
          htmlBuffer!.write('<$tag style="$str" class="ql-indent-$indent">');
        } else {
          htmlBuffer!.write('<$tag style="$str">');
        }
      } else if (tag == kLink && styles.containsKey(kLink)) {
        final str = styles[kLink];
        if (indent != 0) {
          htmlBuffer!.write(
              '<$tag href="$str" target="_blank" class="ql-indent-$indent">');
        } else {
          htmlBuffer!.write('<$tag href="$str" target="_blank">');
        }
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
