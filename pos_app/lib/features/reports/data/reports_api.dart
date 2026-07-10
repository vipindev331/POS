// Reports data source. Reports are computed server-side (authoritative,
// cross-terminal) and require connectivity; screens surface an offline notice
// when unreachable.
import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';

class ReportsApi {
  final DioClient _client;
  ReportsApi(this._client);

  Map<String, dynamic> _range(DateTime from, DateTime to) => {
        'from': from.millisecondsSinceEpoch,
        'to': to.millisecondsSinceEpoch,
      };

  // The shared Dio client treats <500 as non-throwing (so the auth refresh flow
  // can see 401s). Turn a non-200 into a clear error instead of a null cast.
  Object _payload(Response res) {
    if (res.statusCode == 200 && res.data is Map && res.data['data'] != null) {
      return res.data['data'] as Object;
    }
    if (res.statusCode == 403) {
      throw Exception('You do not have permission to view this report.');
    }
    throw Exception('Server returned ${res.statusCode}.');
  }

  Future<Map<String, dynamic>> dashboard() async {
    final res = await _client.dio.get('/reports/dashboard');
    return (_payload(res) as Map).cast<String, dynamic>();
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

  /// Sold products aggregated over a date range (product, qty, revenue, bills).
  Future<List<Map<String, dynamic>>> soldProducts(DateTime from, DateTime to) async {
    final res = await _client.dio.get('/reports/sold', queryParameters: _range(from, to));
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }

  /// Individual sale lines for one product in a date range.
  Future<List<Map<String, dynamic>>> soldProductDetail(
      String productId, DateTime from, DateTime to) async {
    final res = await _client.dio
        .get('/reports/sold/$productId', queryParameters: _range(from, to));
    return (res.data['data'] as List).cast<Map<String, dynamic>>();
  }
}
