// The fast billing screen. Operable by keyboard only, mouse only, or both.
//   Barcode field is always refocused after each scan/add.
//   F2 search · F3 customer · F4 discount · F5 hold · F6 resume
//   F7 cash · F8 card · F9 UPI · F10 print · F12 checkout · Esc cancel · Ctrl+N new
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injector.dart';
import '../../../core/money/tax_engine.dart';
import '../../../data/local/database.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../../auth/presentation/user_menu.dart';
import '../../printing/data/print_service.dart';
import '../../products/data/products_repository.dart';
import '../../sync/presentation/sync_badge.dart';
import '../data/sales_repository.dart';
import '../domain/cart.dart';
import 'billing_cubit.dart';
import 'billing_state.dart';
import 'widgets/payment_dialog.dart';
import 'widgets/product_search_dialog.dart';

class BillingScreen extends StatelessWidget {
  const BillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BillingCubit(
        sl<ProductsRepository>(),
        sl<SalesRepository>(),
        cashierId: sl<AuthCubit>().state.user?.id,
      ),
      child: const _BillingView(),
    );
  }
}

class _BillingView extends StatefulWidget {
  const _BillingView();
  @override
  State<_BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends State<_BillingView> {
  final _barcodeController = TextEditingController();
  final _barcodeFocus = FocusNode();
  final _screenFocus = FocusNode();

  BillingCubit get _cubit => context.read<BillingCubit>();

  @override
  void initState() {
    super.initState();
    // Populate the local catalog from the backend if it's empty (offline-safe).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repo = sl<ProductsRepository>();
      if (await repo.localCount() == 0) {
        final n = await repo.refreshFromRemote();
        if (mounted && n > 0) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Loaded $n products')));
        }
      }
      _focusBarcode();
    });
  }

  void _focusBarcode() {
    if (mounted) _barcodeFocus.requestFocus();
  }

  Future<void> _submitBarcode(String value) async {
    await _cubit.addByBarcode(value);
    _barcodeController.clear();
    _focusBarcode(); // refocus after every scan
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _barcodeFocus.dispose();
    _screenFocus.dispose();
    super.dispose();
  }

  // ── Keyboard shortcut router ────────────────────────────────────────────────
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final ctrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;

    if (ctrl && event.logicalKey == LogicalKeyboardKey.keyN) {
      _cubit.clearCart();
      _focusBarcode();
      return KeyEventResult.handled;
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.f2:
        _openSearch();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f3:
        _openCustomer();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f4:
        _openDiscount();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f5:
        _cubit.holdBill();
        _focusBarcode();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f6:
        _openHeld();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f7:
        _checkout(PayMethod.cash);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f8:
        _checkout(PayMethod.card);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f9:
        _checkout(PayMethod.upi);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f10:
        _reprintLast();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.f12:
        _checkout(PayMethod.cash);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        _cubit.clearCart();
        _focusBarcode();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _notify(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _openSearch() async {
    final product = await showDialog<Product>(
      context: context,
      builder: (_) => ProductSearchDialog(repository: sl<ProductsRepository>()),
    );
    if (product != null) _cubit.addProduct(product);
    _focusBarcode();
  }

  Future<void> _openDiscount() async {
    final controller = TextEditingController(
        text: (_cubit.state.billDiscount / 100).toStringAsFixed(2));
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bill discount (₹)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(prefixText: '₹ '),
          onSubmitted: (v) => Navigator.pop(ctx, double.tryParse(v) ?? 0),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text) ?? 0),
              child: const Text('Apply')),
        ],
      ),
    );
    if (value != null) _cubit.setBillDiscount((value * 100).round());
    _focusBarcode();
  }

  Future<void> _openCustomer() async {
    final customers = await sl<AppDatabase>().partiesDao.allCustomers();
    if (!mounted) return;
    final picked = await showDialog<Customer>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Select customer (F3)'),
        children: [
          if (customers.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('No customers synced yet')),
          for (final c in customers)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, c),
              child: Text('${c.name}  ${c.phone ?? ''}'),
            ),
        ],
      ),
    );
    if (picked != null) _cubit.setCustomer(id: picked.id, name: picked.name);
    _focusBarcode();
  }

  Future<void> _openHeld() async {
    final held = await _cubit.heldBills();
    if (!mounted) return;
    final picked = await showDialog<Bill>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Resume held bill (F6)'),
        children: [
          if (held.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('No held bills')),
          for (final b in held.cast<Bill>())
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, b),
              child: Text('${b.localNo ?? b.id}  ·  ${formatPaise(b.grandTotal)}'),
            ),
        ],
      ),
    );
    if (picked != null) await _cubit.resumeHeld(picked.id);
    _focusBarcode();
  }

  Future<void> _checkout(PayMethod method) async {
    if (_cubit.state.isEmpty) {
      _notify('Cart is empty');
      return;
    }
    final payable = _cubit.state.totals.grandTotal;
    final result = await showDialog<PaymentResult>(
      context: context,
      builder: (_) => PaymentDialog(payable: payable, initialMethod: method),
    );
    if (result == null) {
      _focusBarcode();
      return;
    }
    final checkout = await _cubit.checkout(result.payments);
    if (mounted && checkout != null) {
      _notify('Bill saved (${checkout.localNo}) · ${formatPaise(checkout.totals.grandTotal)}');
      await _printBill(checkout.billId, customer: _cubit.state.customerName ?? 'Walk-in');
    }
    _focusBarcode();
  }

  Future<void> _printBill(String billId, {String customer = 'Walk-in'}) async {
    final full = await sl<SalesRepository>().fullBill(billId);
    if (full == null) return;
    final outcome = await sl<PrintService>().printBill(full, customer: customer);
    if (mounted && !outcome.success) _notify(outcome.message);
  }

  Future<void> _reprintLast() async {
    final recent = await sl<SalesRepository>().recentBills();
    if (recent.isEmpty) {
      _notify('No bill to reprint');
      return;
    }
    await _printBill(recent.first.id);
    _focusBarcode();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Focus(
      focusNode: _screenFocus,
      onKeyEvent: _onKey,
      child: BlocListener<BillingCubit, BillingState>(
        listenWhen: (a, b) => a.notice != b.notice || a.error != b.error,
        listener: (context, state) {
          final msg = state.error ?? state.notice;
          if (msg != null) _notify(msg);
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Billing'),
            actions: [
              BlocBuilder<BillingCubit, BillingState>(
                buildWhen: (a, b) => a.customerName != b.customerName,
                builder: (_, s) => Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(s.customerName ?? 'Walk-in'),
                  ),
                ),
              ),
              const SyncBadge(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Center(child: UserMenu()),
              ),
            ],
          ),
          body: Column(
            children: [
              _BarcodeBar(
                controller: _barcodeController,
                focusNode: _barcodeFocus,
                onSubmit: _submitBarcode,
              ),
              const Divider(height: 1),
              Expanded(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Expanded(flex: 3, child: _CartTable()),
                          const VerticalDivider(width: 1),
                          SizedBox(width: 320, child: _TotalsPanel(onCheckout: () => _checkout(PayMethod.cash))),
                        ],
                      )
                    : Column(
                        children: [
                          const Expanded(child: _CartTable()),
                          _TotalsPanel(onCheckout: () => _checkout(PayMethod.cash)),
                        ],
                      ),
              ),
              const _ShortcutLegend(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarcodeBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmit;
  const _BarcodeBar({required this.controller, required this.focusNode, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.qr_code_scanner),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              textInputAction: TextInputAction.none,
              decoration: const InputDecoration(
                hintText: 'Scan or type a barcode, then Enter  (F2 to search)',
              ),
              onSubmitted: onSubmit,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartTable extends StatelessWidget {
  const _CartTable();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BillingCubit, BillingState>(
      buildWhen: (a, b) => a.lines != b.lines,
      builder: (context, state) {
        if (state.isEmpty) {
          return const Center(child: Text('Scan a product to start billing'));
        }
        final cubit = context.read<BillingCubit>();
        return ListView.separated(
          itemCount: state.lines.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final line = state.lines[i];
            final lineResult = state.totals.lines[i];
            return ListTile(
              title: Text(line.name),
              subtitle: Text(
                  '${formatPaise(line.unitPrice)} × ${line.qty}  ·  GST ${line.gstRate}%'
                  '${line.lineDiscount > 0 ? '  ·  -${formatPaise(line.lineDiscount)}' : ''}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => cubit.decQty(i)),
                  Text('${line.qty}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => cubit.incQty(i)),
                  SizedBox(
                      width: 90,
                      child: Text(formatPaise(lineResult.lineTotal),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontWeight: FontWeight.bold))),
                  IconButton(
                      icon: const Icon(Icons.close), onPressed: () => cubit.removeLine(i)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _TotalsPanel extends StatelessWidget {
  final VoidCallback onCheckout;
  const _TotalsPanel({required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BillingCubit, BillingState>(
      builder: (context, state) {
        final t = state.totals;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _row('Items', '${state.itemCount}'),
              _row('Subtotal', formatPaise(t.subTotal)),
              if (t.itemDiscount > 0) _row('Item discount', '-${formatPaise(t.itemDiscount)}'),
              if (t.billDiscount > 0) _row('Bill discount', '-${formatPaise(t.billDiscount)}'),
              if (state.interState)
                _row('IGST', formatPaise(t.igst))
              else ...[
                _row('CGST', formatPaise(t.cgst)),
                _row('SGST', formatPaise(t.sgst)),
              ],
              if (t.roundOff != 0) _row('Round off', formatPaise(t.roundOff)),
              const Divider(),
              _row('TOTAL', formatPaise(t.grandTotal), big: true),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: state.isSaving ? null : onCheckout,
                icon: const Icon(Icons.check_circle),
                label: Text(state.isSaving ? 'Saving…' : 'Checkout  (F12)'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(String label, String value, {bool big = false}) {
    final style = big
        ? const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)
        : const TextStyle(fontSize: 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}

class _ShortcutLegend extends StatelessWidget {
  const _ShortcutLegend();
  @override
  Widget build(BuildContext context) {
    const items = 'F2 Search · F3 Customer · F4 Discount · F5 Hold · F6 Resume · '
        'F7 Cash · F8 Card · F9 UPI · F10 Print · F12 Checkout · Esc Cancel · Ctrl+N New';
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(items, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
