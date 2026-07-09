import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> exportCsv(String filename, String csv) async {
  Directory dir;
  try {
    dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  } catch (_) {
    dir = await getApplicationDocumentsDirectory();
  }
  final file = File('${dir.path}/$filename');
  await file.writeAsString(csv);
  return 'Saved to ${file.path}';
}
