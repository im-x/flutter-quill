import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../../utils/quill_data.dart';

/// An object which can be embedded into a Quill document.
///
/// See also:
///
/// * [BlockEmbed] which represents a block embed.
class Embeddable {
  const Embeddable(this.type, this.data);

  /// The type of this object.
  final String type;

  /// The data payload of this object.
  final dynamic data;

  Map<String, dynamic> toJson() {
    return {'type': runtimeType.toString(), type: data};
  }

  static Embeddable fromJson(Map<String, dynamic> json) {
    assert(json.length == 2, 'Embeddable map need two key');

    if (json['type'] == 'BlockEmbed') {
      return BlockEmbed(json.keys.last, json.values.last);
    } else if (json['type'] == 'InlineEmbed') {
      return InlineEmbed(json.keys.last, json.values.last);
    }
    throw ArgumentError('Not Support Argument ${json.toString()}');
  }
}

/// An object which occupies an entire line in a document and cannot co-exist
/// inline with regular text.
///
/// There are two built-in embed types supported by Quill documents, however
/// the document model itself does not make any assumptions about the types
/// of embedded objects and allows users to define their own types.
class BlockEmbed extends Embeddable {
  const BlockEmbed(String type, String data) : super(type, data);

  static const String horizontalRuleType = 'divider';
  static BlockEmbed horizontalRule = const BlockEmbed(horizontalRuleType, 'hr');

  static const String imageType = 'image';
  static BlockEmbed image(String imageUrl) => BlockEmbed(imageType, imageUrl);
}

class InlineEmbed extends Embeddable {
  InlineEmbed(String type, Object data) : super(type, data);

  static const emojiName = 'emoji';
  static InlineEmbed emoji(String name) => InlineEmbed(emojiName, name);

  static const mentionName = 'mention';
  static InlineEmbed mention(Map<int, String> info) =>
      InlineEmbed(mentionName, info);

  Widget getEmbedWidget() {
    return QuillData.getInlineEmbedWidget?.call(this) ??
        const SizedBox.shrink();
  }

  bool onTap() {
    return QuillData.onInlineEmbedTap?.call(this) == true;
  }
}
