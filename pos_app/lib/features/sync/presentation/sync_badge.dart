// Compact sync indicator for app bars: shows a spinner while syncing, a pending
// count when the outbox is non-empty, or a check when everything is pushed.
// Tapping forces a sync.
import 'package:flutter/material.dart';

import '../../../core/di/injector.dart';
import '../data/sync_engine.dart';

class SyncBadge extends StatelessWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = sl<SyncEngine>();
    return StreamBuilder<SyncStatus>(
      stream: engine.status.stream,
      initialData: engine.status.value,
      builder: (context, snapshot) {
        final s = snapshot.data ?? const SyncStatus();
        final Widget icon;
        if (s.syncing) {
          icon = const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
        } else if (s.pending > 0) {
          icon = Badge(label: Text('${s.pending}'), child: const Icon(Icons.cloud_upload_outlined));
        } else {
          icon = const Icon(Icons.cloud_done_outlined);
        }
        return IconButton(
          tooltip: s.lastError != null
              ? 'Sync error: ${s.lastError}'
              : s.pending > 0
                  ? '${s.pending} pending — tap to sync'
                  : 'All synced',
          onPressed: () => engine.syncNow(),
          icon: icon,
        );
      },
    );
  }
}
