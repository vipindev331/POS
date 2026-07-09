import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<String> exportCsv(String filename, String csv) async {
  final bytes = utf8.encode(csv).toJS;
  final blob = web.Blob(
    [bytes].toJS,
    web.BlobPropertyBag(type: 'text/csv'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return 'Downloaded $filename';
}
