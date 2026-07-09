import 'package:flutter/material.dart';

/// A titled scaffold used by feature sections. During incremental delivery,
/// sections not yet built show a clear "arriving in Part N" note rather than
/// fake data.
class SectionScaffold extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget body;
  const SectionScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: body,
    );
  }
}

class ComingInPart extends StatelessWidget {
  final int part;
  final String feature;
  const ComingInPart({super.key, required this.part, required this.feature});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.construction, size: 48, color: scheme.outline),
          const SizedBox(height: 12),
          Text('$feature UI', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Delivered in Part $part', style: TextStyle(color: scheme.outline)),
        ],
      ),
    );
  }
}
