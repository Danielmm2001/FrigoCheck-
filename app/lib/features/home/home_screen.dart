import 'package:flutter/material.dart';

import '../../core/navigation/app_route_observer.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/product_image.dart';
import '../../data/models/product_model.dart';
import '../../data/models/stats_summary_model.dart';
import '../../data/services/api_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/inventory_events.dart';
import '../main/main_tabs.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, RouteAware {
  final _api = const ApiService();
  final _auth = const AuthService();
  late Future<_HomeData> _future;
  bool _routeSubscribed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    inventoryVersion.addListener(_refresh);
    _future = _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!_routeSubscribed && route is PageRoute<dynamic>) {
      appRouteObserver.subscribe(this, route);
      _routeSubscribed = true;
    }
  }

  @override
  void dispose() {
    if (_routeSubscribed) {
      appRouteObserver.unsubscribe(this);
    }
    WidgetsBinding.instance.removeObserver(this);
    inventoryVersion.removeListener(_refresh);
    super.dispose();
  }

  @override
  void didPush() => _refresh();

  @override
  void didPopNext() => _refresh();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refresh();
    }
  }

  Future<_HomeData> _load() async {
    final products = await _api.fetchProducts();
    StatsSummaryModel stats = StatsSummaryModel.empty;
    Object? statsError;
    try {
      stats = await _api.fetchStatsSummary();
    } catch (error) {
      statsError = error;
    }
    final visibleProducts = products.where((p) => p.isPending).toList()
      ..sort((a, b) => (a.daysLeft ?? 9999).compareTo(b.daysLeft ?? 9999));
    return _HomeData(
        products: products,
        visibleProducts: visibleProducts,
        stats: stats,
        statsError: statsError);
  }

  Future<void> _refresh() {
    if (!mounted) return Future.value();
    final nextLoad = _load();
    setState(() {
      _future = nextLoad;
    });
    return nextLoad.then<void>((_) {}, onError: (_) {});
  }

  Future<void> _signOut() async {
    await _auth.signOut();
  }

  Future<void> _handleProfileAction(_ProfileAction action) async {
    switch (action) {
      case _ProfileAction.signOut:
        await _signOut();
        break;
    }
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
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Hola, Dani',
                                style: TextStyle(
                                    fontSize: 28, fontWeight: FontWeight.w900)),
                            SizedBox(height: 4),
                            Text('Asi esta tu nevera hoy',
                                style:
                                    TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      PopupMenuButton<_ProfileAction>(
                        tooltip: 'Perfil',
                        onSelected: _handleProfileAction,
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _ProfileAction.signOut,
                            child: Row(
                              children: [
                                Icon(Icons.logout_rounded),
                                SizedBox(width: 10),
                                Text('Cerrar sesion'),
                              ],
                            ),
                          ),
                        ],
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(Icons.person_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      _Metric(
                          label: 'En nevera',
                          value: data.activeCount.toString(),
                          color: AppColors.success,
                          icon: Icons.kitchen_rounded),
                      const SizedBox(width: 10),
                      _Metric(
                          label: 'Caducan pronto',
                          value: data.expiringSoonCount.toString(),
                          color: AppColors.warning,
                          icon: Icons.schedule_rounded),
                      const SizedBox(width: 10),
                      _Metric(
                          label: 'Vencidos',
                          value: data.expiredCount.toString(),
                          color: AppColors.danger,
                          icon: Icons.warning_rounded),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 58,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          MainTabsScope.select(context, MainTab.scan),
                      icon: const Icon(Icons.document_scanner_rounded),
                      label: const Text('Escanear ticket'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tu nevera',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w900)),
                      TextButton(
                          onPressed: () =>
                              MainTabsScope.select(context, MainTab.fridge),
                          child: const Text('Ver todo')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()))
                  else if (snapshot.hasError)
                    _Notice(
                        text:
                            'No se pudo cargar la nevera. Revisa backend, IP y Supabase.',
                        icon: Icons.error_outline_rounded,
                        color: AppColors.danger,
                        onRetry: _refresh)
                  else if (data.visibleProducts.isEmpty)
                    const _Notice(
                        text:
                            'Aun no hay productos activos. Escanea un ticket o anade uno manualmente.',
                        icon: Icons.kitchen_rounded,
                        color: AppColors.primary)
                  else
                    ...data.visibleProducts
                        .take(4)
                        .map((p) => _ProductTile(product: p)),
                  const SizedBox(height: 18),
                  _Notice(
                    text: data.statsError == null
                        ? '${data.stats.usagePercentage}% aprovechado. Ahorro estimado: ${data.stats.estimatedSavings.toStringAsFixed(2)} EUR.'
                        : 'Productos cargados. Las estadisticas se actualizaran cuando el resumen este disponible.',
                    icon: Icons.insights_rounded,
                    color: AppColors.primary,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _ProfileAction { signOut }

class _HomeData {
  const _HomeData(
      {required this.products,
      required this.visibleProducts,
      required this.stats,
      this.statsError});
  final List<ProductModel> products;
  final List<ProductModel> visibleProducts;
  final StatsSummaryModel stats;
  final Object? statsError;

  int get activeCount => products.where((p) => p.isPending).length;
  int get expiringSoonCount => products.where((p) => p.isExpiringSoon).length;
  int get expiredCount => products
      .where((p) =>
          p.status == 'expired' || p.status == 'wasted' || p.isExpiredActive)
      .length;

  static const empty = _HomeData(
      products: <ProductModel>[],
      visibleProducts: <ProductModel>[],
      stats: StatsSummaryModel.empty);
}

class _Metric extends StatelessWidget {
  const _Metric(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(value,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
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
    final color = days == null
        ? AppColors.secondary
        : days < 0
            ? AppColors.danger
            : days <= 2
                ? AppColors.warning
                : AppColors.success;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        ProductImage(category: product.category, size: 44),
        const SizedBox(width: 12),
        Expanded(
            child: Text(product.name,
                style: const TextStyle(fontWeight: FontWeight.w800))),
        Text(product.daysLabel,
            style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(
      {required this.text,
      required this.icon,
      required this.color,
      this.onRetry});
  final String text;
  final IconData icon;
  final Color color;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
            child: Text(text,
                style: const TextStyle(fontWeight: FontWeight.w600))),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
      ]),
    );
  }
}
