import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/product_image.dart';
import '../../data/models/product_model.dart';
import '../../data/models/receipt_analysis_model.dart';
import '../../data/services/api_service.dart';
import '../fridge/fridge_screen.dart';

class DetectedProductsScreen extends StatefulWidget {
  const DetectedProductsScreen({
    super.key,
    required this.analysis,
    this.onProductsSaved,
  });

  final ReceiptAnalysisModel analysis;
  final VoidCallback? onProductsSaved;

  @override
  State<DetectedProductsScreen> createState() => _DetectedProductsScreenState();
}

class _DetectedProductsScreenState extends State<DetectedProductsScreen> {
  final ApiService _apiService = const ApiService();
  final ImagePicker _imagePicker = ImagePicker();
  late List<DetectedProductModel> _products;
  bool _isSaving = false;
  int? _barcodeLoadingIndex;
  bool _isExpiryScanLoading = false;

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
      if (widget.onProductsSaved != null) {
        widget.onProductsSaved!();
        Navigator.of(context).pop();
      } else {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const FridgeScreen()));
      }
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

  Future<void> _scanBarcodeForProduct(int index) async {
    final barcode = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _BarcodeScannerScreen()),
    );
    if (barcode == null || barcode.trim().isEmpty) return;
    if (!mounted) return;

    setState(() => _barcodeLoadingIndex = index);
    try {
      final lookup = await _apiService.lookupBarcode(barcode);
      if (!mounted) return;

      if (!lookup.found) {
        setState(() {
          _products[index] = _products[index].copyWith(barcode: barcode);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lookup.message ?? 'No he encontrado ese producto'),
          ),
        );
        return;
      }

      setState(() {
        _products[index] = _mergeBarcodeLookup(_products[index], lookup);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${lookup.name ?? 'Producto'} actualizado')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _barcodeLoadingIndex = null);
    }
  }

  Future<void> _scanExpiryDateIntoField({
    required TextEditingController expiryController,
    required TextEditingController nameController,
    required void Function(String value) onConfidenceChanged,
  }) async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (image == null) return;
    if (!mounted) return;

    setState(() => _isExpiryScanLoading = true);
    try {
      final result = await _apiService.analyzeExpiryDateImage(
        imageFile: File(image.path),
        productName: nameController.text,
      );
      if (!mounted) return;

      final days = result.daysLeft;
      if (days == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('No he podido leer una fecha clara. Prueba con más luz.'),
          ),
        );
        return;
      }

      expiryController.text = days < 0 ? '0' : days.toString();
      onConfidenceChanged(result.confidence == 'high' ? 'high' : 'medium');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.expiryDate == null
                ? 'Caducidad actualizada'
                : 'Caducidad detectada: ${result.expiryDate}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isExpiryScanLoading = false);
    }
  }

  DetectedProductModel _mergeBarcodeLookup(
    DetectedProductModel product,
    BarcodeProductLookupModel lookup,
  ) {
    final currentTitle = _cleanProductTitle(product);
    final lookupTitle = (lookup.name ?? '').trim();
    final mergedName = _shouldUseLookupName(currentTitle, lookupTitle)
        ? lookupTitle
        : currentTitle;

    return product.copyWith(
      name: mergedName.isEmpty ? product.name : mergedName,
      normalizedName: mergedName.isEmpty
          ? product.normalizedName
          : mergedName.toLowerCase(),
      barcode: lookup.barcode,
      category: lookup.category ?? product.category,
      quantity: lookup.quantity ?? product.quantity,
      unit: lookup.unit ?? product.unit,
      storageLocation: lookup.storageLocation ?? product.storageLocation,
      estimatedExpiryDays:
          lookup.estimatedExpiryDays ?? product.estimatedExpiryDays,
      expiryConfidence: lookup.estimatedExpiryDays == null
          ? product.expiryConfidence
          : lookup.expiryConfidence,
      confidence: 'barcode',
      price: product.price,
      imageUrl: lookup.imageUrl ?? product.imageUrl,
    );
  }

  bool _shouldUseLookupName(String currentTitle, String lookupTitle) {
    final current = currentTitle.trim();
    final lookup = lookupTitle.trim();
    if (lookup.isEmpty) return false;
    if (current.isEmpty) return true;

    final currentQuality = _nameQualityScore(current);
    final lookupQuality = _nameQualityScore(lookup);
    return lookupQuality > currentQuality + 1;
  }

  int _nameQualityScore(String value) {
    final normalized = value.toLowerCase().trim();
    if (normalized.isEmpty) return 0;

    var score = 0;
    final words = normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 1)
        .toList();
    score += words.length * 2;
    score += normalized.length > 8 ? 2 : 0;
    score += normalized.contains(RegExp(r'\b(nuevo|producto)\b')) ? -6 : 0;
    score += normalized.contains(RegExp(r'\bqued[oó]\b')) ? -8 : 0;
    score += normalized.contains(
            RegExp(r'\bqueso|pollo|yogur|yogurt|leche|carne|pescado|huevo\b'))
        ? 4
        : 0;
    return score;
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
        String expiryConfidence = product.expiryConfidence;
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
                    decoration:
                        _dialogDecoration('Días hasta caducar').copyWith(
                      suffixIcon: IconButton(
                        tooltip: 'Escanear fecha',
                        onPressed: _isExpiryScanLoading
                            ? null
                            : () => _scanExpiryDateIntoField(
                                  expiryController: expiryController,
                                  nameController: nameController,
                                  onConfidenceChanged: (value) {
                                    expiryConfidence = value;
                                  },
                                ),
                        icon: _isExpiryScanLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.event_available_rounded),
                      ),
                    ),
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
                    expiryConfidence: expiryConfidence,
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
                              ProductImage(
                                category: item.category,
                                imageUrl: item.imageUrl,
                                size: 52,
                              ),
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
                                        tooltip: 'Escanear codigo',
                                        onPressed: _barcodeLoadingIndex == null
                                            ? () =>
                                                _scanBarcodeForProduct(index)
                                            : null,
                                        icon: _barcodeLoadingIndex == index
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.qr_code_scanner_rounded,
                                                color: AppColors.primary,
                                              ),
                                      ),
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
    if (days >= 0 && days <= ProductModel.expiryWarningDays) {
      return AppColors.warning;
    }
    return AppColors.success;
  }
}

class _BarcodeScannerScreen extends StatefulWidget {
  const _BarcodeScannerScreen();

  @override
  State<_BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<_BarcodeScannerScreen> {
  late final MobileScannerController _controller;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      formats: const [
        BarcodeFormat.ean8,
        BarcodeFormat.ean13,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) {
    if (_completed) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code == null || code.trim().isEmpty) continue;
      _completed = true;
      Navigator.of(context).pop(code.trim());
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear codigo'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetection,
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .48),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Text(
                      'Coloca el codigo dentro del marco',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  AspectRatio(
                    aspectRatio: 1.55,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Cancelar'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton.filled(
                        onPressed: () => _controller.toggleTorch(),
                        icon: const Icon(Icons.flash_on_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
