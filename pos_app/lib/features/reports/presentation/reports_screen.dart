// Reports & dashboard. Tabs: Dashboard · Sales · GST · Profit · Inventory.
// Data is computed server-side; each tab exports its table to CSV.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injector.dart';
import '../../../core/export/csv.dart';
import '../../../core/money/tax_engine.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../data/reports_api.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isManager = context.read<AuthCubit>().state.user?.isManager ?? false;
    final tabs = <Tab>[
      const Tab(text: 'Dashboard'),
      const Tab(text: 'Sales'),
      const Tab(text: 'GST'),
      if (isManager) const Tab(text: 'Profit'),
      const Tab(text: 'Inventory'),
    ];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports'),
          bottom: TabBar(isScrollable: true, tabs: tabs),
        ),
        body: TabBarView(
          children: [
            const _DashboardTab(),
            const _SalesTab(),
            const _GstTab(),
            if (isManager) const _ProfitTab(),
            const _InventoryTab(),
          ],
        ),
      ),
    );
  }
}

ReportsApi get _api => sl<ReportsApi>();

// Generic async loader with an offline/error fallback.
class _Loader<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext, T) builder;
  const _Loader({required this.future, required this.builder});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load report.\nReports need a connection to the server.\n\n${snap.error}',
                  textAlign: TextAlign.center),
            ),
          );
        }
        return builder(context, snap.data as T);
      },
    );
  }
}

Future<void> _download(BuildContext context, String name, List<String> headers, List<List<Object?>> rows) async {
  final msg = await exportCsv(name, buildCsv(headers, rows));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _ExportBar extends StatelessWidget {
  final VoidCallback onExport;
  const _ExportBar({required this.onExport});
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: OutlinedButton.icon(
              onPressed: onExport, icon: const Icon(Icons.download), label: const Text('Export CSV')),
        ),
      );
}

