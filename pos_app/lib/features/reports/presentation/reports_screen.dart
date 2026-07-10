// Reports & dashboard. Tabs: Dashboard · Sales · GST · Profit · Inventory.
// Data is computed server-side; each tab exports its table to CSV.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme.dart';
import '../../../core/di/injector.dart';
import '../../../core/export/csv.dart';
import '../../../core/money/tax_engine.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/presentation/auth_cubit.dart';
import '../data/reports_api.dart';
import 'widgets/report_date_bar.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // Shared date range for the tabular tabs. Defaults to today.
  DateTimeRange _range = todayRange();

  @override
  Widget build(BuildContext context) {
    final isManager = context.read<AuthCubit>().state.user?.isManager ?? false;
    final from = _range.start;
    final to = rangeTo(_range);
    // Dashboard & Profit are manager-only on the backend; staff would get a 403.
    final tabs = <Tab>[
      if (isManager) const Tab(text: 'Dashboard'),
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
        body: Column(
          children: [
            // The date filter applies to Sales / GST / Profit (Dashboard shows
            // today+month KPIs; Inventory is a current snapshot).
            ReportDateBar(range: _range, onChanged: (r) => setState(() => _range = r)),
            Expanded(
              child: TabBarView(
                children: [
                  if (isManager) const _DashboardTab(),
                  _SalesTab(from: from, to: to),
                  _GstTab(from: from, to: to),
                  if (isManager) _ProfitTab(from: from, to: to),
                  const _InventoryTab(),
                ],
              ),
            ),
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
          return const AppEmptyState(
            icon: Icons.cloud_off,
            title: 'Could not load report',
            message: 'Reports need a connection to the server. Check your network and try again.',
            isError: true,
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
        final lowStock = d['lowStock'] as int;
        final outOfStock = d['outOfStock'] as int;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _Kpi(
                  label: "Today's Sales",
                  value: formatPaise(d['todaySales'] as int),
                  icon: Icons.today,
                  sub: '${d['todayCount']} bills generated',
                  subIcon: Icons.receipt_long,
                ),
                _Kpi(
                  label: 'Month Sales',
                  value: formatPaise(d['monthSales'] as int),
                  icon: Icons.calendar_month,
                  sub: '${d['monthCount']} bills this month',
                  subIcon: Icons.receipt_long,
                ),
                _Kpi(
                  label: 'Month Profit',
                  value: formatPaise(d['monthProfit'] as int),
                  icon: Icons.payments_outlined,
                  sub: 'On track with goal',
                  subIcon: Icons.trending_up,
                ),
                _Kpi(
                  label: 'Low Stock',
                  value: '$lowStock',
                  icon: Icons.warning_amber,
                  sub: lowStock == 0 ? 'No alerts pending' : 'Needs attention',
                  subIcon: lowStock == 0 ? Icons.check_circle_outline : Icons.error_outline,
                  badge: lowStock == 0 ? 'HEALTHY' : 'ALERT',
                  badgeColor: lowStock == 0 ? AppTheme.accent : const Color(0xFFF87171),
                ),
                _Kpi(
                  label: 'Out of Stock',
                  value: '$outOfStock',
                  icon: Icons.remove_shopping_cart_outlined,
                  sub: outOfStock == 0 ? 'All items available' : 'Restock needed',
                  subIcon: outOfStock == 0 ? Icons.verified_outlined : Icons.error_outline,
                  badge: outOfStock == 0 ? 'GREAT' : 'LOW',
                  badgeColor: outOfStock == 0 ? AppTheme.accent : const Color(0xFFF87171),
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, c) {
                final twoCol = c.maxWidth >= 900;
                final bills = _Panel(
                  title: 'Recent Bills',
                  child: Column(
                    children: [
                      for (final b in recent)
                        _BillRow(
                          id: b['invoice_no']?.toString() ?? b['id'].toString(),
                          amount: formatPaise(b['grand_total'] as int),
                        ),
                      if (recent.isEmpty) const _EmptyRow('No bills yet'),
                    ],
                  ),
                );
                final products = _Panel(
                  title: 'Top Selling Products',
                  child: Column(
                    children: [
                      for (final p in top)
                        _ProductRow(
                          name: p['name']?.toString() ?? '-',
                          qty: '${p['qty']}',
                          revenue: formatPaise((p['revenue'] ?? 0) as int),
                        ),
                      if (top.isEmpty) const _EmptyRow('No sales yet'),
                    ],
                  ),
                );
                if (!twoCol) {
                  return Column(children: [bills, const SizedBox(height: 16), products]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: bills),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: products),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// KPI stat tile matching the Management Suite dashboard style: a tinted icon
/// square, an optional status badge, an uppercase label, a large value, and a
/// captioned sub-note.
class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? sub;
  final IconData? subIcon;
  final String? badge;
  final Color? badgeColor;
  const _Kpi({
    required this.label,
    required this.value,
    required this.icon,
    this.sub,
    this.subIcon,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tint = badgeColor ?? scheme.primary;
    return Container(
      width: 210,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: tint, size: 22),
              ),
              const Spacer(),
              if (badge != null) StatusPill(label: badge!, color: tint),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(color: scheme.onSurface, fontSize: 26, fontWeight: FontWeight.w800),
          ),
          if (sub != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (subIcon != null) ...[
                  Icon(subIcon, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                ],
                Flexible(
                  child: Text(
                    sub!,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Bordered content panel with a header row, used for the dashboard's
/// Recent Bills and Top Selling Products sections.
class _Panel extends StatelessWidget {
  final String title;
  final Widget child;
  const _Panel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => SectionCard(
        title: title,
        childPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: child,
      );
}

class _BillRow extends StatelessWidget {
  final String id;
  final String amount;
  const _BillRow({required this.id, required this.amount});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: scheme.surfaceContainerHighest,
        child: Icon(Icons.receipt_long, size: 16, color: scheme.onSurfaceVariant),
      ),
      title: Text(id, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const StatusPill(label: 'COMPLETED', color: AppTheme.accent),
          const SizedBox(width: 14),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final String name;
  final String qty;
  final String revenue;
  const _ProductRow({required this.name, required this.qty, required this.revenue});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 15,
        height: 15,
        decoration: BoxDecoration(color: const Color.fromARGB(255, 193, 206, 217), borderRadius: BorderRadius.circular(83)),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text('Qty: $qty units',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
      trailing: Text(revenue,
          style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 14)),
    );
  }
}

class _EmptyRow extends StatelessWidget {
  final String text;
  const _EmptyRow(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
            child: Text(text,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
      );
}

// ── Simple table tabs ───────────────────────────────────────────────────────
class _SalesTab extends StatelessWidget {
  final DateTime from;
  final DateTime to;
  const _SalesTab({required this.from, required this.to});
  @override
  Widget build(BuildContext context) {
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
  final DateTime from;
  final DateTime to;
  const _GstTab({required this.from, required this.to});
  @override
  Widget build(BuildContext context) {
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
  final DateTime from;
  final DateTime to;
  const _ProfitTab({required this.from, required this.to});
  @override
  Widget build(BuildContext context) {
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
              ? const AppEmptyState(
                  icon: Icons.bar_chart_outlined,
                  title: 'No data',
                  message: 'There is nothing to show for the selected period.',
                )
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
