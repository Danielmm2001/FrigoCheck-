import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/daily_stats_model.dart';
import '../../data/models/stats_summary_model.dart';
import '../../data/services/api_service.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _api = const ApiService();
  late Future<_ProfileData> _future;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProfileData> _load() async {
    final stats = await _api.fetchStatsSummary();
    final daily = await _api.fetchDailyStats(
        year: _selectedMonth.year, month: _selectedMonth.month);
    return _ProfileData(stats: stats, daily: daily);
  }

  void _refresh() => setState(() => _future = _load());

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + offset);
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
              onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))
        ],
      ),
      body: FutureBuilder<_ProfileData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
                message: snapshot.error.toString(), onRetry: _refresh);
          }

          final data = snapshot.data ?? _ProfileData.empty;
          final stats = data.stats;
          final lostCount = stats.wastedCount + stats.expiredCount;
          final rank = _Rank.fromScore(stats.score, stats.usagePercentage);

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _ProfileHeader(stats: stats, rank: rank),
                const SizedBox(height: 16),
                Row(children: [
                  _Metric(
                      title: 'Ahorro',
                      value: '${stats.estimatedSavings.toStringAsFixed(2)} EUR',
                      icon: Icons.savings_rounded,
                      color: AppColors.success),
                  const SizedBox(width: 10),
                  _Metric(
                      title: 'Perdida',
                      value: '${stats.estimatedWaste.toStringAsFixed(2)} EUR',
                      icon: Icons.money_off_rounded,
                      color: AppColors.danger),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _Metric(
                      title: 'Consumidos',
                      value: stats.consumedCount.toString(),
                      icon: Icons.check_circle_rounded,
                      color: AppColors.primary),
                  const SizedBox(width: 10),
                  _Metric(
                      title: 'Vencidos',
                      value: lostCount.toString(),
                      icon: Icons.warning_rounded,
                      color: AppColors.warning),
                ]),
                const SizedBox(height: 16),
                _StreakPanel(streak: stats.currentStreak),
                const SizedBox(height: 16),
                _RankPanel(rank: rank, score: stats.score),
                const SizedBox(height: 16),
                _ChartPanel(
                  month: _selectedMonth,
                  daily: data.daily,
                  onPrevious: () => _changeMonth(-1),
                  onNext: () => _changeMonth(1),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileData {
  const _ProfileData({required this.stats, required this.daily});

  final StatsSummaryModel stats;
  final DailyStatsModel daily;

  static final empty = _ProfileData(
      stats: StatsSummaryModel.empty, daily: DailyStatsModel.empty);
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.stats, required this.rank});

  final StatsSummaryModel stats;
  final _Rank rank;

  @override
  Widget build(BuildContext context) {
    final progress = stats.usagePercentage.clamp(0, 100).toDouble() / 100;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 92,
              height: 92,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 10,
                color: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: .22),
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${stats.usagePercentage}%',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              const Text('uso',
                  style: TextStyle(color: Colors.white, fontSize: 11)),
            ]),
          ]),
          const SizedBox(width: 18),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Dani',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(rank.title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                stats.usagePercentage >= 80
                    ? 'Tu nevera va muy controlada.'
                    : 'Aun puedes rescatar mas productos antes de vencer.',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .86), height: 1.25),
              ),
            ]),
          ),
          _Shield(rank: rank, size: 54),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(
      {required this.title,
      required this.value,
      required this.icon,
      required this.color});

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 118,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(22)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color),
          const Spacer(),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          Text(title,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
        ]),
      ),
    );
  }
}

class _StreakPanel extends StatelessWidget {
  const _StreakPanel({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.local_fire_department_rounded,
              color: AppColors.warning),
        ),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('En racha',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          Text(
              streak == 0
                  ? 'Consume productos para empezar una racha.'
                  : '$streak dias seguidos aprovechando productos.',
              style: const TextStyle(color: AppColors.textSecondary)),
        ])),
        Text('$streak',
            style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppColors.warning)),
      ]),
    );
  }
}

class _RankPanel extends StatelessWidget {
  const _RankPanel({required this.rank, required this.score});

  final _Rank rank;
  final int score;

