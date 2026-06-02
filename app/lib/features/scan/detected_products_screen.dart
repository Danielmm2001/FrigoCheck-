import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../fridge/fridge_screen.dart';

class DetectedProductsScreen extends StatelessWidget {
  const DetectedProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final products = [
      ('Leche semidesnatada', '1 L', '5 días', AppColors.success),
      ('Yogur natural', '125 g', '7 días', AppColors.success),
      ('Pechuga de pollo', '500 g', '1 día', AppColors.warning),
      ('Arándanos', '125 g', '3 días', AppColors.success),
      ('Lechuga', '1 ud', '2 días', AppColors.danger),
    ];

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
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Supermercado Fresco', style: TextStyle(fontWeight: FontWeight.w900)),
                    Text('Ticket detectado · Revisa si hace falta', style: TextStyle(color: AppColors.textSecondary)),
                  ]),
                  Text('23,48 €', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text('Productos', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = products[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(color: item.$4.withOpacity(.12), borderRadius: BorderRadius.circular(14)),
                          child: Icon(Icons.fastfood_rounded, color: item.$4),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(item.$2, style: const TextStyle(color: AppColors.textSecondary)),
                        ])),
                        Text(item.$3, style: TextStyle(color: item.$4, fontWeight: FontWeight.w800)),
                        IconButton(onPressed: () {}, icon: const Icon(Icons.edit_outlined)),
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
}
