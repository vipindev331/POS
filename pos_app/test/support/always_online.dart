import 'package:pos_app/core/network/connectivity_service.dart';

/// Test double: always reports online, no connectivity plugin needed.
class AlwaysOnline implements ConnectivityService {
  @override
  bool get isOnline => true;
  @override
  Stream<bool> get onStatusChange => const Stream.empty();
  @override
  Future<void> init() async {}
  @override
  void dispose() {}
}
