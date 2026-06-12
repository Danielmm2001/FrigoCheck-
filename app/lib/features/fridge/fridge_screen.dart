import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/product_image.dart';
import '../../data/models/product_model.dart';
import '../../data/models/receipt_analysis_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/inventory_events.dart';

enum _FridgeFilter { all, expiringSoon, consumed, expired }

class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key});

  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen> {
  final ApiService _apiService = const ApiService();
  final TextEditingController _searchController = TextEditingController();
  late Future<List<ProductModel>> _productsFuture;
  _FridgeFilter _selectedFilter = _FridgeFilter.all;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _productsFuture = _apiService.fetchProducts();
    inventoryVersion.addListener(_refreshProducts);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    inventoryVersion.removeListener(_refreshProducts);
    _searchController.dispose();
    super.dispose();
  }

  void _refreshProducts() {
    if (!mounted) return;
    setState(() {
      _productsFuture = _apiService.fetchProducts();
    });
  }

  Future<void> _markConsumed(ProductModel product) async {
    await _runAction(() => _apiService.markConsumed(product.id),
        '${product.name} marcado como consumido');
  }

  Future<void> _markExpired(ProductModel product) async {
    await _runAction(() => _apiService.markExpired(product.id),
        '${product.name} marcado como vencido');
  }

  Future<void> _runAction(
      Future<ProductModel> Function() action, String successMessage) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
      _refreshProducts();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  List<ProductModel> _applyFilters(List<ProductModel> products) {
    Iterable<ProductModel> filtered = products;

    switch (_selectedFilter) {
      case _FridgeFilter.all:
        break;
      case _FridgeFilter.expiringSoon:
        filtered = filtered.where((product) => product.isPending);
        break;
      case _FridgeFilter.consumed:
        filtered = filtered.where((product) => product.status == 'consumed');
        break;
      case _FridgeFilter.expired:
        filtered = filtered.where((product) =>
            product.status == 'wasted' ||
            product.status == 'expired' ||
            product.isExpiredActive);
        break;
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((product) {
        final name = product.name.toLowerCase();
        final normalizedName = product.normalizedName?.toLowerCase() ?? '';
        final category = product.category.toLowerCase();
        return name.contains(_searchQuery) ||
            normalizedName.contains(_searchQuery) ||
            category.contains(_searchQuery);
      });
    }

    return filtered.toList();
  }

  Future<void> _addManualProduct() async {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    final expiryController = TextEditingController(text: '3');
    final priceController = TextEditingController();
    String category = 'other_refrigerated';
    String storage = 'fridge';

    final product = await showDialog<DetectedProductModel>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Añadir producto'),
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
                  decoration:
                      const InputDecoration(labelText: 'Días hasta caducar'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Precio (€)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: const [
                    DropdownMenuItem(value: 'dairy', child: Text('Lácteos')),
                    DropdownMenuItem(value: 'cheese', child: Text('Queso')),
                    DropdownMenuItem(value: 'yogurt', child: Text('Yogur')),
                    DropdownMenuItem(value: 'meat', child: Text('Carne')),
                    DropdownMenuItem(
                        value: 'poultry', child: Text('Pollo / ave')),
                    DropdownMenuItem(value: 'fish', child: Text('Pescado')),
                    DropdownMenuItem(value: 'seafood', child: Text('Marisco')),
                    DropdownMenuItem(value: 'eggs', child: Text('Huevos')),
                    DropdownMenuItem(
                        value: 'refrigerated_ready_meal',
                        child: Text('Plato refrigerado')),
                    DropdownMenuItem(value: 'frozen', child: Text('Congelado')),
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
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: storage,
                  decoration: const InputDecoration(labelText: 'Ubicación'),
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
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                final quantity = double.tryParse(
                        quantityController.text.replaceAll(',', '.')) ??
                    1;
                final expiryDays = int.tryParse(expiryController.text) ?? 3;
                final price =
                    double.tryParse(priceController.text.replaceAll(',', '.'));
                Navigator.of(context).pop(
                  DetectedProductModel(
                    name: name,
                    normalizedName: name.toLowerCase(),
                    category: category,
                    quantity: quantity,
                    unit: 'ud',
                    storageLocation: storage,
                    estimatedExpiryDays: expiryDays,
                    expiryConfidence: 'medium',
                    confidence: 'manual',
                    price: price,
                    notes: 'Añadido manualmente',
                  ),
                );
              },
              child: const Text('Añadir'),
            ),
          ],
        );
      },
    );

    if (product == null) return;

    try {
      await _apiService.saveReceiptProducts(
        store: ReceiptStoreModel(
          name: 'Añadido manualmente',
          purchaseDate: DateTime.now().toIso8601String().split('T').first,
          totalAmount: product.price,
        ),
        products: [product],
        warnings: const [],
        rawAiResponse: {
          'source': 'manual_fridge_add',
          'products': [product.toJson()],
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto añadido a tu nevera')));
      _refreshProducts();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi nevera'),
        actions: [
          IconButton(
            onPressed: _refreshProducts,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Buscar productos...',
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                      label: 'Todos',
                      selected: _selectedFilter == _FridgeFilter.all,
                      onTap: () =>
                          setState(() => _selectedFilter = _FridgeFilter.all)),
                  const SizedBox(width: 8),
                  _FilterChip(
                      label: 'Por vencer',
                      selected: _selectedFilter == _FridgeFilter.expiringSoon,
                      onTap: () => setState(
                          () => _selectedFilter = _FridgeFilter.expiringSoon)),
                  const SizedBox(width: 8),
                  _FilterChip(
                      label: 'Consumidos',
                      selected: _selectedFilter == _FridgeFilter.consumed,
                      onTap: () => setState(
                          () => _selectedFilter = _FridgeFilter.consumed)),
                  const SizedBox(width: 8),
                  _FilterChip(
                      label: 'Vencidos',
                      selected: _selectedFilter == _FridgeFilter.expired,
                      onTap: () => setState(
                          () => _selectedFilter = _FridgeFilter.expired)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: FutureBuilder<List<ProductModel>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _ErrorState(
                        message: snapshot.error.toString(),
                        onRetry: _refreshProducts);
                  }

                  final products = snapshot.data ?? [];
                  final visibleProducts = _applyFilters(products);
                  if (products.isEmpty) {
                    return const _EmptyState();
                  }
                  if (visibleProducts.isEmpty) {
                    return const _EmptyState(
                        message:
                            'No hay productos que coincidan con este filtro.');
                  }

                  return ListView.separated(
                    itemCount: visibleProducts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final product = visibleProducts[index];
                      return _ProductCard(
                        product: product,
                        onConsumed: product.status == 'active'
                            ? () => _markConsumed(product)
                            : null,
                        onExpired: product.status == 'active'
                            ? () => _markExpired(product)
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _addManualProduct,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onConsumed,
    required this.onExpired,
  });

  final ProductModel product;
  final VoidCallback? onConsumed;
  final VoidCallback? onExpired;

  Color get _statusColor {
    if (product.status == 'consumed') return AppColors.success;
    if (product.status == 'wasted' || product.status == 'expired') {
      return AppColors.danger;
    }

    final days = product.daysLeft;
    if (days == null) return AppColors.secondary;
    if (days < 0) return AppColors.danger;
    if (product.isExpiringSoon) return AppColors.warning;
    return AppColors.success;
  }

  String get _statusText {
    if (product.status != 'active') return product.statusLabel;
    final days = product.daysLeft;
    if (days == null) return 'Sin fecha';
    if (days < 0) return 'Vencido';
    if (product.isExpiringSoon) return 'Por revisar';
    return 'En buen estado';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor;
    final isActive = product.status == 'active';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            children: [
              ProductImage(category: product.category, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name,
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text('${product.quantityLabel} · ${product.priceLabel}',
                        style: const TextStyle(color: AppColors.textSecondary)),
                    if (product.notes != null && product.notes!.isNotEmpty)
                      Text(product.notes!,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isActive ? product.daysLabel : product.statusLabel,
                    style: TextStyle(
                        color: statusColor, fontWeight: FontWeight.w900),
                  ),
                  if (isActive)
                    Text(_statusText,
                        style: TextStyle(color: statusColor, fontSize: 12)),
                ],
              ),
            ],
          ),
          if (product.status == 'active') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onConsumed,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Consumido'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onExpired,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Vencido'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 54, color: AppColors.danger),
          const SizedBox(height: 12),
          const Text('No se pudieron cargar los productos',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(
      {this.message = 'Escanea un ticket para añadir productos.'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.kitchen_rounded, size: 64, color: AppColors.primary),
          const SizedBox(height: 12),
          const Text('Tu nevera está vacía',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.onTap, this.selected = false});

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
