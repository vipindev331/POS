// 80mm HTML receipt for the web target. Uses CSS @media print sized to 80mm
// and an inline SVG QR (from the pure-Dart `barcode` package) so it needs no
// network assets. The web printer injects this and calls window.print().
import 'package:barcode/barcode.dart';

import '../domain/receipt_data.dart';

String buildHtmlReceipt(ReceiptData r) {
  final qrSvg = Barcode.qrCode().toSvg(r.qrPayload, width: 120, height: 120, drawText: false);
  final rows = StringBuffer();
  for (final l in r.lines) {
    rows.writeln('''
      <tr><td colspan="2" class="item">${_esc(l.name)}</td></tr>
      <tr class="sub">
        <td>${l.qty} × ${r.money(l.unitPrice)}${l.gstRate > 0 ? ' · GST ${l.gstRate}%' : ''}</td>
        <td class="right">${r.money(l.lineTotal)}</td>
      </tr>''');
  }

  String totalRow(String label, String value, {bool big = false}) =>
      '<tr class="${big ? 'grand' : 'tot'}"><td>${_esc(label)}</td><td class="right">$value</td></tr>';

  final taxRows = r.interState
      ? totalRow('IGST', r.money(r.igst))
      : totalRow('CGST', r.money(r.cgst)) + totalRow('SGST', r.money(r.sgst));

  final payRows =
      r.payments.map((p) => totalRow(p.method.toUpperCase(), r.money(p.amount))).join();

  return '''
<!doctype html>
<html><head><meta charset="utf-8"><title>${_esc(r.invoiceNo)}</title>
<style>
  * { box-sizing: border-box; }
  body { margin: 0; font-family: 'Courier New', monospace; color: #000; }
  .receipt { width: 80mm; padding: 4mm; margin: 0 auto; font-size: 12px; }
  h1 { font-size: 16px; text-align: center; margin: 0 0 2px; }
  .center { text-align: center; }
  .right { text-align: right; }
  .meta { font-size: 11px; }
  hr { border: none; border-top: 1px dashed #000; margin: 6px 0; }
  table { width: 100%; border-collapse: collapse; }
  td { padding: 1px 0; vertical-align: top; }
  .item { font-weight: bold; padding-top: 3px; }
  .sub td { font-size: 11px; }
  .grand td { font-weight: bold; font-size: 15px; border-top: 1px solid #000; }
  .thanks { text-align: center; margin-top: 8px; }
  @media print { @page { size: 80mm auto; margin: 0; } body { width: 80mm; } }
</style></head>
<body onload="window.focus();window.print();">
  <div class="receipt">
    <h1>${_esc(r.company.name)}</h1>
    <div class="center meta">
      ${r.company.address.isNotEmpty ? '${_esc(r.company.address)}<br>' : ''}
      ${r.company.phone.isNotEmpty ? 'Ph: ${_esc(r.company.phone)}<br>' : ''}
      ${r.company.gstin.isNotEmpty ? 'GSTIN: ${_esc(r.company.gstin)}' : ''}
    </div>
    <hr>
    <div class="meta">
      Invoice: <b>${_esc(r.invoiceNo)}</b><br>
      Date: ${_fmt(r.dateTime)}<br>
      Cashier: ${_esc(r.cashier)} &nbsp; Customer: ${_esc(r.customer)}
    </div>
    <hr>
    <table>$rows</table>
    <hr>
    <table>
      ${totalRow('Subtotal', r.money(r.subTotal))}
      ${r.itemDiscount + r.billDiscount > 0 ? totalRow('Discount', '-${r.money(r.itemDiscount + r.billDiscount)}') : ''}
      $taxRows
      ${r.roundOff != 0 ? totalRow('Round off', r.money(r.roundOff)) : ''}
      ${totalRow('TOTAL', r.money(r.grandTotal), big: true)}
      $payRows
    </table>
    <div class="center" style="margin-top:8px;">$qrSvg</div>
    <div class="thanks">${_esc(r.thankYou)}</div>
  </div>
</body></html>''';
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _fmt(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
