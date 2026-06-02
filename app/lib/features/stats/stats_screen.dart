import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tu progreso')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pequeñas acciones hoy, menos desperdicio mañana 💚',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 24),
            Row(
              children: const [
                _MetricCard(title: 'Aprovechados', value: '28', icon: Icons.check_circle_rounded, color: AppColors.success),
                SizedBox(width: 12),
                _MetricCard(title: 'Tirados', value: '3', icon: Icons.delete_outline_rounded, color: AppColors.danger),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                _MetricCard(title: 'Racha', value: '6 días', icon: Icons.local_fire_department_rounded, color: AppColors.warning),
                SizedBox(width: 12),
                _MetricCard(title: 'Ahorro', value: '18,40 €', icon: Icons.savings_rounded, color: AppColors.secondary),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Porcentaje aprovechado', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: const [
                          SizedBox(
                            width: 108,
                            height: 108,
                            child: CircularProgressIndicator(
                              value: .90,
                              strokeWidth: 12,
                              color: AppColors.primary,
                              backgroundColor: AppColors.primaryLight,
                            ),
                          ),
                          Text('90%', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
                        ],
                      ),
                      const SizedBox(width: 20),
                      const Expanded(
                        child: Text(
                          '¡Excelente! Estás aprovechando muy bien tus alimentos.',
                          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(24)),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ranking personal', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  SizedBox(height: 10),
                  Text('Nivel 3 · Nevera en control', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                  SizedBox(height: 12),
                  LinearProgressIndicator(value: .6, color: AppColors.primary, backgroundColor: Colors.white),
                  SizedBox(height: 8),
                  Text('120 / 200 pts para el siguiente nivel', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value, required this.icon, required this.color});

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text(title, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
