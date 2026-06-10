import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/product_image.dart';
import '../../data/models/receipt_analysis_model.dart';
import '../../data/services/api_service.dart';
import '../fridge/fridge_screen.dart';

class DetectedProductsScreen extends StatefulWidget {
  const DetectedProductsScreen({super.key, required this.analysis});

  final ReceiptAnalysisModel analysis;

  @override
  State<DetectedProductsScreen> createState() => _DetectedProductsScreenState();
}

class _DetectedProductsScreenState extends State<DetectedProductsScreen> {
  final ApiService _apiService = const ApiService();
  late List<DetectedProductModel> _products;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _products = List<DetectedProductModel>.from(widget.analysis.products);
  }

  double get _selectedProductsTotal {
    return _products.fold<double>(
        0, (total, product) => total + (product.price ?? 0));
  }

  String _numberInputValue(num? value) {
    if (value == null) return '';
    if (value % 1 == 0) return value.toInt().toString();
    return value.toString();
  }

  String _cleanProductTitle(DetectedProductModel product) {
    var title = (product.normalizedName?.trim().isNotEmpty ?? false)
        ? product.normalizedName!.trim()
        : product.name.trim();

    title = title
        .replaceAll(
            RegExp(
                r'\b\d+\s*[xX]\s*\d+([,.]\d+)?\s*(g|kg|ml|l|u|ud|uds|unidades|pcs)?\b',
                caseSensitive: false),
            '')
        .replaceAll(
            RegExp(r'\b\d+([,.]\d+)?\s*(g|kg|ml|l|u|ud|uds|unidades|pcs)\b',
                caseSensitive: false),
            '')
        .replaceAll(RegExp(r'\bpack\s*\d+\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b\d+\s*pack\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[\-·,]+$'), '')
        .trim();

    if (title.isEmpty) return product.name;
    return title;
  }

  InputDecoration _dialogDecoration(String label) {
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _saveProducts() async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay productos para guardar')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _apiService.saveReceiptProducts(
        store: widget.analysis.store,
        products: _products,
        warnings: widget.analysis.warnings,
        rawAiResponse: widget.analysis.rawJson,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Productos guardados en tu nevera')),
      );
      Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FridgeScreen()));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addProduct() async {
    const newProduct = DetectedProductModel(
      name: 'Nuevo producto',
      category: 'other_refrigerated',
      quantity: 1,
      unit: 'ud',
      storageLocation: 'fridge',
      estimatedExpiryDays: 3,
      expiryConfidence: 'medium',
      confidence: 'manual',
    );

    final edited =
        await _showProductDialog(newProduct, title: 'Añadir producto');
    if (edited != null) {
      setState(() => _products.add(edited));
    }
  }

  Future<void> _editProduct(int index) async {
    final updated =
        await _showProductDialog(_products[index], title: 'Editar producto');
    if (updated != null) {
      setState(() => _products[index] = updated);
    }
  }

  Future<DetectedProductModel?> _showProductDialog(DetectedProductModel product,
      {required String title}) async {
    final nameController =
        TextEditingController(text: _cleanProductTitle(product));
    final quantityController =
        TextEditingController(text: _numberInputValue(product.quantity));
    final expiryController = TextEditingController(
        text: _numberInputValue(product.estimatedExpiryDays));
    final priceController =
        TextEditingController(text: product.price?.toStringAsFixed(2) ?? '');

    return showDialog<DetectedProductModel>(
      context: context,
      builder: (context) {
        String category = product.category;
        String storage = product.storageLocation;
        return AlertDialog(
          title: Text(title),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: _dialogDecoration('Nombre'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: _dialogDecoration('Cantidad'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: expiryController,
                    keyboardType: TextInputType.number,
                    decoration: _dialogDecoration('Días hasta caducar'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: _dialogDecoration('Precio añadido (€)'),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    isExpanded: true,
                    decoration: _dialogDecoration('Categoría'),
                    items: const [
                      DropdownMenuItem(value: 'dairy', child: Text('Lácteos')),
                      DropdownMenuItem(value: 'cheese', child: Text('Queso')),
                      DropdownMenuItem(value: 'yogurt', child: Text('Yogur')),
                      DropdownMenuItem(value: 'meat', child: Text('Carne')),
                      DropdownMenuItem(
                          value: 'poultry', child: Text('Pollo / ave')),
                      DropdownMenuItem(value: 'fish', child: Text('Pescado')),
                      DropdownMenuItem(
                          value: 'seafood', child: Text('Marisco')),
                      DropdownMenuItem(value: 'eggs', child: Text('Huevos')),
                      DropdownMenuItem(
                          value: 'refrigerated_ready_meal',
                          child: Text('Plato refrigerado')),
                      DropdownMenuItem(
                          value: 'frozen', child: Text('Congelado')),
                      DropdownMenuItem(
                          value: 'fruit', child: Text('Fruta refrigerada')),
                      DropdownMenuItem(
                          value: 'vegetables',
                          child: Text('Verdura refrigerada')),
                      DropdownMenuItem(
                          value: 'other_refrigerated',
                          child: Text('Otro refrigerado')),
                    ],
                    onChanged: (value) => category = value ?? category,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: storage,
                    isExpanded: true,
                    decoration: _dialogDecoration('Ubicación'),
                    items: const [
                      DropdownMenuItem(value: 'fridge', child: Text('Nevera')),
                      DropdownMenuItem(
                          value: 'freezer', child: Text('Congelador')),
                    ],
                    onChanged: (value) => storage = value ?? storage,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final quantity = double.tryParse(
                        quantityController.text.replaceAll(',', '.')) ??
                    product.quantity;
                final expiryDays = int.tryParse(expiryController.text);
                final price =
                    double.tryParse(priceController.text.replaceAll(',', '.'));
                final name = nameController.text.trim();
                Navigator.of(context).pop(
                  product.copyWith(
                    name: name.isEmpty ? product.name : name,
                    normalizedName: name.isEmpty
                        ? product.normalizedName
                        : name.toLowerCase(),
                    quantity: quantity,
                    category: category,
                    storageLocation: storage,
                    estimatedExpiryDays: expiryDays,
                    price: price,
                    confidence: product.confidence == 'manual'
                        ? 'manual'
                        : product.confidence,
                  ),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _removeProduct(int index) {
    setState(() => _products.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final storeName = widget.analysis.store.name ?? 'Ticket detectado';
    final selectedTotal = _selectedProductsTotal;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Productos detectados'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(22)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(storeName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 16)),
                            const SizedBox(height: 4),
                            const Text('Revisa antes de guardar',
                                style:
                                    TextStyle(color: AppColors.textSecondary)),
                            if (widget.analysis.store.purchaseDate != null)
                              Text(
                                  'Fecha: ${widget.analysis.store.purchaseDate}',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Total añadido',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12)),
                          Text('${selectedTotal.toStringAsFixed(2)} €',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary,
                                  fontSize: 18)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Productos (${_products.length})',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900)),
                      TextButton.icon(
                        onPressed: _addProduct,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Añadir'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (widget.analysis.warnings.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(18)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(widget.analysis.warnings.first,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13))),
                  ],
                ),
              ),
            Expanded(
              child: _products.isEmpty
                  ? const Center(
                      child: Text(
                          'No se detectaron productos de nevera. Puedes añadirlos manualmente.'))
                  : ListView.separated(
                      itemCount: _products.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _products[index];
                        final color = _colorForProduct(item);
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: [
                              ProductImage(category: item.category, size: 44),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_cleanProductTitle(item),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 2),
                                    Text(
                                        '${item.quantityLabel} · ${_storageLabel(item.storageLocation)}',
                                        style: const TextStyle(
                                            color: AppColors.textSecondary)),
                                    Text(item.priceLabel,
                                        style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(item.expiryLabel,
                                      style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.w800)),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                          onPressed: () => _editProduct(index),
                                          icon:
                                              const Icon(Icons.edit_outlined)),
                                      IconButton(
                                          onPressed: () =>
                                              _removeProduct(index),
                                          icon:
                                              const Icon(Icons.close_rounded)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveProducts,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.kitchen_rounded),
                label:
                    Text(_isSaving ? 'Guardando...' : 'Guardar en mi nevera'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _storageLabel(String storage) {
    if (storage == 'freezer') return 'Congelador';
    return 'Nevera';
  }

  Color _colorForProduct(DetectedProductModel product) {
    final days = product.estimatedExpiryDays;
    if (product.storageLocation == 'freezer') return AppColors.secondary;
    if (days == null) return AppColors.secondary;
    if (days <= 2) return AppColors.warning;
    return AppColors.success;
  }
}
