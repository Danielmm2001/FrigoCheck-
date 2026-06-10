import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.category,
    this.size = 54,
  });

  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final spec = _ProductVisualSpec.forCategory(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * .28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: size * .18,
            offset: Offset(0, size * .06),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: size * .76,
          height: size * .76,
          decoration: BoxDecoration(
            color: spec.color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(size * .22),
          ),
          child: Icon(spec.icon, color: spec.color, size: size * .44),
        ),
      ),
    );
  }
}

class _ProductVisualSpec {
  const _ProductVisualSpec({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  static _ProductVisualSpec forCategory(String category) {
    switch (category) {
      case 'poultry':
        return const _ProductVisualSpec(
            icon: Icons.set_meal_rounded, color: Color(0xFFE85D75));
      case 'meat':
        return const _ProductVisualSpec(
            icon: Icons.lunch_dining_rounded, color: Color(0xFFEF4444));
      case 'fish':
      case 'seafood':
        return const _ProductVisualSpec(
            icon: Icons.water_rounded, color: Color(0xFF38BDF8));
      case 'cheese':
        return const _ProductVisualSpec(
            icon: Icons.category_rounded, color: Color(0xFFF59E0B));
      case 'yogurt':
      case 'dairy':
        return const _ProductVisualSpec(
            icon: Icons.local_drink_rounded, color: Color(0xFF60A5FA));
      case 'eggs':
        return const _ProductVisualSpec(
            icon: Icons.egg_alt_rounded, color: Color(0xFFFBBF24));
      case 'fruit':
        return const _ProductVisualSpec(
            icon: Icons.local_florist_rounded, color: Color(0xFFFB7185));
      case 'vegetables':
        return const _ProductVisualSpec(
            icon: Icons.eco_rounded, color: AppColors.success);
      case 'frozen':
        return const _ProductVisualSpec(
            icon: Icons.ac_unit_rounded, color: AppColors.secondary);
      case 'refrigerated_ready_meal':
        return const _ProductVisualSpec(
            icon: Icons.ramen_dining_rounded, color: Color(0xFF8B5CF6));
      default:
        return const _ProductVisualSpec(
            icon: Icons.fastfood_rounded, color: AppColors.primary);
    }
  }
}
