// Remote product data source (backend REST). Used to refresh the local Drift
// cache; the billing hot path always reads local first.
import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';

class ProductsRemoteDataSource {
  final DioClient _client;
  ProductsRemoteDataSource(this._client);

  Future<List<Map<String, dynamic>>> fetchAll({int limit = 500}) async {
    final res = await _client.dio.get('/products', queryParameters: {'limit': limit});
    final data = (res.data['data'] as List).cast<Map<String, dynamic>>();
    return data;
  }

  Future<Map<String, dynamic>?> byBarcode(String barcode) async {
    final res = await _client.dio.get(
      '/products/barcode/$barcode',
      options: Options(validateStatus: (s) => s != null && s < 500),
    );
    if (res.statusCode == 200) return res.data['data'] as Map<String, dynamic>;
    return null;
  }
}
