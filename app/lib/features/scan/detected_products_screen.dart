import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/receipt_analysis_model.dart';
import '../fridge/fridge_screen.dart';

class DetectedProductsScreen extends StatelessWidget {
  const DetectedProductsScreen({super.key, required this.analysis});

  final ReceiptAnalysisModel analysis;

  @override
  Widget build(BuildContext context) {
    final products = analysis.products;
    final storeName = analysis.store.name ?? 'Ticket detectado';
    final total = analysis.store.totalAmount;

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
                        const Text('Revisa los productos antes de guardarlos', style: TextStyle(color: AppColors.textSecondary)),
                        if (analysis.store.purchaseDate != null)
                          Text('Fecha: ${analysis.store.purchaseDate}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (total != null)
                    Text('${total.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('Productos (${products.length})', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if (analysis.warnings.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: AppColors.warning.withOpacity(.12), borderRadius: BorderRadius.circular(18)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.warning),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        analysis.warnings.first,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: products.isEmpty
                  ? const Center(
                      child: Text('No se detectaron productos en este ticket.'),
                    )
                  : ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = products[index];
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
                                    Text('${item.quantityLabel} · ${item.storageLocation}', style: const TextStyle(color: AppColors.textSecondary)),
                                    if (item.normalizedName != null && item.normalizedName != item.name)
                                      Text(item.normalizedName!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(item.expiryLabel, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                                  Text(item.confidence, style: TextStyle(color: color, fontSize: 12)),
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
                onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const FridgeScreen())),
                icon: const Icon(Icons.kitchen_rounded),
                label: const Text('Guardar en mi nevera'),
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

  Color _colorForProduct(DetectedProductModel product) {
    final days = product.estimatedExpiryDays;
    if (days == null) return AppColors.secondary;
    if (days <= 2) return AppColors.warning;
    return AppColors.success;
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'dairy':
        return Icons.local_drink_rounded;
      case 'meat':
      case 'fish':
        return Icons.restaurant_rounded;
      case 'fruit':
      case 'vegetables':
        return Icons.eco_rounded;
      case 'frozen':
        return Icons.ac_unit_rounded;
      case 'drinks':
        return Icons.local_cafe_rounded;
      case 'pantry':
        return Icons.inventory_2_rounded;
      default:
        return Icons.fastfood_rounded;
    }
  }
}
