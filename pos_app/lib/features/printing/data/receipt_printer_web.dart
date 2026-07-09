// Web printer: build the 80mm HTML receipt, drop it into a hidden iframe whose
// body auto-calls window.print() on load, then clean up. Uses browser printing
// with CSS @page 80mm — no native plugin, works in any browser.
import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../domain/receipt_data.dart';
import 'html_receipt.dart';
import 'receipt_printer.dart';

ReceiptPrinter createReceiptPrinter() => WebReceiptPrinter();

class WebReceiptPrinter implements ReceiptPrinter {
  @override
  Future<PrintOutcome> printReceipt(ReceiptData data,
      {PrinterConfig config = const PrinterConfig()}) async {
    try {
      final html = buildHtmlReceipt(data);
      final iframe = web.HTMLIFrameElement()
        ..style.position = 'fixed'
        ..style.right = '0'
        ..style.bottom = '0'
        ..style.width = '0'
        ..style.height = '0'
        ..style.border = '0'
        ..srcdoc = html.toJS;

      web.document.body!.append(iframe);
      // Remove the iframe a little after the print dialog has been served.
      Timer(const Duration(seconds: 30), () => iframe.remove());
      return const PrintOutcome(true, 'Sent to browser print');
    } catch (e) {
      return PrintOutcome(false, 'Web print failed: $e');
    }
  }
}
