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
    this.barcode,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.storageLocation,
    this.estimatedExpiryDays,
    required this.expiryConfidence,
    required this.confidence,
    this.price,
    this.imageUrl,
    this.notes,
  });

  final String name;
  final String? normalizedName;
  final String? barcode;
  final String category;
  final double quantity;
  final String unit;
  final String storageLocation;
  final int? estimatedExpiryDays;
  final String expiryConfidence;
  final String confidence;
  final double? price;
  final String? imageUrl;
  final String? notes;

  factory DetectedProductModel.fromJson(Map<String, dynamic> json) {
    return DetectedProductModel(
      name: json['name']?.toString() ?? 'Producto',
      normalizedName: json['normalized_name']?.toString(),
      barcode: json['barcode']?.toString(),
      category: json['category']?.toString() ?? 'other_refrigerated',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unit: json['unit']?.toString() ?? 'ud',
      storageLocation: json['storage_location']?.toString() ?? 'fridge',
      estimatedExpiryDays: (json['estimated_expiry_days'] as num?)?.toInt(),
      expiryConfidence: json['expiry_confidence']?.toString() ?? 'medium',
      confidence: json['confidence']?.toString() ?? 'medium',
      price: (json['price'] as num?)?.toDouble(),
      imageUrl: json['image_url']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  DetectedProductModel copyWith({
    String? name,
    String? normalizedName,
    String? barcode,
    String? category,
    double? quantity,
    String? unit,
    String? storageLocation,
    int? estimatedExpiryDays,
    String? expiryConfidence,
    String? confidence,
    double? price,
    String? imageUrl,
    String? notes,
  }) {
    return DetectedProductModel(
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      storageLocation: storageLocation ?? this.storageLocation,
      estimatedExpiryDays: estimatedExpiryDays ?? this.estimatedExpiryDays,
      expiryConfidence: expiryConfidence ?? this.expiryConfidence,
      confidence: confidence ?? this.confidence,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'normalized_name': normalizedName,
      'barcode': barcode,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'storage_location': storageLocation,
      'estimated_expiry_days': estimatedExpiryDays,
      'expiry_confidence': expiryConfidence,
      'confidence': confidence,
      'price': price,
      'image_url': imageUrl,
      'notes': notes,
    };
  }

  String get quantityLabel {
    final cleanQuantity = quantity % 1 == 0
        ? quantity.toInt().toString()
        : quantity.toStringAsFixed(1);
    return '$cleanQuantity $unit';
  }

  String get expiryLabel {
    final days = estimatedExpiryDays;
    if (days == null) return 'Sin estimación';
    if (days == 0) return 'Hoy';
    if (days == 1) return '1 día';
    return '$days días';
  }

  String get priceLabel {
    if (price == null) return 'Sin precio';
    return '${price!.toStringAsFixed(2)} €';
  }
}

class BarcodeProductLookupModel {
  const BarcodeProductLookupModel({
    required this.barcode,
    required this.found,
    this.name,
    this.normalizedName,
    this.brand,
    this.category,
    this.quantity,
    this.unit,
    this.storageLocation,
    this.estimatedExpiryDays,
    this.expiryConfidence = 'medium',
    this.imageUrl,
    this.source,
    this.message,
  });

  final String barcode;
  final bool found;
  final String? name;
  final String? normalizedName;
  final String? brand;
  final String? category;
  final double? quantity;
  final String? unit;
  final String? storageLocation;
  final int? estimatedExpiryDays;
  final String expiryConfidence;
  final String? imageUrl;
  final String? source;
  final String? message;

  factory BarcodeProductLookupModel.fromJson(Map<String, dynamic> json) {
    return BarcodeProductLookupModel(
      barcode: json['barcode']?.toString() ?? '',
      found: json['found'] == true,
      name: json['name']?.toString(),
      normalizedName: json['normalized_name']?.toString(),
      brand: json['brand']?.toString(),
      category: json['category']?.toString(),
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit']?.toString(),
      storageLocation: json['storage_location']?.toString(),
      estimatedExpiryDays: (json['estimated_expiry_days'] as num?)?.toInt(),
      expiryConfidence: json['expiry_confidence']?.toString() ?? 'medium',
      imageUrl: json['image_url']?.toString(),
      source: json['source']?.toString(),
      message: json['message']?.toString(),
    );
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
      products: rawProducts
          .map((item) =>
              DetectedProductModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      warnings: rawWarnings.map((item) => item.toString()).toList(),
      rawJson: json,
    );
  }
}
