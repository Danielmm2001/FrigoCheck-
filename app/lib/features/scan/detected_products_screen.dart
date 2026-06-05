import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
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
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const FridgeScreen()));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _editProduct(int index) async {
    final product = _products[index];
    final nameController = TextEditingController(text: product.name);
    final quantityController = TextEditingController(text: product.quantity.toString());
    final expiryController = TextEditingController(text: product.estimatedExpiryDays?.toString() ?? '');

    final updated = await showDialog<DetectedProductModel>(
      context: context,
      builder: (context) {
        String category = product.category;
        String storage = product.storageLocation;
        return AlertDialog(
          title: const Text('Editar producto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: expiryController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Días hasta caducar'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: const [
                    DropdownMenuItem(value: 'dairy', child: Text('Lácteos')),
                    DropdownMenuItem(value: 'cheese', child: Text('Queso')),
                    DropdownMenuItem(value: 'yogurt', child: Text('Yogur')),
                    DropdownMenuItem(value: 'meat', child: Text('Carne')),
                    DropdownMenuItem(value: 'poultry', child: Text('Pollo / ave')),
                    DropdownMenuItem(value: 'fish', child: Text('Pescado')),
                    DropdownMenuItem(value: 'seafood', child: Text('Marisco')),
                    DropdownMenuItem(value: 'eggs', child: Text('Huevos')),
                    DropdownMenuItem(value: 'refrigerated_ready_meal', child: Text('Plato refrigerado')),
                    DropdownMenuItem(value: 'frozen', child: Text('Congelado')),
                    DropdownMenuItem(value: 'fruit', child: Text('Fruta refrigerada')),
                    DropdownMenuItem(value: 'vegetables', child: Text('Verdura refrigerada')),
                    DropdownMenuItem(value: 'other_refrigerated', child: Text('Otro refrigerado')),
                  ],
                  onChanged: (value) => category = value ?? category,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: storage,
                  decoration: const InputDecoration(labelText: 'Ubicación'),
                  items: const [
                    DropdownMenuItem(value: 'fridge', child: Text('Nevera')),
                    DropdownMenuItem(value: 'freezer', child: Text('Congelador')),
                  ],
                  onChanged: (value) => storage = value ?? storage,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final quantity = double.tryParse(quantityController.text.replaceAll(',', '.')) ?? product.quantity;
                final expiryDays = int.tryParse(expiryController.text);
                Navigator.of(context).pop(
                  product.copyWith(
                    name: nameController.text.trim().isEmpty ? product.name : nameController.text.trim(),
                    quantity: quantity,
                    category: category,
                    storageLocation: storage,
                    estimatedExpiryDays: expiryDays,
                  ),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );

    if (updated != null) {
      setState(() => _products[index] = updated);
    }
  }

  void _removeProduct(int index) {
    setState(() => _products.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final storeName = widget.analysis.store.name ?? 'Ticket detectado';
    final total = widget.analysis.store.totalAmount;

    return Scaffold(
      appBar: AppBar(title: const Text('Productos detectados')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(storeName, style: const TextStyle(fontWeight: FontWeight.w900)),
                        const Text('Revisa, edita o elimina antes de guardar', style: TextStyle(color: AppColors.textSecondary)),
                        if (widget.analysis.store.purchaseDate != null)
                          Text('Fecha: ${widget.analysis.store.purchaseDate}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (total != null)
                    Text('${total.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('Productos de nevera (${_products.length})', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if (widget.analysis.warnings.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.warning.withOpacity(.12), borderRadius: BorderRadius.circular(18)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(child: Text(widget.analysis.warnings.first, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
                  ],
                ),
              ),
            Expanded(
              child: _products.isEmpty
                  ? const Center(child: Text('No se detectaron productos de nevera en este ticket.'))
                  : ListView.separated(
                      itemCount: _products.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _products[index];
                        final color = _colorForProduct(item);
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(14)),
                                child: Icon(_iconForCategory(item.category), color: color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    Text('${item.quantityLabel} · ${_storageLabel(item.storageLocation)}', style: const TextStyle(color: AppColors.textSecondary)),
                                    if (item.normalizedName != null && item.normalizedName != item.name)
                                      Text(item.normalizedName!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(item.expiryLabel, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(onPressed: () => _editProduct(index), icon: const Icon(Icons.edit_outlined)),
                                      IconButton(onPressed: () => _removeProduct(index), icon: const Icon(Icons.close_rounded)),
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
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.kitchen_rounded),
                label: Text(_isSaving ? 'Guardando...' : 'Guardar en mi nevera'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'dairy':
      case 'yogurt':
        return Icons.local_drink_rounded;
      case 'cheese':
        return Icons.breakfast_dining_rounded;
      case 'meat':
      case 'poultry':
      case 'fish':
      case 'seafood':
        return Icons.restaurant_rounded;
      case 'eggs':
        return Icons.egg_alt_rounded;
      case 'fruit':
      case 'vegetables':
        return Icons.eco_rounded;
      case 'frozen':
        return Icons.ac_unit_rounded;
      case 'refrigerated_ready_meal':
        return Icons.ramen_dining_rounded;
      default:
        return Icons.fastfood_rounded;
    }
  }
}