  @override
  Widget build(BuildContext context) {
    final next = rank.next;
    final progress = next == null
        ? 1.0
        : ((score - rank.minScore) / (next.minScore - rank.minScore))
            .clamp(0, 1)
            .toDouble();
    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _Shield(rank: rank, size: 62),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Ranking personal',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(rank.title,
                    style: TextStyle(
                        color: rank.color, fontWeight: FontWeight.w900)),
              ])),
          Text('$score pts',
              style: const TextStyle(fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              color: rank.color,
              backgroundColor: rank.color.withValues(alpha: .14)),
        ),
        const SizedBox(height: 8),
        Text(
            next == null
                ? 'Rango maximo alcanzado.'
                : '${next.minScore - score} puntos para ${next.title}.',
            style: const TextStyle(color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _ChartPanel extends StatelessWidget {
  const _ChartPanel(
      {required this.month,
      required this.daily,
      required this.onPrevious,
      required this.onNext});

  final DateTime month;
  final DailyStatsModel daily;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final totalSavings =
        daily.days.fold<double>(0, (sum, day) => sum + day.savings);
    final totalWaste =
        daily.days.fold<double>(0, (sum, day) => sum + day.waste);
    return _Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
              child: Text('Ahorro del mes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
          IconButton(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded)),
          Text(_monthLabel(month),
              style: const TextStyle(fontWeight: FontWeight.w800)),
          IconButton(
              onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded)),
        ]),
        const SizedBox(height: 8),
        SizedBox(height: 150, child: _MonthlyChart(days: daily.days)),
        const SizedBox(height: 14),
        Row(children: [
          _Legend(
              color: AppColors.success,
              label: 'Ahorrado',
              value: '${totalSavings.toStringAsFixed(2)} EUR'),
          const SizedBox(width: 14),
          _Legend(
              color: AppColors.danger,
              label: 'Perdido',
              value: '${totalWaste.toStringAsFixed(2)} EUR'),
        ]),
      ]),
    );
  }

  String _monthLabel(DateTime value) {
    const names = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic'
    ];
    return '${names[value.month - 1]} ${value.year}';
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.days});

  final List<DailyStatsPoint> days;

  @override
  Widget build(BuildContext context) {
    final maxValue = days.fold<double>(1, (max, day) {
      final value = day.savings > day.waste ? day.savings : day.waste;
      return value > max ? value : max;
    });
    if (days.isEmpty) {
      return const Center(
          child: Text('Sin datos este mes',
              style: TextStyle(color: AppColors.textSecondary)));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: days.map((day) {
        final savingsHeight =
            (day.savings / maxValue * 112).clamp(3, 112).toDouble();
        final wasteHeight =
            (day.waste / maxValue * 112).clamp(3, 112).toDouble();
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Container(
                  width: 5,
                  height: wasteHeight,
                  decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: .72),
                      borderRadius: BorderRadius.circular(999))),
              const SizedBox(height: 2),
              Container(
                  width: 5,
                  height: savingsHeight,
                  decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(999))),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(
      {required this.color, required this.label, required this.value});

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Expanded(
            child: Text('$label · $value',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary))),
      ]),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(24)),
      child: child,
    );
  }
}

class _Shield extends StatelessWidget {
  const _Shield({required this.rank, required this.size});

  final _Rank rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: rank.color,
        borderRadius: BorderRadius.circular(size * .32),
        boxShadow: [
          BoxShadow(
              color: rank.color.withValues(alpha: .28),
              blurRadius: 16,
              offset: const Offset(0, 7))
        ],
      ),
      child: Icon(rank.icon, color: Colors.white, size: size * .52),
    );
  }
}

class _Rank {
  const _Rank(
      {required this.title,
      required this.minScore,
      required this.color,
      required this.icon});

  final String title;
  final int minScore;
  final Color color;
  final IconData icon;

  _Rank? get next {
    final index = _ranks.indexOf(this);
    if (index < 0 || index == _ranks.length - 1) return null;
    return _ranks[index + 1];
  }

  static _Rank fromScore(int score, int usagePercentage) {
    if (score >= 500 && usagePercentage >= 85) return _ranks[3];
    if (score >= 250 && usagePercentage >= 70) return _ranks[2];
    if (score >= 100) return _ranks[1];
    return _ranks[0];
  }

  static const _ranks = [
    _Rank(
        title: 'Aprendiz anti-desperdicio',
        minScore: 0,
        color: AppColors.secondary,
        icon: Icons.eco_rounded),
    _Rank(
        title: 'Ahorrador constante',
        minScore: 100,
        color: AppColors.primary,
        icon: Icons.savings_rounded),
    _Rank(
        title: 'Nevera en control',
        minScore: 250,
        color: AppColors.warning,
        icon: Icons.workspace_premium_rounded),
    _Rank(
        title: 'Maestro FrigoCheck',
        minScore: 500,
        color: Color(0xFF8B5CF6),
        icon: Icons.military_tech_rounded),
  ];
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
          const Icon(Icons.error_outline_rounded,
              size: 54, color: AppColors.danger),
          const SizedBox(height: 12),
          const Text('No se pudo cargar el perfil',
              style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Reintentar')),
        ]),
      ),
    );
  }
}
