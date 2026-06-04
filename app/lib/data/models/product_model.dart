class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    this.normalizedName,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.storageLocation,
    this.purchaseDate,
    this.estimatedExpiryDate,
    required this.expiryConfidence,
    required this.status,
    this.notes,
  });

  final String id;
  final String name;
  final String? normalizedName;
  final String category;
  final double quantity;
  final String unit;
  final String storageLocation;
  final String? purchaseDate;
  final String? estimatedExpiryDate;
  final String expiryConfidence;
  final String status;
  final String? notes;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Producto',
      normalizedName: json['normalized_name']?.toString(),
      category: json['category']?.toString() ?? 'other',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
      unit: json['unit']?.toString() ?? 'ud',
      storageLocation: json['storage_location']?.toString() ?? 'fridge',
      purchaseDate: json['purchase_date']?.toString(),
      estimatedExpiryDate: json['estimated_expiry_date']?.toString(),
      expiryConfidence: json['expiry_confidence']?.toString() ?? 'medium',
      status: json['status']?.toString() ?? 'active',
      notes: json['notes']?.toString(),
    );
  }

  int? get daysLeft {
    if (estimatedExpiryDate == null) return null;
    final expiry = DateTime.tryParse(estimatedExpiryDate!);
    if (expiry == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return expiry.difference(today).inDays;
  }

  String get quantityLabel {
    final cleanQuantity = quantity % 1 == 0 ? quantity.toInt().toString() : quantity.toStringAsFixed(1);
    return '$cleanQuantity $unit';
  }

  String get daysLabel {
    final days = daysLeft;
    if (days == null) return 'Sin fecha';
    if (days < 0) return 'Vencido';
    if (days == 0) return 'Hoy';
    if (days == 1) return '1 día';
    return '$days días';
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return 'Activo';
      case 'consumed':
        return 'Consumido';
      case 'wasted':
        return 'Tirado';
      case 'expired':
        return 'Caducado';
      default:
        return status;
    }
  }
}
