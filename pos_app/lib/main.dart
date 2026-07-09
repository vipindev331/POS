import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/di/injector.dart';
import 'features/auth/presentation/auth_cubit.dart';
import 'features/sync/data/sync_engine.dart';

Future<void> main() async {
  // A guarded zone so background async failures never crash or spam the app.
  // On web, Dio's adapter can surface a failed request (e.g. the periodic sync
  // engine when the backend is unreachable, blocks CORS, or returns an empty
  // body) as an uncaught error in a detached future — outside any caller's
  // try/catch. We log those and carry on; the UI already handles per-call
  // failures with offline fallbacks.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Route framework + platform errors through the same sink.
    FlutterError.onError = (details) => debugPrint('FlutterError: ${details.exceptionAsString()}');
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Uncaught (platform): $error');
      return true; // handled — don't let it propagate as a crash
    };

    await registerCore();
    // Resolve the session in the background; the router shows a splash until then.
    unawaited(sl<AuthCubit>().bootstrap());
    // Kick off background sync (push outbox + pull deltas). Never blocks the UI.
    sl<SyncEngine>().start();
    runApp(const PosApp());
  }, (error, stack) {
    debugPrint('Uncaught (zone): $error');
  });
}
