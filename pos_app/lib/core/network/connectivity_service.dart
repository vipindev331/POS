// Thin wrapper over connectivity_plus exposing a simple online/offline stream.
// The sync engine (Part 6) listens to this to drain its outbox when a
// connection returns.
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity;
  final _controller = StreamController<bool>.broadcast();
  bool _online = true;

  ConnectivityService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  bool get isOnline => _online;
  Stream<bool> get onStatusChange => _controller.stream;

  Future<void> init() async {
    _update(await _connectivity.checkConnectivity());
    _connectivity.onConnectivityChanged.listen(_update);
  }

  void _update(List<ConnectivityResult> results) {
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online != _online) {
      _online = online;
      _controller.add(online);
    } else {
      _online = online;
    }
  }

  void dispose() => _controller.close();
}
