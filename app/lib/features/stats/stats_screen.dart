import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/stats_summary_model.dart';
import '../../data/services/api_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _api = const ApiService();
  late Future<StatsSummaryModel> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchStatsSummary();
  }

  void _refresh() => setState(() => _future = _api.fetchStatsSummary());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu progreso'),
        actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: FutureBuilder<StatsSummaryModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(message: snapshot.error.toString(), onRetry: _refresh);
          }

          final stats = snapshot.data ?? StatsSummaryModel.empty;
          final progress = stats.usagePercentage.clamp(0, 100).toDouble() / 100;
          final lostCount = stats.wastedCount + stats.expiredCount;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Cada producto aprovechado cuenta.', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              const SizedBox(height: 24),
              Row(children: [
                _Metric(title: 'Aprovechados', value: stats.consumedCount.toString(), icon: Icons.check_circle_rounded, color: AppColors.success),
                const SizedBox(width: 12),
                _Metric(title: 'Perdidos', value: lostCount.toString(), icon: Icons.delete_outline_rounded, color: AppColors.danger),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _Metric(title: 'Ahorro', value: '${stats.estimatedSavings.toStringAsFixed(2)} EUR', icon: Icons.savings_rounded, color: AppColors.secondary),
                const SizedBox(width: 12),
                _Metric(title: 'Perdida', value: '${stats.estimatedWaste.toStringAsFixed(2)} EUR', icon: Icons.money_off_rounded, color: AppColors.danger),
              ]),
              const SizedBox(height: 24),
              _Panel(
                child: Row(children: [
                  Stack(alignment: Alignment.center, children: [
                    SizedBox(
                      width: 108,
                      height: 108,
                      child: CircularProgressIndicator(value: progress, strokeWidth: 12, color: AppColors.primary, backgroundColor: AppColors.primaryLight),
                    ),
                    Text('${stats.usagePercentage}%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
                  ]),
                  const SizedBox(width: 20),
                  Expanded(child: Text(stats.usagePercentage >= 80 ? 'Vas muy bien: la mayoria se aprovecha.' : 'Revisa antes los productos que caducan pronto.', style: const TextStyle(color: AppColors.textSecondary))),
                ]),
              ),
              const SizedBox(height: 18),
              _Panel(
                color: AppColors.primaryLight,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Ranking personal', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 10),
                  Text(stats.level, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: (stats.score % 200) / 200, color: AppColors.primary, backgroundColor: Colors.white),
                  const SizedBox(height: 8),
                  Text('${stats.score} pts acumulados', style: const TextStyle(color: AppColors.textSecondary)),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.title, required this.value, required this.icon, required this.color});
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text(title, style: const TextStyle(color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.color = Colors.white});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(24)), child: child);
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline_rounded, size: 54, color: AppColors.danger),
          const SizedBox(height: 12),
          const Text('No se pudieron cargar las estadisticas', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ]),
      ),
    );
  }
}
