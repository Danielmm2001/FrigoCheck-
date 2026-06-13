import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../models/daily_stats_model.dart';
import '../models/product_model.dart';
import '../models/receipt_analysis_model.dart';
import '../models/stats_summary_model.dart';
import 'auth_service.dart';
import 'inventory_events.dart';

class ApiService {
  const ApiService({this.authService = const AuthService()});

  final AuthService authService;

  Map<String, String> get _headers {
    final token = authService.accessToken;
    return {
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<ProductModel>> fetchProducts({String? status}) async {
    final queryParams = <String, String>{
      if (status != null) 'status': status,
    };

    final uri = Uri.parse('${ApiConstants.baseUrl}/products')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('Error cargando productos: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final products = decoded['products'] as List<dynamic>? ?? [];
    return products
        .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<EmailStatusResult> checkEmailStatus(String email) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/auth/email-status');
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (response.statusCode != 200) {
      throw Exception('Error comprobando correo: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return EmailStatusResult.fromJson(decoded);
  }

  Future<StatsSummaryModel> fetchStatsSummary() async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/stats/summary').replace(
      queryParameters: const {},
    );
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('Error cargando estadisticas: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return StatsSummaryModel.fromJson(decoded);
  }

  Future<DailyStatsModel> fetchDailyStats(
      {required int year, required int month}) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/stats/daily').replace(
      queryParameters: {
        'year': year.toString(),
        'month': month.toString(),
      },
    );
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('Error cargando grafica: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return DailyStatsModel.fromJson(decoded);
  }

  Future<BarcodeProductLookupModel> lookupBarcode(String barcode) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/products/barcode/$barcode');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('Error buscando producto: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return BarcodeProductLookupModel.fromJson(
      decoded['product'] as Map<String, dynamic>,
    );
  }

  Future<ReceiptAnalysisModel> analyzeReceiptImage(File imageFile) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/receipts/analyze');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers)
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Error analizando ticket: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return ReceiptAnalysisModel.fromJson(decoded);
  }

  Future<ExpiryDateScanResult> analyzeExpiryDateImage({
    required File imageFile,
    String? productName,
  }) async {
    final uri =
        Uri.parse('${ApiConstants.baseUrl}/receipts/expiry-date/analyze');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers);
    if (productName != null && productName.trim().isNotEmpty) {
      request.fields['product_name'] = productName.trim();
    }
    request.files
        .add(await http.MultipartFile.fromPath('image', imageFile.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Error leyendo caducidad: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return ExpiryDateScanResult.fromJson(decoded);
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
        'store': store.toJson(),
        'products': products.map((product) => product.toJson()).toList(),
        'warnings': warnings,
        'raw_ai_response': rawAiResponse,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Error guardando productos: ${response.body}');
    }

    notifyInventoryChanged();
  }

  Future<ProductModel> markConsumed(String productId) async {
    return _changeProductStatus(productId, 'consume');
  }

  Future<ProductModel> markWasted(String productId) async {
    return _changeProductStatus(productId, 'waste');
  }

  Future<ProductModel> markExpired(String productId) async {
    return _changeProductStatus(productId, 'expire');
  }

  Future<ProductModel> _changeProductStatus(
      String productId, String action) async {
    final uri =
        Uri.parse('${ApiConstants.baseUrl}/products/$productId/$action');
    final response = await http.post(uri, headers: _headers);

    if (response.statusCode != 200) {
      throw Exception('Error actualizando producto: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final product =
        ProductModel.fromJson(decoded['product'] as Map<String, dynamic>);
    notifyInventoryChanged();
    return product;
  }
}

class EmailStatusResult {
  const EmailStatusResult({
    required this.exists,
    required this.confirmed,
  });

  final bool exists;
  final bool confirmed;

  factory EmailStatusResult.fromJson(Map<String, dynamic> json) {
    return EmailStatusResult(
      exists: json['exists'] == true,
      confirmed: json['confirmed'] == true,
    );
  }
}

class ExpiryDateScanResult {
  const ExpiryDateScanResult({
    this.expiryDate,
    this.daysLeft,
    this.rawText,
    this.confidence = 'low',
    this.reason,
  });

  final String? expiryDate;
  final int? daysLeft;
  final String? rawText;
  final String confidence;
  final String? reason;

  factory ExpiryDateScanResult.fromJson(Map<String, dynamic> json) {
    return ExpiryDateScanResult(
      expiryDate: json['expiry_date']?.toString(),
      daysLeft: (json['days_left'] as num?)?.toInt(),
      rawText: json['raw_text']?.toString(),
      confidence: json['confidence']?.toString() ?? 'low',
      reason: json['reason']?.toString(),
    );
  }
}
