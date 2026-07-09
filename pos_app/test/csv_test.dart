import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/export/csv.dart';

void main() {
  test('buildCsv escapes commas, quotes and newlines', () {
    final csv = buildCsv(
      ['Name', 'Qty', 'Note'],
      [
        ['Tata Salt', 3, 'ok'],
        ['Rice, 5kg', 1, 'He said "hi"'],
        ['Multi\nline', 2, 'x'],
      ],
    );
    final lines = csv.trimRight().split('\n');
    expect(lines.first, 'Name,Qty,Note');
    expect(lines[1], 'Tata Salt,3,ok');
    expect(lines[2], '"Rice, 5kg",1,"He said ""hi"""');
    // The embedded newline keeps the quoted field spanning two physical lines.
    expect(csv.contains('"Multi\nline",2,x'), true);
  });
}
