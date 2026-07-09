// Everything a receipt needs, assembled from a saved bill + company profile.
// Platform printers (ESC/POS thermal, HTML web) render from this one model.
import '../../../core/money/tax_engine.dart';
import '../../../data/local/database.dart';

class CompanyProfile {
  final String name;
  final String gstin;
  final String address;
  final String phone;
  final String email;
  final String currencySymbol;

  const CompanyProfile({
    this.name = 'My Retail Store',
    this.gstin = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.currencySymbol = '₹',
  });

  factory CompanyProfile.fromJson(Map<String, dynamic> j) => CompanyProfile(
        name: (j['name'] ?? 'My Retail Store') as String,
        gstin: (j['gstin'] ?? '') as String,
        address: (j['address'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        email: (j['email'] ?? '') as String,
        currencySymbol: (j['currency'] == 'INR' || j['currency'] == null) ? '₹' : (j['currency'] as String),
      );
}

class ReceiptLine {
  final String name;
  final int qty;
  final int unitPrice;
  final int lineDiscount;
  final int gstRate;
  final int lineTotal;
  const ReceiptLine({
    required this.name,
    required this.qty,
    required this.unitPrice,
    required this.lineDiscount,
    required this.gstRate,
    required this.lineTotal,
  });
}

class ReceiptData {
  final CompanyProfile company;
  final String invoiceNo;
  final DateTime dateTime;
  final String cashier;
  final String customer;
  final List<ReceiptLine> lines;
  final int subTotal;
  final int itemDiscount;
  final int billDiscount;
  final int cgst;
  final int sgst;
  final int igst;
  final bool interState;
  final int roundOff;
  final int grandTotal;
  final int paid;
  final List<({String method, int amount})> payments;
  final String thankYou;

  const ReceiptData({
    required this.company,
    required this.invoiceNo,
    required this.dateTime,
    required this.cashier,
    required this.customer,
    required this.lines,
    required this.subTotal,
    required this.itemDiscount,
    required this.billDiscount,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.interState,
    required this.roundOff,
    required this.grandTotal,
    required this.paid,
    required this.payments,
    this.thankYou = 'Thank you! Visit again.',
  });

  /// Content encoded into the receipt QR (invoice + total + GSTIN).
  String get qrPayload =>
      'INV:$invoiceNo;TOTAL:${(grandTotal / 100).toStringAsFixed(2)};GSTIN:${company.gstin}';

  String money(int paise) => formatPaise(paise, symbol: company.currencySymbol);

  factory ReceiptData.fromBill({
    required CompanyProfile company,
    required FullBill full,
    required String cashier,
    required String customer,
  }) {
    final b = full.bill;
    return ReceiptData(
      company: company,
      invoiceNo: b.invoiceNo ?? b.localNo ?? b.id.substring(0, 8),
      dateTime: DateTime.fromMillisecondsSinceEpoch(b.createdAt),
      cashier: cashier,
      customer: customer,
      lines: full.items
          .map((i) => ReceiptLine(
                name: i.name,
                qty: i.qty,
                unitPrice: i.unitPrice,
                lineDiscount: i.lineDiscount,
                gstRate: i.gstRate,
                lineTotal: i.lineTotal,
              ))
          .toList(),
      subTotal: b.subTotal,
      itemDiscount: b.itemDiscount,
      billDiscount: b.billDiscount,
      cgst: b.cgst,
      sgst: b.sgst,
      igst: b.igst,
      interState: b.interState,
      roundOff: b.roundOff,
      grandTotal: b.grandTotal,
      paid: b.paid,
      payments: full.payments.map((p) => (method: p.method, amount: p.amount)).toList(),
    );
  }
}
