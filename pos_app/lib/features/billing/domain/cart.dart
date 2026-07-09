// Billing domain models. Pure Dart — no Flutter/DB/HTTP imports.
import 'package:equatable/equatable.dart';

import '../../../core/money/tax_engine.dart';

/// A single line in the active cart.
class CartLine extends Equatable {
  final String? productId;
  final String name;
  final String? barcode;
  final String? hsn;
  final int unitPrice; // paise, tax-exclusive
  final int qty;
  final int lineDiscount; // paise
  final int gstRate;

  const CartLine({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.qty,
    this.gstRate = 0,
    this.lineDiscount = 0,
    this.barcode,
    this.hsn,
  });

  CartLine copyWith({int? qty, int? lineDiscount, int? unitPrice}) => CartLine(
        productId: productId,
        name: name,
        barcode: barcode,
        hsn: hsn,
        unitPrice: unitPrice ?? this.unitPrice,
        qty: qty ?? this.qty,
        gstRate: gstRate,
        lineDiscount: lineDiscount ?? this.lineDiscount,
      );

  LineInput toLineInput() => LineInput(
        unitPrice: unitPrice,
        qty: qty,
        lineDiscount: lineDiscount,
        gstRate: gstRate,
      );

  @override
  List<Object?> get props => [productId, name, unitPrice, qty, lineDiscount, gstRate];
}

enum PayMethod { cash, card, upi, wallet, credit }

class PaymentEntry extends Equatable {
  final PayMethod method;
  final int amount; // paise
  final String? reference;
  const PaymentEntry({required this.method, required this.amount, this.reference});

  String get methodName => method.name;

  @override
  List<Object?> get props => [method, amount, reference];
}
