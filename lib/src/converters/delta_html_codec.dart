import 'dart:convert';

import '../models/quill_delta.dart';
import 'delta2html.dart';
import 'html2delta.dart';

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
  Converter<String, Delta> get decoder => Html2DeltaDecoder();

  @override
  Converter<Delta, String> get encoder => Delta2HtmlEncoder();
}
