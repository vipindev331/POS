// The fast billing screen. Operable by keyboard only, mouse only, or both.
//   Barcode field is always refocused after each scan/add.
//   F2 search · F3 customer · F4 discount · F5 hold · F6 resume
//   F7 cash · F8 card · F9 UPI · F10 print · F12 checkout · Esc cancel · Ctrl+N new
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injector.dart';
import '../../../core/money/tax_engine.dart';
import '../../../core/widgets/widgets.dart';
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
import 'widgets/barcode_scanner_sheet.dart';
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

  bool get _isMobile =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  void _focusBarcode() {
    // On phones/tablets, don't force the soft keyboard open every time — mobile
    // users scan with the camera. Keyboard-driven desktop keeps its focus.
    if (mounted && !_isMobile) _barcodeFocus.requestFocus();
  }

  // Open the full-screen camera scanner (mobile only). Continuous: each detected
  // barcode is added to the cart; the sheet stays open until the user taps Done.
  Future<void> _scanWithCamera() async {
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => BarcodeScannerScreen(
        onDetect: (code) => _cubit.addByBarcode(code),
      ),
    ));
    _focusBarcode(); // restore keyboard/USB-scanner flow on return
  }

  Future<void> _submitBarcode(String value) async {
    final found = await _cubit.addByBarcode(value);
    _barcodeController.clear();
    if (!found && value.trim().isNotEmpty) {
      // Not an exact barcode — fall back to a name/SKU/barcode search.
      await _openSearch(initialTerm: value.trim());
      return;
    }
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

  Future<void> _openSearch({String initialTerm = ''}) async {
    final product = await showDialog<Product>(
      context: context,
      builder: (_) => ProductSearchDialog(
        repository: sl<ProductsRepository>(),
        initialTerm: initialTerm,
      ),
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
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
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
          // Barcode field lives at the top, so let the soft keyboard overlay the
          // bottom (totals/legend) rather than shrinking the layout into overflow.
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            title: const Text('Billing'),
            actions: [
              BlocBuilder<BillingCubit, BillingState>(
                buildWhen: (a, b) => a.customerName != b.customerName,
                builder: (_, s) {
                  final named = s.customerName != null;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: StatusPill(
                        icon: named ? Icons.person : Icons.person_outline,
                        label: (s.customerName ?? 'Walk-in').toUpperCase(),
                        color: named
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 4),
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
                onScan: _scanWithCamera,
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
              // Function-key legend is only useful with a physical keyboard.
              if (!isMobile) const _ShortcutLegend(),
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
  final VoidCallback onScan;
  const _BarcodeBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              // Don't auto-open the soft keyboard on phones; desktop keeps focus.
              autofocus: !isMobile,
              textInputAction: TextInputAction.done,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.qr_code_scanner, color: scheme.primary),
                hintText: 'Scan or type a barcode, then Enter  (F2 to search)',
              ),
              onSubmitted: onSubmit,
            ),
          ),
          if (isMobile) ...[
            const Gap(AppSpacing.sm),
            IconButton.filledTonal(
              tooltip: 'Scan with camera',
              onPressed: onScan,
              icon: const Icon(Icons.camera_alt),
            ),
          ],
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
          return const AppEmptyState(
            icon: Icons.shopping_cart_outlined,
            title: 'Cart is empty',
            message: 'Scan a barcode or press F2 to search for a product to start billing.',
          );
        }
        final cubit = context.read<BillingCubit>();
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: state.lines.length,
          separatorBuilder: (_, _) => const Gap(AppSpacing.sm),
          itemBuilder: (context, i) {
            final line = state.lines[i];
            final lineResult = state.totals.lines[i];
            return _CartLine(
              name: line.name,
              detail: '${formatPaise(line.unitPrice)} × ${line.qty}  ·  GST ${line.gstRate}%'
                  '${line.lineDiscount > 0 ? '  ·  -${formatPaise(line.lineDiscount)}' : ''}',
              qty: line.qty,
              lineTotal: formatPaise(lineResult.lineTotal),
              onDec: () => cubit.decQty(i),
              onInc: () => cubit.incQty(i),
              onRemove: () => cubit.removeLine(i),
            );
          },
        );
      },
    );
  }
}

/// A single cart row: product name + pricing detail on the left, a compact
/// qty stepper and line total on the right, with a remove button.
class _CartLine extends StatelessWidget {
  final String name;
  final String detail;
  final int qty;
  final String lineTotal;
  final VoidCallback onDec;
  final VoidCallback onInc;
  final VoidCallback onRemove;

  const _CartLine({
    required this.name,
    required this.detail,
    required this.qty,
    required this.lineTotal,
    required this.onDec,
    required this.onInc,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          const Gap(AppSpacing.sm),
          _QtyStepper(qty: qty, onDec: onDec, onInc: onInc),
          const Gap(AppSpacing.sm),
          SizedBox(
            width: 84,
            child: Text(lineTotal,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            color: scheme.onSurfaceVariant,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// Compact −/qty/+ stepper pill used in cart rows.
class _QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onDec;
  final VoidCallback onInc;
  const _QtyStepper({required this.qty, required this.onDec, required this.onInc});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(context, Icons.remove, onDec),
          SizedBox(
            width: 28,
            child: Text('$qty',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
          _stepBtn(context, Icons.add, onInc),
        ],
      ),
    );
  }

  Widget _stepBtn(BuildContext context, IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        ),
      );
}

class _TotalsPanel extends StatelessWidget {
  final VoidCallback onCheckout;
  const _TotalsPanel({required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BlocBuilder<BillingCubit, BillingState>(
      builder: (context, state) {
        final t = state.totals;
        return Container(
          color: scheme.surfaceContainerLow,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _row(context, 'Items', '${state.itemCount}'),
              _row(context, 'Subtotal', formatPaise(t.subTotal)),
              if (t.itemDiscount > 0)
                _row(context, 'Item discount', '-${formatPaise(t.itemDiscount)}'),
              if (t.billDiscount > 0)
                _row(context, 'Bill discount', '-${formatPaise(t.billDiscount)}'),
              if (state.interState)
                _row(context, 'IGST', formatPaise(t.igst))
              else ...[
                _row(context, 'CGST', formatPaise(t.cgst)),
                _row(context, 'SGST', formatPaise(t.sgst)),
              ],
              if (t.roundOff != 0) _row(context, 'Round off', formatPaise(t.roundOff)),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Divider(height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('TOTAL',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: scheme.onSurfaceVariant)),
                  Text(formatPaise(t.grandTotal),
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                ],
              ),
              const Gap(AppSpacing.lg),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: state.isSaving ? null : onCheckout,
                  icon: const Icon(Icons.check_circle),
                  label: Text(state.isSaving ? 'Saving…' : 'Checkout  (F12)',
                      style: const TextStyle(fontSize: 15)),
                ),
              ),
              const Gap(AppSpacing.sm),
              OutlinedButton.icon(
                onPressed:
                    (state.isEmpty || state.isSaving) ? null : () => _cancelBill(context),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel bill  (Esc)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _cancelBill(BuildContext context) async {
    final cubit = context.read<BillingCubit>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel bill'),
        content: const Text('Remove all items and start over? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep bill')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel bill'),
          ),
        ],
      ),
    );
    if (confirm == true) cubit.clearCart();
  }

  Widget _row(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant)),
          Text(value,
              style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600, color: scheme.onSurface)),
        ],
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Text(items,
          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant, letterSpacing: 0.2)),
    );
  }
}
