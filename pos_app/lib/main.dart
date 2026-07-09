import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/di/injector.dart';
import 'features/sync/data/sync_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await registerCore();
  // Kick off background sync (push outbox + pull deltas). Never blocks the UI.
  sl<SyncEngine>().start();
  runApp(const PosApp());
}
