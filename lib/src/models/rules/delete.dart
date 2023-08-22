import '../documents/attribute.dart';
import '../documents/nodes/embeddable.dart';
import '../quill_delta.dart';
import 'rule.dart';

/// A heuristic rule for delete operations.
abstract class DeleteRule extends Rule {
  const DeleteRule();

  @override
  RuleType get type => RuleType.DELETE;

  @override
  void validateArgs(int? len, Object? data, Attribute? attribute) {
    assert(len != null);
    assert(data == null);
    assert(attribute == null);
  }
}

class EnsureLastLineBreakDeleteRule extends DeleteRule {
  const EnsureLastLineBreakDeleteRule();

  @override
  Delta? applyRule(Delta document, int index,
      {int? len, Object? data, Attribute? attribute}) {
    final itr = DeltaIterator(document)..skip(index + len!);

    return Delta()
      ..retain(index)
      ..delete(itr.hasNext ? len : len - 1);
  }
}

/// Fallback rule for delete operations which simply deletes specified text
/// range without any special handling.
class CatchAllDeleteRule extends DeleteRule {
  const CatchAllDeleteRule();

  @override
  Delta applyRule(Delta document, int index,
      {int? len, Object? data, Attribute? attribute}) {
    final itr = DeltaIterator(document)..skip(index + len!);

    return Delta()
      ..retain(index)
      ..delete(itr.hasNext ? len : len - 1);
  }
}

/// Preserves line format when user deletes the line's newline character
/// effectively merging it with the next line.
///
/// This rule makes sure to apply all style attributes of deleted newline
/// to the next available newline, which may reset any style attributes
/// already present there.
class PreserveLineStyleOnMergeRule extends DeleteRule {
  const PreserveLineStyleOnMergeRule();

  @override
  Delta? applyRule(Delta document, int index,
      {int? len, Object? data, Attribute? attribute}) {
    final itr = DeltaIterator(document)..skip(index);
    var op = itr.next(1);
    if (op.data != '\n') {
      return null;
    }

    final isNotPlain = op.isNotPlain;
    final attrs = op.attributes;

    itr.skip(len! - 1);

    if (!itr.hasNext) {
      // User attempts to delete the last newline character, prevent it.
      return Delta()
        ..retain(index)
        ..delete(len - 1);
    }

    final delta = Delta()
      ..retain(index)
      ..delete(len);

    while (itr.hasNext) {
      op = itr.next();
      final text = op.data is String ? (op.data as String?)! : '';
      final lineBreak = text.indexOf('\n');
      if (lineBreak == -1) {
        delta.retain(op.length!);
        continue;
      }

      var attributes = op.attributes == null
          ? null
          : op.attributes!.map<String, dynamic>(
              (key, dynamic value) => MapEntry<String, dynamic>(key, null));

      if (isNotPlain) {
        attributes ??= <String, dynamic>{};
        attributes.addAll(attrs!);
      }
      delta
        ..retain(lineBreak)
        ..retain(1, attributes);
      break;
    }
    return delta;
  }
}

/// Prevents user from merging a line containing an embed with other lines.
/// This rule applies to video, not image.
/// The rule relates to [InsertEmbedsRule].
class EnsureEmbedLineRule extends DeleteRule {
  const EnsureEmbedLineRule();

  @override
  Delta? applyRule(Delta document, int index,
      {int? len, Object? data, Attribute? attribute}) {
    final itr = DeltaIterator(document);

    var op = itr.skip(index);
    final opAfter = itr.skip(index + 1);

    // Only video embed occupies a whole line.
    if (!_isVideo(op) || !_isVideo(opAfter)) {
      return null;
    }

    int? indexDelta = 0, lengthDelta = 0, remain = len;
    var embedFound = op != null && op.data is! String;
    final hasLineBreakBefore =
        !embedFound && (op == null || (op.data as String).endsWith('\n'));
    if (embedFound) {
      var candidate = itr.next(1);
      if (remain != null) {
        remain--;
        if (candidate.data == '\n') {
          indexDelta++;
          lengthDelta--;

          candidate = itr.next(1);
          remain--;
          if (candidate.data == '\n') {
            lengthDelta++;
          }
        }
      }
    }

    op = itr.skip(remain!);
    if (op != null &&
        (op.data is String ? op.data as String? : '')!.endsWith('\n')) {
      final candidate = itr.next(1);
      if (candidate.data is! String && !hasLineBreakBefore) {
        embedFound = true;
        lengthDelta--;
      }
    }

    if (!embedFound) {
      return null;
    }

    return Delta()
      ..retain(index + indexDelta)
      ..delete(len! + lengthDelta);
  }

  bool _isVideo(op) {
    return false;
    // return op != null &&
    //     op.data is! String &&
    //     !(op.data as Map).containsKey(BlockEmbed.videoType);
  }
}

class DeleteBlockEmbedRule extends DeleteRule {
  const DeleteBlockEmbedRule();

  @override
  Delta? applyRule(Delta document, int index,
      {int? len, Object? data, Attribute? attribute}) {
    if (index == 0) return null;

    final prev = DeltaIterator(document).skip(index + len! - 1);
    final cur = DeltaIterator(document).skip(index + len);
    final next = DeltaIterator(document).skip(index + len + 1);

    if (next != null && next.data is! String) {
      if (next.data is Map &&
          (next.data as Map).containsKey('type') &&
          (next.data as Map)['type'] == 'InlineEmbed') {
        return null;
      }

      //删除顶格
      var offset = 0;
      if (cur?.data is String) {
        final p = cur!.data as String;
        if (p.length == 2 && p.endsWith('\n')) offset++;
      }

      return Delta()
        ..retain(index - 1)
        ..delete(len + offset);
    }

    if (prev != null && prev.data is! String) {
      if (prev.data is Map &&
          (prev.data as Map).containsKey('type') &&
          (prev.data as Map)['type'] == 'InlineEmbed') {
        return null;
      }

      //移除前后的空格
      var offset = 1;
      if (document.elementAt(0) != prev) offset++;

      return Delta()
        ..retain(index - offset)
        ..delete(len + offset);
    }
    return null;
  }
}
