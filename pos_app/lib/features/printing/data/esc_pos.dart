// ESC/POS command builder — emits the raw byte stream a thermal printer
// understands (USB / Bluetooth / network, all speak ESC/POS). No dependency:
// we assemble the well-known control sequences directly.
import 'dart:convert';
import 'dart:typed_data';

import '../domain/receipt_data.dart';

class EscPos {
  final BytesBuilder _b = BytesBuilder();
  final int width; // characters per line (48 for 80mm, 32 for 58mm)

  EscPos({this.width = 48});

  static const _esc = 0x1B;
  static const _gs = 0x1D;

  EscPos raw(List<int> bytes) {
    _b.add(bytes);
    return this;
  }

  EscPos init() => raw([_esc, 0x40]); // ESC @
  EscPos feed([int n = 1]) => raw([_esc, 0x64, n]); // ESC d n
  EscPos cut() => raw([_gs, 0x56, 0x00]); // GS V 0 (full cut)

  EscPos align(int mode) => raw([_esc, 0x61, mode]); // 0 left, 1 center, 2 right
  EscPos bold(bool on) => raw([_esc, 0x45, on ? 1 : 0]);
  EscPos doubleSize(bool on) => raw([_gs, 0x21, on ? 0x11 : 0x00]); // GS ! (w+h)

  EscPos text(String s) {
    _b.add(latin1.encode(_ascii(s)));
    return this;
  }

  EscPos line([String s = '']) => text('$s\n');

  /// A left/right justified row within [width] columns.
  EscPos row(String left, String right) {
    final space = width - left.length - right.length;
    final padded = space > 0 ? left + ' ' * space + right : '$left $right';
    return line(padded);
  }

  EscPos rule([String ch = '-']) => line(ch * width);

  /// GS ( k — print a QR code of [data]. Model 2, moderate size + error level.
  EscPos qr(String data) {
    final bytes = latin1.encode(_ascii(data));
    // Select model 2
    raw([_gs, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);
    // Module size = 6
    raw([_gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x06]);
    // Error correction = M
    raw([_gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]);
    // Store data
    final len = bytes.length + 3;
    raw([_gs, 0x28, 0x6B, len & 0xFF, (len >> 8) & 0xFF, 0x31, 0x50, 0x30]);
    raw(bytes);
    // Print
    raw([_gs, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);
    return this;
  }

  Uint8List done() => _b.toBytes();

  // Thermal printers use a code page; strip anything non-ASCII (e.g. ₹) to a
  // safe token so the byte stream stays valid.
  String _ascii(String s) => s.replaceAll('₹', 'Rs.').replaceAll(RegExp(r'[^\x00-\x7F]'), '');
}

/// Render a full receipt to ESC/POS bytes.
Uint8List buildEscPosReceipt(ReceiptData r, {int width = 48}) {
  final p = EscPos(width: width)..init();

  p.align(1).bold(true).doubleSize(true).line(r.company.name).doubleSize(false);
  if (r.company.address.isNotEmpty) p.line(r.company.address);
  if (r.company.phone.isNotEmpty) p.line('Ph: ${r.company.phone}');
  if (r.company.gstin.isNotEmpty) p.line('GSTIN: ${r.company.gstin}');
  p.bold(false).align(0).rule();

  p.line('Invoice: ${r.invoiceNo}');
  p.line('Date: ${_fmt(r.dateTime)}');
  p.line('Cashier: ${r.cashier}');
  p.line('Customer: ${r.customer}');
  p.rule();

  p.row('Item', 'Amount');
  p.rule();
  for (final l in r.lines) {
    p.line(l.name);
    final qtyPrice = '  ${l.qty} x ${r.company.currencySymbol == '₹' ? 'Rs.' : ''}${(l.unitPrice / 100).toStringAsFixed(2)}'
        '${l.gstRate > 0 ? ' (GST ${l.gstRate}%)' : ''}';
    p.row(qtyPrice, (l.lineTotal / 100).toStringAsFixed(2));
  }
  p.rule();

  p.row('Subtotal', (r.subTotal / 100).toStringAsFixed(2));
  if (r.itemDiscount + r.billDiscount > 0) {
    p.row('Discount', '-${((r.itemDiscount + r.billDiscount) / 100).toStringAsFixed(2)}');
  }
  if (r.interState) {
    p.row('IGST', (r.igst / 100).toStringAsFixed(2));
  } else {
    p.row('CGST', (r.cgst / 100).toStringAsFixed(2));
    p.row('SGST', (r.sgst / 100).toStringAsFixed(2));
  }
  if (r.roundOff != 0) p.row('Round off', (r.roundOff / 100).toStringAsFixed(2));
  p.bold(true).doubleSize(true).row('TOTAL', (r.grandTotal / 100).toStringAsFixed(2)).doubleSize(false).bold(false);
  p.rule();

  for (final pay in r.payments) {
    p.row(pay.method.toUpperCase(), (pay.amount / 100).toStringAsFixed(2));
  }
  p.feed();

  p.align(1).qr(r.qrPayload).feed().line(r.thankYou).feed(2).cut();
  return p.done();
}

String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
