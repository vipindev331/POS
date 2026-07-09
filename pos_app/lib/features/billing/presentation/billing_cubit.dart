// BillingCubit — the billing ViewModel. Holds the active cart, applies the
// shared tax engine for live totals, and drives offline-first checkout.
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/local/database.dart';
import '../../products/data/products_repository.dart';
import '../data/sales_repository.dart';
import '../domain/cart.dart';
import 'billing_state.dart';

class BillingCubit extends Cubit<BillingState> {
  final ProductsRepository _products;
  final SalesRepository _sales;
  final String? cashierId;

  BillingCubit(this._products, this._sales, {this.cashierId}) : super(const BillingState());

  // ── Cart mutations ────────────────────────────────────────────────────────

  void addProduct(Product p) {
    final idx = state.lines.indexWhere((l) => l.productId == p.id);
    final lines = [...state.lines];
    if (idx >= 0) {
      lines[idx] = lines[idx].copyWith(qty: lines[idx].qty + 1);
    } else {
      lines.add(CartLine(
        productId: p.id,
        name: p.name,
        barcode: p.barcode,
        hsn: p.hsn,
        unitPrice: p.sellingPrice,
        qty: 1,
        gstRate: p.gstRate,
      ));
    }
    emit(state.copyWith(lines: lines, clearNotice: true, clearError: true));
  }

  /// Barcode scan / manual barcode entry. Increments if present, else looks up.
  /// Returns true if a product was found/added; false if nothing matched (so
  /// the caller can fall back to a name search).
  Future<bool> addByBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return false;
    final existing = state.lines.indexWhere((l) => l.barcode == code);
    if (existing >= 0) {
      final lines = [...state.lines];
      lines[existing] = lines[existing].copyWith(qty: lines[existing].qty + 1);
      emit(state.copyWith(lines: lines, clearNotice: true));
      return true;
    }
    final product = await _products.byBarcode(code);
    if (product == null) return false;
    addProduct(product);
    return true;
  }

  void setQty(int index, int qty) {
    if (index < 0 || index >= state.lines.length) return;
    if (qty <= 0) {
      removeLine(index);
      return;
    }
    final lines = [...state.lines];
    lines[index] = lines[index].copyWith(qty: qty);
    emit(state.copyWith(lines: lines));
  }

  void incQty(int index) => setQty(index, state.lines[index].qty + 1);
  void decQty(int index) => setQty(index, state.lines[index].qty - 1);

  void setLineDiscount(int index, int paise) {
    final lines = [...state.lines];
    lines[index] = lines[index].copyWith(lineDiscount: paise < 0 ? 0 : paise);
    emit(state.copyWith(lines: lines));
  }

  void removeLine(int index) {
    final lines = [...state.lines]..removeAt(index);
    emit(state.copyWith(lines: lines));
  }

  void setBillDiscount(int paise) => emit(state.copyWith(billDiscount: paise < 0 ? 0 : paise));
  void setInterState(bool value) => emit(state.copyWith(interState: value));

  void setCustomer({required String id, required String name}) =>
      emit(state.copyWith(customerId: id, customerName: name));
  void clearCustomer() => emit(state.copyWith(clearCustomer: true));

  void clearCart() => emit(const BillingState());
  void clearNotice() => emit(state.copyWith(clearNotice: true));

  // ── Checkout / hold ───────────────────────────────────────────────────────

  Future<CheckoutResult?> checkout(List<PaymentEntry> payments) async {
    if (state.isEmpty) {
      emit(state.copyWith(notice: 'Cart is empty'));
      return null;
    }
    emit(state.copyWith(isSaving: true, clearError: true, clearNotice: true));
    try {
      final result = await _sales.checkout(
        lines: state.lines,
        payments: payments,
        customerId: state.customerId,
        cashierId: cashierId,
        billDiscount: state.billDiscount,
        interState: state.interState,
      );
      // Reset cart, keep the last result for the receipt.
      emit(BillingState(lastResult: result, notice: 'Saved ${result.localNo}'));
      return result;
    } catch (e) {
      emit(state.copyWith(isSaving: false, error: 'Checkout failed: $e'));
      return null;
    }
  }

  /// Load a held bill back into the cart, then remove its local record.
  Future<void> resumeHeld(String billId) async {
    final full = await _sales.fullBill(billId);
    if (full == null) return;
    final lines = full.items
        .map((i) => CartLine(
              productId: i.productId,
              name: i.name,
              hsn: i.hsn,
              unitPrice: i.unitPrice,
              qty: i.qty,
              gstRate: i.gstRate,
              lineDiscount: i.lineDiscount,
            ))
        .toList();
    await _sales.deleteHeld(billId);
    emit(BillingState(
      lines: lines,
      billDiscount: full.bill.billDiscount,
      interState: full.bill.interState,
      customerId: full.bill.customerId,
      notice: 'Resumed ${full.bill.localNo ?? billId}',
    ));
  }

  Future<List<dynamic>> heldBills() => _sales.heldBills();

  Future<void> holdBill() async {
    if (state.isEmpty) return;
    emit(state.copyWith(isSaving: true));
    try {
      await _sales.checkout(
        lines: state.lines,
        payments: const [],
        customerId: state.customerId,
        cashierId: cashierId,
        billDiscount: state.billDiscount,
        interState: state.interState,
        status: 'held',
      );
      emit(const BillingState(notice: 'Bill held'));
    } catch (e) {
      emit(state.copyWith(isSaving: false, error: 'Hold failed: $e'));
    }
  }
}
