// Reusable date-range filter bar for reports. Shows quick presets (Today, 7D,
// 30D, This month) plus a custom range picker. Defaults to today.
import 'package:flutter/material.dart';

/// Today (start of day → same day). Query code should treat the end as the whole
/// end day via [rangeTo].
DateTimeRange todayRange() {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  return DateTimeRange(start: start, end: start);
}

/// Inclusive end-of-day for the range's end date, for backend `to` params.
DateTime rangeTo(DateTimeRange r) =>
    DateTime(r.end.year, r.end.month, r.end.day, 23, 59, 59, 999);

String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}'
    '/${d.month.toString().padLeft(2, '0')}/${d.year}';

class ReportDateBar extends StatelessWidget {
  final DateTimeRange range;
  final ValueChanged<DateTimeRange> onChanged;
  const ReportDateBar({super.key, required this.range, required this.onChanged});

  DateTimeRange _preset(int days) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    return DateTimeRange(start: end.subtract(Duration(days: days - 1)), end: end);
  }

  DateTimeRange _thisMonth() {
    final now = DateTime.now();
    return DateTimeRange(
        start: DateTime(now.year, now.month, 1), end: DateTime(now.year, now.month, now.day));
  }

  Future<void> _pickCustom(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: range,
    );
    if (picked != null) onChanged(picked);
  }

  bool _isSame(DateTimeRange a, DateTimeRange b) =>
      a.start.difference(b.start).inDays == 0 && a.end.difference(b.end).inDays == 0;

  @override
  Widget build(BuildContext context) {
    final presets = <String, DateTimeRange>{
      'Today': todayRange(),
      '7 days': _preset(7),
      '30 days': _preset(30),
      'This month': _thisMonth(),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final e in presets.entries)
            ChoiceChip(
              label: Text(e.key),
              selected: _isSame(range, e.value),
              onSelected: (_) => onChanged(e.value),
            ),
          ActionChip(
            avatar: const Icon(Icons.calendar_today, size: 16),
            label: Text('${_fmt(range.start)} – ${_fmt(range.end)}'),
            onPressed: () => _pickCustom(context),
          ),
        ],
      ),
    );
  }
}
