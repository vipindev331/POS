/// MONEY & TAX ENGINE — Dart port of `backend/src/utils/money.js`.
///
/// This MUST stay byte-equivalent to the backend: identical inputs must yield
/// identical totals so an offline-computed bill reconciles exactly on sync.
/// If you change one side, change the other and update both test suites.
///
/// All money is INTEGER paise. `unitPrice` is tax-exclusive; GST is added.
library;

const List<int> kGstSlabs = [0, 5, 12, 18, 28];

/// Round a paise amount to the nearest whole rupee (100 paise).
/// Matches JS `Math.round(paise/100)*100` for the non-negative values used here.
int roundToRupee(int paise) => (paise / 100).round() * 100;

class LineResult {
  final int gross;
  final int taxable;
  final int tax;
  final int cgst;
  final int sgst;
  final int igst;
  final int lineTotal;

  const LineResult({
    required this.gross,
    required this.taxable,
    required this.tax,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.lineTotal,
  });
}

class LineInput {
  final int unitPrice;
  final int qty;
  final int lineDiscount;
  final int gstRate;

  const LineInput({
    required this.unitPrice,
    required this.qty,
    this.lineDiscount = 0,
    required this.gstRate,
  });
}

class BillResult {
  final List<LineResult> lines;
  final int subTotal;
  final int itemDiscount;
  final int billDiscount;
  final int totalTax;
  final int cgst;
  final int sgst;
  final int igst;
  final bool interState;
  final int roundOff;
  final int grandTotal;

  const BillResult({
    required this.lines,
    required this.subTotal,
    required this.itemDiscount,
    required this.billDiscount,
    required this.totalTax,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.interState,
    required this.roundOff,
    required this.grandTotal,
  });
}

class TaxException implements Exception {
  final String message;
  const TaxException(this.message);
  @override
  String toString() => 'TaxException: $message';
}

/// Compute a single line. Mirrors `computeLine` in money.js.
LineResult computeLine(LineInput item, {bool interState = false}) {
  if (!kGstSlabs.contains(item.gstRate)) {
    throw TaxException(
        'gstRate ${item.gstRate} is not a valid GST slab (${kGstSlabs.join('/')})');
  }
  final gross = item.unitPrice * item.qty;
  final taxable = (gross - item.lineDiscount) < 0 ? 0 : gross - item.lineDiscount;
  final tax = (taxable * item.gstRate / 100).round();

  var cgst = 0;
  var sgst = 0;
  var igst = 0;
  if (interState) {
    igst = tax;
  } else {
    cgst = tax ~/ 2; // floor for non-negative — matches Math.floor(tax/2)
    sgst = tax - cgst;
  }

  return LineResult(
    gross: gross,
    taxable: taxable,
    tax: tax,
    cgst: cgst,
    sgst: sgst,
    igst: igst,
    lineTotal: taxable + tax,
  );
}

/// Compute a full bill. Mirrors `computeBill` in money.js.
BillResult computeBill(
  List<LineInput> items, {
  int billDiscount = 0,
  bool interState = false,
}) {
  final lines = items.map((it) => computeLine(it, interState: interState)).toList();

  final subTotal = lines.fold<int>(0, (s, l) => s + l.taxable);
  final totalTax = lines.fold<int>(0, (s, l) => s + l.tax);
  final totalCgst = lines.fold<int>(0, (s, l) => s + l.cgst);
  final totalSgst = lines.fold<int>(0, (s, l) => s + l.sgst);
  final totalIgst = lines.fold<int>(0, (s, l) => s + l.igst);
  final itemDiscount = items.fold<int>(0, (s, it) => s + it.lineDiscount);

  final cappedBillDiscount = billDiscount < subTotal ? billDiscount : subTotal;
  final afterBillDisc = subTotal - cappedBillDiscount;
  final preRound = afterBillDisc + totalTax;
  final grandTotal = roundToRupee(preRound);
  final roundOff = grandTotal - preRound;

  return BillResult(
    lines: lines,
    subTotal: subTotal,
    itemDiscount: itemDiscount,
    billDiscount: cappedBillDiscount,
    totalTax: totalTax,
    cgst: totalCgst,
    sgst: totalSgst,
    igst: totalIgst,
    interState: interState,
    roundOff: roundOff,
    grandTotal: grandTotal,
  );
}

/// Format integer paise as a rupee string, e.g. 12345 -> "123.45".
String formatPaise(int paise, {String symbol = '₹'}) {
  final negative = paise < 0;
  final abs = paise.abs();
  final rupees = abs ~/ 100;
  final paisePart = (abs % 100).toString().padLeft(2, '0');
  final grouped = _groupIndian(rupees);
  return '${negative ? '-' : ''}$symbol$grouped.$paisePart';
}

// Indian digit grouping (e.g. 1234567 -> 12,34,567).
String _groupIndian(int value) {
  final s = value.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  var head = s.substring(0, s.length - 3);
  // Group the head into pairs from the right.
  final groups = <String>[];
  while (head.length > 2) {
    groups.insert(0, head.substring(head.length - 2));
    head = head.substring(0, head.length - 2);
  }
  if (head.isNotEmpty) groups.insert(0, head);
  return '${groups.join(',')},$last3';
}
