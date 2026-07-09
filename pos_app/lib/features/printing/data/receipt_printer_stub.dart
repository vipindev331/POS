// Fallback — a real platform implementation always wins via conditional import.
import '../domain/receipt_data.dart';
import 'receipt_printer.dart';

ReceiptPrinter createReceiptPrinter() => _StubPrinter();

class _StubPrinter implements ReceiptPrinter {
  @override
  Future<PrintOutcome> printReceipt(ReceiptData data, {PrinterConfig config = const PrinterConfig()}) async =>
      const PrintOutcome(false, 'No printer implementation for this platform');
}
