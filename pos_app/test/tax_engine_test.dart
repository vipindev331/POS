// Mirrors backend/tests/money.test.js — proves the Dart port computes
// byte-identical totals to the server tax engine.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/money/tax_engine.dart';

void main() {
  test('roundToRupee rounds to nearest 100 paise', () {
    expect(roundToRupee(12345), 12300);
    expect(roundToRupee(12350), 12400); // half up
    expect(roundToRupee(12399), 12400);
    expect(roundToRupee(0), 0);
  });

  test('computeLine intra-state splits tax into equal CGST/SGST', () {
    final l = computeLine(const LineInput(unitPrice: 27500, qty: 2, gstRate: 5));
    expect(l.taxable, 55000);
    expect(l.tax, 2750);
    expect(l.cgst, 1375);
    expect(l.sgst, 1375);
    expect(l.igst, 0);
    expect(l.lineTotal, 57750);
  });

  test('computeLine odd tax splits remainder to SGST', () {
    final l = computeLine(const LineInput(unitPrice: 100, qty: 1, gstRate: 5));
    expect(l.tax, 5);
    expect(l.cgst, 2);
    expect(l.sgst, 3);
  });

  test('computeLine inter-state uses IGST only', () {
    final l = computeLine(
      const LineInput(unitPrice: 10000, qty: 1, gstRate: 18),
      interState: true,
    );
    expect(l.igst, 1800);
    expect(l.cgst, 0);
    expect(l.sgst, 0);
  });

  test('line discount reduces taxable before tax', () {
    final l = computeLine(
      const LineInput(unitPrice: 10000, qty: 1, lineDiscount: 2000, gstRate: 18),
    );
    expect(l.taxable, 8000);
    expect(l.tax, 1440);
  });

  test('computeBill totals + round-off', () {
    final bill = computeBill(const [
      LineInput(unitPrice: 27500, qty: 2, gstRate: 5),
      LineInput(unitPrice: 4000, qty: 1, gstRate: 28),
    ]);
    expect(bill.subTotal, 59000);
    expect(bill.totalTax, 3870);
    expect(bill.grandTotal, 62900);
    expect(bill.roundOff, 30);
  });

  test('computeBill applies bill discount capped at subtotal', () {
    final bill = computeBill(
      const [LineInput(unitPrice: 10000, qty: 1, gstRate: 0)],
      billDiscount: 99999,
    );
    expect(bill.billDiscount, 10000);
    expect(bill.grandTotal, 0);
  });

  test('rejects invalid GST slab', () {
    expect(
      () => computeLine(const LineInput(unitPrice: 100, qty: 1, gstRate: 7)),
      throwsA(isA<TaxException>()),
    );
  });

  test('formatPaise groups Indian style', () {
    expect(formatPaise(12345), '₹123.45');
    expect(formatPaise(123456789), '₹12,34,567.89');
    expect(formatPaise(-5000), '-₹50.00');
  });
}
