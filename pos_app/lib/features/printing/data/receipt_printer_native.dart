// Native (desktop/mobile) printer: renders ESC/POS bytes and dispatches them.
// Network printers (RAW 9100) are fully implemented here. USB/Bluetooth share
// the same byte stream — dispatch plugs in at the marked seam (a platform
// channel or a package like `flutter_esc_pos_utils` / `print_bluetooth_thermal`).
import 'dart:io';

import '../domain/receipt_data.dart';
import 'esc_pos.dart';
import 'receipt_printer.dart';

ReceiptPrinter createReceiptPrinter() => NativeReceiptPrinter();

class NativeReceiptPrinter implements ReceiptPrinter {
  @override
  Future<PrintOutcome> printReceipt(ReceiptData data,
      {PrinterConfig config = const PrinterConfig()}) async {
    final bytes = buildEscPosReceipt(data, width: config.widthChars);

    switch (config.kind) {
      case PrinterKind.network:
        if (config.host == null || config.host!.isEmpty) {
          return const PrintOutcome(false, 'No printer host configured');
        }
        try {
          final socket = await Socket.connect(config.host!, config.port,
              timeout: const Duration(seconds: 5));
          socket.add(bytes);
          await socket.flush();
          await socket.close();
          return PrintOutcome(true, 'Printed to ${config.host}:${config.port}');
        } catch (e) {
          return PrintOutcome(false, 'Network print failed: $e');
        }

      case PrinterKind.usb:
      case PrinterKind.bluetooth:
        // ── Dispatch seam ──────────────────────────────────────────────────
        // The ESC/POS `bytes` are ready; hand them to the platform USB/BT
        // channel here. Left unwired to avoid bundling a native plugin.
        return PrintOutcome(false,
            '${config.kind.name.toUpperCase()} dispatch not wired (${bytes.length} bytes ready)');

      case PrinterKind.browser:
        return const PrintOutcome(false, 'Browser printing is a web-only path');
    }
  }
}
