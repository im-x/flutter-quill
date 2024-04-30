import 'dart:convert';
import 'dart:io';

import '../../quill_delta.dart';
import 'delta2html.dart';
import 'html2delta.dart';

const DeltaHtmlCodec html = DeltaHtmlCodec();
final specialCodeReg = RegExp(r'[\uF000-\uF0FF]');

String htmlEncode(Delta delta) {
  return html.encode(delta);
}

Delta htmlDecode(String source) {
  if (Platform.isIOS && specialCodeReg.hasMatch(source)) {
    source = source.replaceAll(specialCodeReg, '□');
  }
  if (source.indexOf('\n') != -1) {
    source = source.replaceAll('\n', '<br>');
  }
  return html.decode(source);
}

class DeltaHtmlCodec extends Codec<Delta, String> {
  const DeltaHtmlCodec();

  @override
  Converter<String, Delta> get decoder => Html2DeltaDecoder();

  @override
  Converter<Delta, String> get encoder => Delta2HtmlEncoder();
}
