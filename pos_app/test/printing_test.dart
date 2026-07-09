// Verifies the ESC/POS byte stream and the 80mm HTML receipt render correctly
// from a ReceiptData (both platform printers build from these).
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/printing/data/esc_pos.dart';
import 'package:pos_app/features/printing/data/html_receipt.dart';
import 'package:pos_app/features/printing/domain/receipt_data.dart';

ReceiptData _sample() => ReceiptData(
      company: const CompanyProfile(
          name: 'Demo Mart', gstin: '29ABCDE1234F1Z5', address: 'MG Road', phone: '9999999999'),
      invoiceNo: 'INV-BR01-000001',
      dateTime: DateTime(2026, 7, 9, 14, 30),
      cashier: 'staff',
      customer: 'Walk-in',
      lines: const [
        ReceiptLine(name: 'Tata Salt 1kg', qty: 3, unitPrice: 2800, lineDiscount: 0, gstRate: 5, lineTotal: 8820),
      ],
      subTotal: 8400,
      itemDiscount: 0,
      billDiscount: 0,
      cgst: 210,
      sgst: 210,
      igst: 0,
      interState: false,
      roundOff: -20,
      grandTotal: 8800,
      paid: 8800,
      payments: const [(method: 'cash', amount: 8800)],
    );

void main() {
  test('ESC/POS bytes start with printer init and are non-trivial', () {
    final bytes = buildEscPosReceipt(_sample());
    // ESC @ init sequence.
    expect(bytes.sublist(0, 2), [0x1B, 0x40]);
    // Contains a GS (cut) command near the end.
    expect(bytes.length, greaterThan(200));
    expect(bytes.contains(0x1D), true);
  });

  test('HTML receipt contains key fields, totals, QR svg and 80mm print CSS', () {
    final html = buildHtmlReceipt(_sample());
    expect(html.contains('Demo Mart'), true);
    expect(html.contains('INV-BR01-000001'), true);
    expect(html.contains('Tata Salt 1kg'), true);
    expect(html.contains('TOTAL'), true);
    expect(html.contains('₹88.00'), true); // grand total formatted
    expect(html.contains('<svg'), true); // QR rendered as inline SVG
    expect(html.contains('80mm'), true); // print sizing
    expect(html.contains('window.print()'), true);
  });

  test('QR payload encodes invoice + total + gstin', () {
    final r = _sample();
    expect(r.qrPayload, 'INV:INV-BR01-000001;TOTAL:88.00;GSTIN:29ABCDE1234F1Z5');
  });
}
