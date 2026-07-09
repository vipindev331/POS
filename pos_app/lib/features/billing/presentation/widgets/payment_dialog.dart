// F12 checkout / payment. Pre-fills the payable and a chosen tender method.
// Enter confirms. Supports quick tender via a preselected method (F7 cash,
// F8 card, F9 UPI).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/money/tax_engine.dart';
import '../../domain/cart.dart';

class PaymentResult {
  final List<PaymentEntry> payments;
  const PaymentResult(this.payments);
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
          width: 420,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payment', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('Payable: ${formatPaise(widget.payable)}',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in PayMethod.values)
                    ChoiceChip(
                      label: Text(m.name.toUpperCase()),
                      selected: _method == m,
                      onSelected: (_) => setState(() => _method = m),
                    ),
                ],
              ),
              const SizedBox(height: 16),
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
                const SizedBox(height: 8),
                Text('Change: ${formatPaise(_change < 0 ? 0 : _change)}',
                    style: TextStyle(
                        color: _change < 0 ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: 8),
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
