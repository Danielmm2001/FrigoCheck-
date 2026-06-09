import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/product_model.dart';
import '../../data/models/stats_summary_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/auth_service.dart';
import '../fridge/fridge_screen.dart';
import '../scan/scan_ticket_screen.dart';
import '../stats/stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = const ApiService();
  final _auth = const AuthService();
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final products = await _api.fetchProducts();
    final stats = await _api.fetchStatsSummary();
    final active = products.where((p) => p.status == 'active').toList()
      ..sort((a, b) => (a.daysLeft ?? 9999).compareTo(b.daysLeft ?? 9999));
    return _HomeData(active, stats);
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (context, snapshot) {
            final data = snapshot.data ?? _HomeData.empty;
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hola, Dani', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                            SizedBox(height: 4),
                            Text('Asi esta tu nevera hoy', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(onPressed: _signOut, icon: const Icon(Icons.person_rounded)),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      _Metric(label: 'Activos', value: data.stats.activeCount.toString(), color: AppColors.success, icon: Icons.kitchen_rounded),
                      const SizedBox(width: 10),
                      _Metric(label: 'Por revisar', value: data.stats.expiringSoonCount.toString(), color: AppColors.warning, icon: Icons.schedule_rounded),
                      const SizedBox(width: 10),
                      _Metric(label: 'Vencidos', value: data.stats.expiredActiveCount.toString(), color: AppColors.danger, icon: Icons.warning_rounded),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 58,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanTicketScreen())),
                      icon: const Icon(Icons.document_scanner_rounded),
                      label: const Text('Escanear ticket'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tu nevera', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FridgeScreen())), child: const Text('Ver todo')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                  else if (snapshot.hasError)
                    _Notice(text: 'No se pudo cargar la nevera. Revisa backend, IP y Supabase.', icon: Icons.error_outline_rounded, color: AppColors.danger, onRetry: _refresh)
                  else if (data.products.isEmpty)
                    const _Notice(text: 'Aun no hay productos activos. Escanea un ticket o anade uno manualmente.', icon: Icons.kitchen_rounded, color: AppColors.primary)
                  else
                    ...data.products.take(4).map((p) => _ProductTile(product: p)),
                  const SizedBox(height: 18),
                  _Notice(
                    text: '${data.stats.usagePercentage}% aprovechado. Ahorro estimado: ${data.stats.estimatedSavings.toStringAsFixed(2)} EUR.',
                    icon: Icons.insights_rounded,
                    color: AppColors.primary,
                  ),
                ],
              ),
            );
          },
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
          NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: 'Stats'),
        ],
      ),
    );
  }
}

class _HomeData {
  const _HomeData(this.products, this.stats);
  final List<ProductModel> products;
  final StatsSummaryModel stats;
  static const empty = _HomeData(<ProductModel>[], StatsSummaryModel.empty);
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.color, required this.icon});
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

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});
  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final days = product.daysLeft;
    final color = days == null ? AppColors.secondary : days < 0 ? AppColors.danger : days <= 2 ? AppColors.warning : AppColors.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        Icon(Icons.fastfood_rounded, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w800))),
        Text(product.daysLabel, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.icon, required this.color, this.onRetry});
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
        if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ]),
    );
  }
}
