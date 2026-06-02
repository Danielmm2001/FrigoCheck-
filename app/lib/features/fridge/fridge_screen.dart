import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class FridgeScreen extends StatelessWidget {
  const FridgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final products = [
      ('Arándanos', '125 g', '3 días', 'En buen estado', AppColors.success),
      ('Yogur natural', '125 g', '5 días', 'En buen estado', AppColors.success),
      ('Pechuga de pollo', '500 g', '1 día', 'Por revisar', AppColors.warning),
      ('Huevos', '6 uds', '8 días', 'En buen estado', AppColors.success),
      ('Lechuga', '1 ud', '2 días', 'Pronto caduca', AppColors.danger),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Mi nevera')),
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
              child: ListView.separated(
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = products[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: item.$5.withOpacity(.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.fastfood_rounded, color: item.$5),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.$1, style: const TextStyle(fontWeight: FontWeight.w900)),
                              Text(item.$2, style: const TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(item.$3, style: TextStyle(color: item.$5, fontWeight: FontWeight.w900)),
                            Text(item.$4, style: TextStyle(color: item.$5, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
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
