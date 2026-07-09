import 'package:equatable/equatable.dart';

import '../../../core/money/tax_engine.dart';
import '../data/sales_repository.dart';
import '../domain/cart.dart';

class BillingState extends Equatable {
  final List<CartLine> lines;
  final int billDiscount;
  final bool interState;
  final String? customerId;
  final String? customerName;
  final bool isSaving;
  final String? error;
  final String? notice; // transient status text (e.g. "Not found")
  final CheckoutResult? lastResult;

  const BillingState({
    this.lines = const [],
    this.billDiscount = 0,
    this.interState = false,
    this.customerId,
    this.customerName,
    this.isSaving = false,
    this.error,
    this.notice,
    this.lastResult,
  });

  bool get isEmpty => lines.isEmpty;
  int get itemCount => lines.fold(0, (s, l) => s + l.qty);

  /// Live totals from the shared tax engine.
  BillResult get totals => computeBill(
        lines.map((l) => l.toLineInput()).toList(),
        billDiscount: billDiscount,
        interState: interState,
      );

  BillingState copyWith({
    List<CartLine>? lines,
    int? billDiscount,
    bool? interState,
    String? customerId,
    String? customerName,
    bool? isSaving,
    String? error,
    String? notice,
    CheckoutResult? lastResult,
    bool clearError = false,
    bool clearNotice = false,
    bool clearCustomer = false,
    bool clearResult = false,
  }) {
    return BillingState(
      lines: lines ?? this.lines,
      billDiscount: billDiscount ?? this.billDiscount,
      interState: interState ?? this.interState,
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      customerName: clearCustomer ? null : (customerName ?? this.customerName),
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
      notice: clearNotice ? null : (notice ?? this.notice),
      lastResult: clearResult ? null : (lastResult ?? this.lastResult),
    );
  }

  @override
  List<Object?> get props =>
      [lines, billDiscount, interState, customerId, customerName, isSaving, error, notice, lastResult];
}
