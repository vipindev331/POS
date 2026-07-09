// Reports data source. Reports are computed server-side (authoritative,
// cross-terminal) and require connectivity; screens surface an offline notice
// when unreachable.
import '../../../core/network/dio_client.dart';

class ReportsApi {
  final DioClient _client;
  ReportsApi(this._client);

  Map<String, dynamic> _range(DateTime from, DateTime to) => {
        'from': from.millisecondsSinceEpoch,
        'to': to.millisecondsSinceEpoch,
      };

  Future<Map<String, dynamic>> dashboard() async {
    final res = await _client.dio.get('/reports/dashboard');
    return (res.data['data'] as Map).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> salesByDay(DateTime from, DateTime to) async {
    final res = await _client.dio.get('/reports/sales', queryParameters: _range(from, to));
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> gst(DateTime from, DateTime to) async {
    final res = await _client.dio.get('/reports/gst', queryParameters: _range(from, to));
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> profit(DateTime from, DateTime to) async {
    final res = await _client.dio.get('/reports/profit', queryParameters: _range(from, to));
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> inventory() async {
    final res = await _client.dio.get('/reports/inventory');
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }
}
