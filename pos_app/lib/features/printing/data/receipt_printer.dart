// Platform-agnostic receipt printing.
//   Desktop/mobile → raw ESC/POS bytes to a thermal printer (network socket
//     implemented; USB/BT dispatch plugs in at the marked seam).
//   Web → 80mm HTML injected into a hidden iframe, browser print dialog.
// The correct implementation is chosen by conditional import — call sites never
// import dart:io or dart:html.
import '../domain/receipt_data.dart';

import 'receipt_printer_stub.dart'
    if (dart.library.io) 'receipt_printer_native.dart'
    if (dart.library.js_interop) 'receipt_printer_web.dart' as impl;

enum PrinterKind { network, usb, bluetooth, browser }

class PrinterConfig {
  final PrinterKind kind;
  final String? host; // for network printers
  final int port;
  final int widthChars; // 48 = 80mm, 32 = 58mm
  const PrinterConfig({
    this.kind = PrinterKind.network,
    this.host,
    this.port = 9100,
    this.widthChars = 48,
  });

  factory PrinterConfig.fromJson(Map<String, dynamic> j) => PrinterConfig(
        kind: PrinterKind.values.firstWhere(
          (k) => k.name == (j['kind'] ?? 'network'),
          orElse: () => PrinterKind.network,
        ),
        host: j['host'] as String?,
        port: (j['port'] as num?)?.toInt() ?? 9100,
        widthChars: (j['width'] as num?)?.toInt() ?? 48,
      );
}

class PrintOutcome {
  final bool success;
  final String message;
  const PrintOutcome(this.success, this.message);
}

abstract class ReceiptPrinter {
  Future<PrintOutcome> printReceipt(ReceiptData data, {PrinterConfig config});
}

ReceiptPrinter createReceiptPrinter() => impl.createReceiptPrinter();
