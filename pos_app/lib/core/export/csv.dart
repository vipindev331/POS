// CSV export. `buildCsv` is pure; `exportCsv` saves/downloads per platform
// (file on native, browser download on web) via conditional import.
import 'csv_stub.dart'
    if (dart.library.io) 'csv_native.dart'
    if (dart.library.js_interop) 'csv_web.dart' as impl;

String _cell(Object? v) {
  final s = v?.toString() ?? '';
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

String buildCsv(List<String> headers, List<List<Object?>> rows) {
  final buf = StringBuffer()..writeln(headers.map(_cell).join(','));
  for (final row in rows) {
    buf.writeln(row.map(_cell).join(','));
  }
  return buf.toString();
}

/// Save/download the CSV. Returns a human-readable location/message.
Future<String> exportCsv(String filename, String csv) => impl.exportCsv(filename, csv);
