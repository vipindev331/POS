// Remote endpoints for the sync engine: idempotent op push + delta pull.
import '../../../core/network/dio_client.dart';

class SyncRemoteDataSource {
  final DioClient _client;
  SyncRemoteDataSource(this._client);

  /// Push a batch of outbox operations. Returns the per-op results list.
  Future<List<Map<String, dynamic>>> push(List<Map<String, dynamic>> operations) async {
    final res = await _client.dio.post('/sync/push', data: {'operations': operations});
    return ((res.data['data']?['results']) as List? ?? const []).cast<Map<String, dynamic>>();
  }

  /// Pull rows changed since [since] for [entities]. Returns (serverTime, changes).
  Future<({int serverTime, Map<String, dynamic> changes})> pull({
    required int since,
    required List<String> entities,
  }) async {
    final res = await _client.dio.post('/sync/pull', data: {'since': since, 'entities': entities});
    final data = res.data['data'] as Map<String, dynamic>;
    return (
      serverTime: (data['serverTime'] as num).toInt(),
      changes: (data['changes'] as Map).cast<String, dynamic>(),
    );
  }
}
