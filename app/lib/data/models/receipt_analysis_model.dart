class ReceiptStoreModel {
  const ReceiptStoreModel({
    this.name,
    this.purchaseDate,
    this.totalAmount,
  });

  final String? name;
  final String? purchaseDate;
  final double? totalAmount;

  factory ReceiptStoreModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ReceiptStoreModel();
    return ReceiptStoreModel(
      name: json['name']?.toString(),
      purchaseDate: json['purchase_date']?.toString(),
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'purchase_date': purchaseDate,
      'total_amount': totalAmount,
    };
  }
}

class DetectedProductModel {
  const DetectedProductModel({
    required this.name,
    this.normalizedName,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.storageLocation,
    this.estimatedExpiryDays,
    required this.expiryConfidence,
    required this.confidence,
    this.notes,
  });

  final String name;
  final String? normalizedName;
  final String category;
  final double quantity;
  final String unit;
  final String storageLocation;
  final int? estimatedExpiryDays;
  final String expiryConfidence;
  final String confidence;
  final String? notes;

  factory DetectedProductModel.fromJson(Map<String, dynamic> json) {
    return DetectedProductModel(
      name: json['name']?.toString() ?? 'Producto',
      normalizedName: json['normalized_name']?.toString(),
      category: json['category']?.toString() ?? 'other_refrigerated',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unit: json['unit']?.toString() ?? 'ud',
      storageLocation: json['storage_location']?.toString() ?? 'fridge',
      estimatedExpiryDays: (json['estimated_expiry_days'] as num?)?.toInt(),
      expiryConfidence: json['expiry_confidence']?.toString() ?? 'medium',
      confidence: json['confidence']?.toString() ?? 'medium',
      notes: json['notes']?.toString(),
    );
  }

  DetectedProductModel copyWith({
    String? name,
    String? normalizedName,
    String? category,
    double? quantity,
    String? unit,
    String? storageLocation,
    int? estimatedExpiryDays,
    String? expiryConfidence,
    String? confidence,
    String? notes,
  }) {
    return DetectedProductModel(
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      storageLocation: storageLocation ?? this.storageLocation,
      estimatedExpiryDays: estimatedExpiryDays ?? this.estimatedExpiryDays,
      expiryConfidence: expiryConfidence ?? this.expiryConfidence,
      confidence: confidence ?? this.confidence,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'normalized_name': normalizedName,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'storage_location': storageLocation,
      'estimated_expiry_days': estimatedExpiryDays,
      'expiry_confidence': expiryConfidence,
      'confidence': confidence,
      'notes': notes,
    };
  }

  String get quantityLabel {
    final cleanQuantity = quantity % 1 == 0 ? quantity.toInt().toString() : quantity.toStringAsFixed(1);
    return '$cleanQuantity $unit';
  }

  String get expiryLabel {
    final days = estimatedExpiryDays;
    if (days == null) return 'Sin estimación';
    if (days == 0) return 'Hoy';
    if (days == 1) return '1 día';
    return '$days días';
  }
}

class ReceiptAnalysisModel {
  const ReceiptAnalysisModel({
    required this.store,
    required this.products,
    required this.warnings,
    required this.rawJson,
  });

  final ReceiptStoreModel store;
  final List<DetectedProductModel> products;
  final List<String> warnings;
  final Map<String, dynamic> rawJson;

  factory ReceiptAnalysisModel.fromJson(Map<String, dynamic> json) {
    final rawProducts = json['products'] as List<dynamic>? ?? [];
    final rawWarnings = json['warnings'] as List<dynamic>? ?? [];

    return ReceiptAnalysisModel(
      store: ReceiptStoreModel.fromJson(json['store'] as Map<String, dynamic>?),
      products: rawProducts.map((item) => DetectedProductModel.fromJson(item as Map<String, dynamic>)).toList(),
      warnings: rawWarnings.map((item) => item.toString()).toList(),
      rawJson: json,
    );
  }
}
