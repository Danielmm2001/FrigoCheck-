import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../scan/scan_ticket_screen.dart';
import '../fridge/fridge_screen.dart';
import '../stats/stats_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hola, Dani 👋', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                      SizedBox(height: 4),
                      Text('Así está tu nevera hoy', style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.person_rounded, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: const [
                  _SummaryCard(label: 'En buen estado', value: '12', color: AppColors.success, icon: Icons.check_circle),
                  SizedBox(width: 10),
                  _SummaryCard(label: 'Por revisar', value: '3', color: AppColors.warning, icon: Icons.schedule),
                  SizedBox(width: 10),
                  _SummaryCard(label: 'Caducan pronto', value: '2', color: AppColors.danger, icon: Icons.warning_rounded),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanTicketScreen())),
                  icon: const Icon(Icons.document_scanner_rounded),
                  label: const Text('Escanear ticket'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tu nevera', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FridgeScreen())),
                    child: const Text('Ver todo'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const _ProductRow(name: 'Arándanos', subtitle: '125 g', days: '3 días', status: 'En buen estado', color: AppColors.success, icon: Icons.eco_rounded),
              const _ProductRow(name: 'Pechuga de pollo', subtitle: '500 g', days: '1 día', status: 'Por revisar', color: AppColors.warning, icon: Icons.restaurant_rounded),
              const _ProductRow(name: 'Lechuga', subtitle: '1 ud', days: '2 días', status: 'Pronto caduca', color: AppColors.danger, icon: Icons.spa_rounded),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(22)),
                child: const Row(
                  children: [
                    Icon(Icons.notifications_active_rounded, color: AppColors.primary),
                    SizedBox(width: 12),
                    Expanded(child: Text('2 productos vencen pronto. Revísalos para evitar desperdicios.', style: TextStyle(fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanTicketScreen()));
          if (index == 2) Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FridgeScreen()));
          if (index == 3) Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StatsScreen()));
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.document_scanner_rounded), label: 'Escanear'),
          NavigationDestination(icon: Icon(Icons.kitchen_rounded), label: 'Nevera'),
          NavigationDestination(icon: Icon(Icons.person_rounded), label: 'Perfil'),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, required this.color, required this.icon});
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.name, required this.subtitle, required this.days, required this.status, required this.color, required this.icon});
  final String name;
  final String subtitle;
  final String days;
  final String status;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w800)), Text(subtitle, style: const TextStyle(color: AppColors.textSecondary))])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(days, style: TextStyle(color: color, fontWeight: FontWeight.w800)), Text(status, style: TextStyle(color: color, fontSize: 12))]),
      ]),
    );
  }
}