// ── Dashboard ───────────────────────────────────────────────────────────────
class _DashboardTab extends StatelessWidget {
  const _DashboardTab();
  @override
  Widget build(BuildContext context) {
    return _Loader<Map<String, dynamic>>(
      future: _api.dashboard(),
      builder: (context, d) {
        final recent = (d['recentBills'] as List).cast<Map<String, dynamic>>();
        final top = (d['topProducts'] as List).cast<Map<String, dynamic>>();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _kpi(context, "Today's Sales", formatPaise(d['todaySales'] as int), Icons.today, '${d['todayCount']} bills'),
                _kpi(context, 'Month Sales', formatPaise(d['monthSales'] as int), Icons.calendar_month, '${d['monthCount']} bills'),
                _kpi(context, 'Month Profit', formatPaise(d['monthProfit'] as int), Icons.trending_up),
                _kpi(context, 'Low Stock', '${d['lowStock']}', Icons.warning_amber),
                _kpi(context, 'Out of Stock', '${d['outOfStock']}', Icons.remove_shopping_cart),
              ],
            ),
            const SizedBox(height: 24),
            Text('Recent bills', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...recent.map((b) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.receipt_long),
                  title: Text(b['invoice_no']?.toString() ?? b['id'].toString()),
                  trailing: Text(formatPaise(b['grand_total'] as int)),
                )),
            const SizedBox(height: 16),
            Text('Top selling products', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...top.map((p) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.local_fire_department),
                  title: Text(p['name']?.toString() ?? '-'),
                  subtitle: Text('Qty ${p['qty']}'),
                  trailing: Text(formatPaise((p['revenue'] ?? 0) as int)),
                )),
          ],
        );
      },
    );
  }

  Widget _kpi(BuildContext context, String label, String value, IconData icon, [String? sub]) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(icon, size: 18, color: scheme.primary), const SizedBox(width: 6), Expanded(child: Text(label))]),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              if (sub != null) Text(sub, style: TextStyle(color: scheme.outline, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Simple table tabs ───────────────────────────────────────────────────────
class _SalesTab extends StatelessWidget {
  const _SalesTab();
  @override
  Widget build(BuildContext context) {
    final to = DateTime.now();
    final from = to.subtract(const Duration(days: 30));
    return _Loader<List<Map<String, dynamic>>>(
      future: _api.salesByDay(from, to),
      builder: (context, rows) => _TableView(
        columns: const ['Day', 'Bills', 'Sales', 'Tax'],
        rows: rows.map((r) => [r['day'], r['bills'], formatPaise(r['total'] as int), formatPaise(r['tax'] as int)]).toList(),
        exportName: 'sales.csv',
        exportRows: rows.map((r) => [r['day'], r['bills'], (r['total'] as int) / 100, (r['tax'] as int) / 100]).toList(),
      ),
    );
  }
}

class _GstTab extends StatelessWidget {
  const _GstTab();
  @override
  Widget build(BuildContext context) {
    final to = DateTime.now();
    final from = to.subtract(const Duration(days: 30));
    return _Loader<List<Map<String, dynamic>>>(
      future: _api.gst(from, to),
      builder: (context, rows) => _TableView(
        columns: const ['GST %', 'Taxable', 'CGST', 'SGST', 'IGST'],
        rows: rows
            .map((r) => [
                  '${r['rate']}%',
                  formatPaise(r['taxable'] as int),
                  formatPaise(r['cgst'] as int),
                  formatPaise(r['sgst'] as int),
                  formatPaise(r['igst'] as int),
                ])
            .toList(),
        exportName: 'gst.csv',
        exportRows: rows
            .map((r) => [r['rate'], (r['taxable'] as int) / 100, (r['cgst'] as int) / 100, (r['sgst'] as int) / 100, (r['igst'] as int) / 100])
            .toList(),
      ),
    );
  }
}

class _ProfitTab extends StatelessWidget {
  const _ProfitTab();
  @override
  Widget build(BuildContext context) {
    final to = DateTime.now();
    final from = to.subtract(const Duration(days: 30));
    return _Loader<List<Map<String, dynamic>>>(
      future: _api.profit(from, to),
      builder: (context, rows) => _TableView(
        columns: const ['Product', 'Qty', 'Revenue', 'Cost', 'Profit'],
        rows: rows
            .map((r) => [
                  r['name'],
                  r['qty'],
                  formatPaise((r['revenue'] ?? 0) as int),
                  formatPaise((r['cost'] ?? 0) as int),
                  formatPaise((r['profit'] ?? 0) as int),
                ])
            .toList(),
        exportName: 'profit.csv',
        exportRows: rows
            .map((r) => [r['name'], r['qty'], ((r['revenue'] ?? 0) as int) / 100, ((r['cost'] ?? 0) as int) / 100, ((r['profit'] ?? 0) as int) / 100])
            .toList(),
      ),
    );
  }
}

class _InventoryTab extends StatelessWidget {
  const _InventoryTab();
  @override
  Widget build(BuildContext context) {
    return _Loader<List<Map<String, dynamic>>>(
      future: _api.inventory(),
      builder: (context, rows) => _TableView(
        columns: const ['Product', 'SKU', 'Stock', 'Reorder', 'Buy', 'Sell'],
        rows: rows
            .map((r) => [
                  r['name'],
                  r['sku'] ?? '',
                  r['stock'],
                  r['reorder_level'],
                  formatPaise((r['purchase_price'] ?? 0) as int),
                  formatPaise((r['selling_price'] ?? 0) as int),
                ])
            .toList(),
        exportName: 'inventory.csv',
        exportRows: rows
            .map((r) => [r['name'], r['sku'] ?? '', r['stock'], r['reorder_level'], ((r['purchase_price'] ?? 0) as int) / 100, ((r['selling_price'] ?? 0) as int) / 100])
            .toList(),
      ),
    );
  }
}

class _TableView extends StatelessWidget {
  final List<String> columns;
  final List<List<Object?>> rows;
  final String exportName;
  final List<List<Object?>> exportRows;
  const _TableView({
    required this.columns,
    required this.rows,
    required this.exportName,
    required this.exportRows,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ExportBar(onExport: () => _download(context, exportName, columns, exportRows)),
        Expanded(
          child: rows.isEmpty
              ? const Center(child: Text('No data for this period'))
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
                      rows: rows
                          .map((r) => DataRow(cells: r.map((c) => DataCell(Text('$c'))).toList()))
                          .toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
