// Sold-products listing. Shows every product sold in a date range (default
// today) with quantity, revenue, and bill count. Tap a row to view the
// individual sale lines. Server-computed, so it needs a connection.
import 'package:flutter/material.dart';

import '../../../core/di/injector.dart';
import '../../../core/money/tax_engine.dart';
import '../data/reports_api.dart';
import 'widgets/report_date_bar.dart';

class SoldProductsScreen extends StatefulWidget {
  const SoldProductsScreen({super.key});

  @override
  State<SoldProductsScreen> createState() => _SoldProductsScreenState();
}

class _SoldProductsScreenState extends State<SoldProductsScreen> {
  ReportsApi get _api => sl<ReportsApi>();

  DateTimeRange _range = todayRange();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = _api.soldProducts(_range.start, rangeTo(_range));
  }

  void _setRange(DateTimeRange r) {
    setState(() {
      _range = r;
      _reload();
    });
  }

  Future<void> _viewDetail(Map<String, dynamic> row) async {
    final id = row['product_id'] as String?;
    if (id == null) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _SoldDetailDialog(
        productId: id,
        name: (row['name'] ?? '-').toString(),
        range: _range,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sold products'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(_reload),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          ReportDateBar(range: _range, onChanged: _setRange),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load sold products.\nThis report needs a connection to the server.\n\n${snap.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                final rows = snap.data ?? const [];
                if (rows.isEmpty) {
                  return const Center(child: Text('No products sold in this period.'));
                }
                final totalQty = rows.fold<int>(0, (s, r) => s + (r['qty'] as int? ?? 0));
                final totalRevenue =
                    rows.fold<int>(0, (s, r) => s + (r['revenue'] as int? ?? 0));
                return Column(
                  children: [
                    _SummaryBar(items: rows.length, qty: totalQty, revenue: totalRevenue),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final r = rows[i];
                          final qty = r['qty'] as int? ?? 0;
                          final revenue = r['revenue'] as int? ?? 0;
                          final bills = r['bills'] as int? ?? 0;
                          final sku = (r['sku'] ?? '').toString();
                          return ListTile(
                            onTap: () => _viewDetail(r),
                            leading: CircleAvatar(child: Text('$qty')),
                            title: Text((r['name'] ?? '-').toString()),
                            subtitle: Text(
                                '${sku.isNotEmpty ? '$sku · ' : ''}$bills bill${bills == 1 ? '' : 's'}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatPaise(revenue),
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('Qty $qty',
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final int items;
  final int qty;
  final int revenue;
  const _SummaryBar({required this.items, required this.qty, required this.revenue});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stat(context, 'Products', '$items'),
          _stat(context, 'Units sold', '$qty'),
          _stat(context, 'Revenue', formatPaise(revenue)),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      );
}

class _SoldDetailDialog extends StatefulWidget {
  final String productId;
  final String name;
  final DateTimeRange range;
  const _SoldDetailDialog({required this.productId, required this.name, required this.range});

  @override
  State<_SoldDetailDialog> createState() => _SoldDetailDialogState();
}

class _SoldDetailDialogState extends State<_SoldDetailDialog> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<ReportsApi>()
        .soldProductDetail(widget.productId, widget.range.start, rangeTo(widget.range));
  }

  String _dateTime(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }

  // 'cash,upi' -> 'Cash · UPI'. Empty (unpaid/held) -> 'No payment recorded'.
  String _payments(Object? raw) {
    final s = (raw ?? '').toString();
    if (s.isEmpty) return 'No payment recorded';
    return s
        .split(',')
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .map((m) => m.toLowerCase() == 'upi' ? 'UPI' : '${m[0].toUpperCase()}${m.substring(1)}')
        .join(' · ');
  }

  IconData _payIcon(Object? raw) {
    final s = (raw ?? '').toString().toLowerCase();
    if (s.contains('card')) return Icons.credit_card;
    if (s.contains('upi')) return Icons.qr_code_2;
    if (s.contains('cash')) return Icons.payments_outlined;
    return Icons.receipt_long;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.name),
      content: SizedBox(
        width: 480,
        height: 420,
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Could not load lines.\n${snap.error}',
                  textAlign: TextAlign.center));
            }
            final lines = snap.data ?? const [];
            if (lines.isEmpty) {
              return const Center(child: Text('No sales in this period.'));
            }
            return ListView.separated(
              itemCount: lines.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final l = lines[i];
                final inv = (l['invoice_no'] ?? l['billId'] ?? '-').toString();
                final qty = l['qty'] as int? ?? 0;
                final unit = l['unit_price'] as int? ?? 0;
                final total = l['line_total'] as int? ?? 0;
                final gst = l['gst_rate'];
                final customer = (l['customer_name'] ?? '').toString();
                final phone = (l['customer_phone'] ?? '').toString();
                final cashier = (l['cashier_name'] ?? '').toString();
                final billTotal = l['grand_total'] as int? ?? 0;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(inv,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          ),
                          Text(formatPaise(total),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _detail(Icons.event, _dateTime(l['created_at'] as int)),
                      _detail(_payIcon(l['payment_methods']), _payments(l['payment_methods'])),
                      _detail(Icons.shopping_cart_outlined,
                          '$qty × ${formatPaise(unit)}${gst != null ? '  ·  GST $gst%' : ''}'),
                      _detail(Icons.person_outline,
                          customer.isEmpty ? 'Walk-in customer' : (phone.isEmpty ? customer : '$customer ($phone)')),
                      if (cashier.isNotEmpty) _detail(Icons.badge_outlined, 'Billed by $cashier'),
                      _detail(Icons.receipt_long_outlined, 'Bill total ${formatPaise(billTotal)}'),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }

  Widget _detail(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ],
        ),
      );
}
