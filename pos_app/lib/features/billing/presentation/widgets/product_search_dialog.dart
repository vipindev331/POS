// F2 product search. Type to filter; Enter or click to add. Fully keyboard
// operable: ↑/↓ to move, Enter to select, Esc to close.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/money/tax_engine.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../../data/local/database.dart';
import '../../../products/data/products_repository.dart';

class ProductSearchDialog extends StatefulWidget {
  final ProductsRepository repository;
  final String initialTerm;
  const ProductSearchDialog({super.key, required this.repository, this.initialTerm = ''});

  @override
  State<ProductSearchDialog> createState() => _ProductSearchDialogState();
}

class _ProductSearchDialogState extends State<ProductSearchDialog> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  List<Product> _results = const [];
  int _highlight = 0;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialTerm;
    _search(widget.initialTerm);
  }

  Future<void> _search(String term) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = term.trim().isEmpty
          ? await widget.repository.all()
          : await widget.repository.search(term);
      if (!mounted) return;
      setState(() {
        _results = results.take(50).toList();
        _highlight = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Surface the failure instead of hanging on a spinner.
      setState(() {
        _results = const [];
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _move(int delta) {
    if (_results.isEmpty) return;
    setState(() => _highlight = (_highlight + delta).clamp(0, _results.length - 1));
  }

  void _select() {
    if (_results.isEmpty) return;
    Navigator.of(context).pop(_results[_highlight]);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 560,
        height: 480,
        child: Focus(
          onKeyEvent: (_, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            switch (event.logicalKey) {
              case LogicalKeyboardKey.arrowDown:
                _move(1);
                return KeyEventResult.handled;
              case LogicalKeyboardKey.arrowUp:
                _move(-1);
                return KeyEventResult.handled;
              case LogicalKeyboardKey.enter:
              case LogicalKeyboardKey.numpadEnter:
                _select();
                return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search products (name / SKU / barcode)',
                  ),
                  onChanged: _search,
                  onSubmitted: (_) => _select(),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? AppEmptyState(
                            icon: Icons.error_outline,
                            title: 'Search failed',
                            message: _error,
                            isError: true,
                          )
                        : _results.isEmpty
                            ? const AppEmptyState(
                                icon: Icons.search_off,
                                title: 'No products',
                                message: 'Try a different name, SKU or barcode.',
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                                itemCount: _results.length,
                                itemBuilder: (context, i) {
                                  final p = _results[i];
                                  final selected = i == _highlight;
                                  final scheme = Theme.of(context).colorScheme;
                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? scheme.primary.withValues(alpha: 0.12)
                                          : null,
                                      borderRadius: BorderRadius.circular(10),
                                      border: selected
                                          ? Border.all(
                                              color: scheme.primary.withValues(alpha: 0.5))
                                          : null,
                                    ),
                                    child: ListTile(
                                      dense: true,
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10)),
                                      title: Text(p.name,
                                          style:
                                              const TextStyle(fontWeight: FontWeight.w600)),
                                      subtitle: Text(
                                          '${p.barcode ?? p.sku ?? '—'}  ·  stock ${p.stock}'),
                                      trailing: Text(formatPaise(p.sellingPrice),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700, fontSize: 14)),
                                      onTap: () => Navigator.of(context).pop(p),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
