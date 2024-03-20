import 'dart:convert' show jsonDecode, jsonEncode;

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
    return {type: data};
  }

  static Embeddable fromJson(Map<String, dynamic> json) {
    final m = Map<String, dynamic>.from(json);
    assert(m.length == 1, 'Embeddable map must only have one key');
    final key = m.keys.first;
    final value = m.values.first;

    if (InlineEmbed.isInlineEmbed(key)) {
      return InlineEmbed(key, value);
    }
    return Embeddable(key, value);
  }
}

/// There are two built-in embed types supported by Quill documents, however
/// the document model itself does not make any assumptions about the types
/// of embedded objects and allows users to define their own types.
class BlockEmbed extends Embeddable {
  const BlockEmbed(super.type, String super.data);

  static const String imageType = 'image';
  static BlockEmbed image(String imageUrl) => BlockEmbed(imageType, imageUrl);

  static const String videoType = 'video';
  static BlockEmbed video(String videoUrl) => BlockEmbed(videoType, videoUrl);

  static const String formulaType = 'formula';
  static BlockEmbed formula(String formula) => BlockEmbed(formulaType, formula);

  static const String customType = 'custom';
  static BlockEmbed custom(CustomBlockEmbed customBlock) =>
      BlockEmbed(customType, customBlock.toJsonString());
}

class CustomBlockEmbed extends BlockEmbed {
  const CustomBlockEmbed(super.type, super.data);

  String toJsonString() => jsonEncode(toJson());

  static CustomBlockEmbed fromJsonString(String data) {
    final embeddable = Embeddable.fromJson(jsonDecode(data));
    return CustomBlockEmbed(embeddable.type, embeddable.data);
  }
}

class InlineEmbed extends Embeddable {
  InlineEmbed(super.type, Object super.data);

  static bool isInlineEmbed(String key) {
    if (key == emojiName ||
        key == mentionName ||
        key == topicName ||
        key == editName ||
        key == containerTextName) {
      return true;
    }
    return false;
  }

  static const emojiName = 'emoji';
  static InlineEmbed emoji(String name) => InlineEmbed(emojiName, name);

  static const mentionName = 'mention';
  static InlineEmbed mention(Map<int, String> info) =>
      InlineEmbed(mentionName, info);

  static const topicName = 'topic';
  static InlineEmbed topic(String name) => InlineEmbed(topicName, name);
  static String getTopicHtml(String name) => '<p>[#$name#]</p>';

  static const editName = 'edited';
  static InlineEmbed edit(String name) => InlineEmbed(editName, name);
  static String getEditHtml(String name) => '[%$name%]';

  static const containerTextName = 'container_text';
  static InlineEmbed containerText(String className, String text) =>
      InlineEmbed(containerTextName, {'class': className, 'text': text});

  @override
  String toString() {
    if (type == emojiName) {
      return '[:${data.toString()}]';
    } else if (type == mentionName) {
      try {
        final map = data as Map<int, String>;
        final userID = map.keys.first;
        final displayName = QuillData.getUserDisplayName?.call(userID);
        var name = map.values.first;
        if (displayName != null && displayName.isNotEmpty) {
          name = displayName;
        }
        return '@$name';
      } catch (e) {
        return '@未知用户';
      }
    } else if (type == topicName) {
      return '#${data.toString()}#';
    }
    return '';
  }
}
