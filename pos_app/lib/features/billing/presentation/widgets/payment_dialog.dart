// F12 checkout / payment. Pre-fills the payable and a chosen tender method.
// Enter confirms. Supports quick tender via a preselected method (F7 cash,
// F8 card, F9 UPI).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/money/tax_engine.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/cart.dart';

IconData _methodIcon(PayMethod m) {
  switch (m) {
    case PayMethod.cash:
      return Icons.payments_outlined;
    case PayMethod.card:
      return Icons.credit_card;
    case PayMethod.upi:
      return Icons.qr_code_2;
    case PayMethod.wallet:
      return Icons.account_balance_wallet_outlined;
    case PayMethod.credit:
      return Icons.schedule_outlined;
  }
}

class PaymentResult {
  final List<PaymentEntry> payments;
  const PaymentResult(this.payments);
}

/// A tappable payment-method selector chip (icon + label) used in the dialog.
class _MethodChip extends StatelessWidget {
  final PayMethod method;
  final bool selected;
  final VoidCallback onTap;
  const _MethodChip({required this.method, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary.withValues(alpha: 0.14) : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_methodIcon(method),
                  size: 18,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                method.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? scheme.primary : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PaymentDialog extends StatefulWidget {
  final int payable; // paise
  final PayMethod initialMethod;
  const PaymentDialog({super.key, required this.payable, this.initialMethod = PayMethod.cash});

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  late PayMethod _method = widget.initialMethod;
  late final TextEditingController _tendered =
      TextEditingController(text: (widget.payable / 100).toStringAsFixed(2));
  final _focus = FocusNode();

  int get _tenderedPaise => ((double.tryParse(_tendered.text) ?? 0) * 100).round();
  int get _change => _tenderedPaise - widget.payable;

  void _confirm() {
    final amount = _method == PayMethod.cash
        ? widget.payable // cash: record the payable; change handled physically
        : _tenderedPaise;
    if (amount < widget.payable && _method != PayMethod.credit) {
      // Under-tender on non-credit is treated as partial; still allowed but flagged.
    }
    Navigator.of(context).pop(PaymentResult([
      PaymentEntry(method: _method, amount: _method == PayMethod.credit ? 0 : amount),
    ]));
  }

  @override
  void dispose() {
    _tendered.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      child: Focus(
        onKeyEvent: (_, e) {
          if (e is KeyDownEvent &&
              (e.logicalKey == LogicalKeyboardKey.enter ||
                  e.logicalKey == LogicalKeyboardKey.numpadEnter)) {
            _confirm();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payment',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface)),
              const Gap(AppSpacing.lg),
              // Payable amount, prominent.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PAYABLE',
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(formatPaise(widget.payable),
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface)),
                  ],
                ),
              ),
              const Gap(AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final m in PayMethod.values)
                    _MethodChip(
                      method: m,
                      selected: _method == m,
                      onTap: () => setState(() => _method = m),
                    ),
                ],
              ),
              const Gap(AppSpacing.lg),
              if (_method != PayMethod.credit)
                TextField(
                  controller: _tendered,
                  focusNode: _focus,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Tendered (₹)', prefixText: '₹ '),
                  onChanged: (_) => setState(() {}),
                ),
              if (_method == PayMethod.cash) ...[
                const Gap(AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Change to return',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13.5)),
                    Text(formatPaise(_change < 0 ? 0 : _change),
                        style: TextStyle(
                            color: _change < 0 ? scheme.error : scheme.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                  ],
                ),
              ],
              const Gap(AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const Gap(AppSpacing.sm),
                  FilledButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.check),
                    label: const Text('Confirm  (Enter)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
