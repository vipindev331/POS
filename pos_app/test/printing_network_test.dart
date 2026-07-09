// Verifies the native network (RAW 9100) print path: the printer opens a socket
// and streams the ESC/POS bytes. A mock TCP server stands in for the printer.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/printing/data/receipt_printer.dart';
import 'package:pos_app/features/printing/domain/receipt_data.dart';

void main() {
  test('network printer streams ESC/POS bytes to the socket', () async {
    final received = <int>[];
    final server = await ServerSocket.bind('127.0.0.1', 0);
    server.listen((socket) {
      socket.listen(received.addAll);
    });
    addTearDown(server.close);

    final printer = createReceiptPrinter(); // native impl on the VM host
    final outcome = await printer.printReceipt(
      ReceiptData(
        company: const CompanyProfile(name: 'Demo Mart'),
        invoiceNo: 'INV-1',
        dateTime: DateTime(2026, 7, 9),
        cashier: 'staff',
        customer: 'Walk-in',
        lines: const [
          ReceiptLine(name: 'Item', qty: 1, unitPrice: 10000, lineDiscount: 0, gstRate: 18, lineTotal: 11800),
        ],
        subTotal: 10000, itemDiscount: 0, billDiscount: 0,
        cgst: 900, sgst: 900, igst: 0, interState: false,
        roundOff: 0, grandTotal: 11800, paid: 11800,
        payments: const [(method: 'cash', amount: 11800)],
      ),
      config: PrinterConfig(kind: PrinterKind.network, host: '127.0.0.1', port: server.port),
    );

    expect(outcome.success, true);
    // Give the socket a moment to deliver.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(received.length, greaterThan(100));
    expect(received.sublist(0, 2), [0x1B, 0x40]); // ESC @ init
  });
}
