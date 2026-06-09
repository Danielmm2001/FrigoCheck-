import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../models/product_model.dart';
import '../models/receipt_analysis_model.dart';
import '../models/stats_summary_model.dart';
import 'auth_service.dart';

class ApiService {
  const ApiService({this.authService = const AuthService()});

  final AuthService authService;

  String get _userId => authService.currentUserId;

  Map<String, String> get _headers {
    final token = authService.accessToken;
    return {
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<ProductModel>> fetchProducts({String? status}) async {
    final queryParams = <String, String>{
      'user_id': _userId,
      if (status != null) 'status': status,
    };

    final uri = Uri.parse('${ApiConstants.baseUrl}/products').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('Error cargando productos: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final products = decoded['products'] as List<dynamic>? ?? [];
    return products.map((item) => ProductModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<StatsSummaryModel> fetchStatsSummary() async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/stats/summary').replace(
      queryParameters: {'user_id': _userId},
    );
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('Error cargando estadisticas: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return StatsSummaryModel.fromJson(decoded);
  }

  Future<ReceiptAnalysisModel> analyzeReceiptImage(File imageFile) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/receipts/analyze');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers)
      ..fields['user_id'] = _userId
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Error analizando ticket: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return ReceiptAnalysisModel.fromJson(decoded);
  }

  Future<void> saveReceiptProducts({
    required ReceiptStoreModel store,
    required List<DetectedProductModel> products,
    required List<String> warnings,
    required Map<String, dynamic> rawAiResponse,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/receipts/save');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json', ..._headers},
      body: jsonEncode({
        'user_id': _userId,
        'store': store.toJson(),
        'products': products.map((product) => product.toJson()).toList(),
        'warnings': warnings,
        'raw_ai_response': rawAiResponse,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Error guardando productos: ${response.body}');
    }
  }

  Future<ProductModel> markConsumed(String productId) async {
    return _changeProductStatus(productId, 'consume');
  }

  Future<ProductModel> markWasted(String productId) async {
    return _changeProductStatus(productId, 'waste');
  }

  Future<ProductModel> _changeProductStatus(String productId, String action) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/products/$productId/$action').replace(
      queryParameters: {'user_id': _userId},
    );
    final response = await http.post(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('Error actualizando producto: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return ProductModel.fromJson(decoded['product'] as Map<String, dynamic>);
  }
}
