import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/product_model.dart';
import '../../data/services/api_service.dart';

class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key});

  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen> {
  final ApiService _apiService = const ApiService();
  late Future<List<ProductModel>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _apiService.fetchProducts();
  }

  void _refreshProducts() {
    setState(() {
      _productsFuture = _apiService.fetchProducts();
    });
  }

  Future<void> _markConsumed(ProductModel product) async {
    await _runAction(() => _apiService.markConsumed(product.id), '${product.name} marcado como consumido');
  }

  Future<void> _markWasted(ProductModel product) async {
    await _runAction(() => _apiService.markWasted(product.id), '${product.name} marcado como tirado');
  }

  Future<void> _runAction(Future<ProductModel> Function() action, String successMessage) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
      _refreshProducts();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
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
            const TextField(
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Buscar productos...',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: const [
                _FilterChip(label: 'Todos', selected: true),
                SizedBox(width: 8),
                _FilterChip(label: 'Por vencer'),
                SizedBox(width: 8),
                _FilterChip(label: 'Consumidos'),
              ],
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
                    return _ErrorState(message: snapshot.error.toString(), onRetry: _refreshProducts);
                  }

                  final products = snapshot.data ?? [];
                  if (products.isEmpty) {
                    return const _EmptyState();
                  }

                  return ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return _ProductCard(
                        product: product,
                        onConsumed: product.status == 'active' ? () => _markConsumed(product) : null,
                        onWasted: product.status == 'active' ? () => _markWasted(product) : null,
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
        onPressed: () {},
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onConsumed,
    required this.onWasted,
  });

  final ProductModel product;
  final VoidCallback? onConsumed;
  final VoidCallback? onWasted;

  Color get _statusColor {
    if (product.status == 'consumed') return AppColors.success;
    if (product.status == 'wasted' || product.status == 'expired') return AppColors.danger;

    final days = product.daysLeft;
    if (days == null) return AppColors.secondary;
    if (days < 0) return AppColors.danger;
    if (days <= 2) return AppColors.warning;
    return AppColors.success;
  }

  String get _statusText {
    if (product.status != 'active') return product.statusLabel;
    final days = product.daysLeft;
    if (days == null) return 'Sin fecha';
    if (days < 0) return 'Vencido';
    if (days <= 2) return 'Por revisar';
    return 'En buen estado';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.fastfood_rounded, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(product.quantityLabel, style: const TextStyle(color: AppColors.textSecondary)),
                    if (product.notes != null && product.notes!.isNotEmpty)
                      Text(product.notes!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(product.daysLabel, style: TextStyle(color: statusColor, fontWeight: FontWeight.w900)),
                  Text(_statusText, style: TextStyle(color: statusColor, fontSize: 12)),
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
                    onPressed: onWasted,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Tirado'),
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
          const Icon(Icons.error_outline_rounded, size: 54, color: AppColors.danger),
          const SizedBox(height: 12),
          const Text('No se pudieron cargar los productos', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.kitchen_rounded, size: 64, color: AppColors.primary),
          SizedBox(height: 12),
          Text('Tu nevera está vacía', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          SizedBox(height: 8),
          Text('Escanea un ticket para añadir productos.', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}
