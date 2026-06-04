import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../models/product_model.dart';

class ApiService {
  const ApiService();

  Future<List<ProductModel>> fetchProducts({String? status}) async {
    final queryParams = <String, String>{
      'user_id': ApiConstants.demoUserId,
      if (status != null) 'status': status,
    };

    final uri = Uri.parse('${ApiConstants.baseUrl}/products').replace(queryParameters: queryParams);
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Error cargando productos: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final products = decoded['products'] as List<dynamic>? ?? [];
    return products.map((item) => ProductModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<ProductModel> markConsumed(String productId) async {
    return _changeProductStatus(productId, 'consume');
  }

  Future<ProductModel> markWasted(String productId) async {
    return _changeProductStatus(productId, 'waste');
  }

  Future<ProductModel> _changeProductStatus(String productId, String action) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/products/$productId/$action').replace(
      queryParameters: {'user_id': ApiConstants.demoUserId},
    );
    final response = await http.post(uri);

    if (response.statusCode != 200) {
      throw Exception('Error actualizando producto: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return ProductModel.fromJson(decoded['product'] as Map<String, dynamic>);
  }
}
