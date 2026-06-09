class StatsSummaryModel {
  const StatsSummaryModel({
    required this.activeCount,
    required this.consumedCount,
    required this.wastedCount,
    required this.expiredCount,
    required this.expiringSoonCount,
    required this.expiredActiveCount,
    required this.usagePercentage,
    required this.estimatedSavings,
    required this.estimatedWaste,
    required this.currentStreak,
    required this.score,
    required this.level,
  });

  final int activeCount;
  final int consumedCount;
  final int wastedCount;
  final int expiredCount;
  final int expiringSoonCount;
  final int expiredActiveCount;
  final int usagePercentage;
  final double estimatedSavings;
  final double estimatedWaste;
  final int currentStreak;
  final int score;
  final String level;

  factory StatsSummaryModel.fromJson(Map<String, dynamic> json) {
    return StatsSummaryModel(
      activeCount: (json['active_count'] as num?)?.toInt() ?? 0,
      consumedCount: (json['consumed_count'] as num?)?.toInt() ?? 0,
      wastedCount: (json['wasted_count'] as num?)?.toInt() ?? 0,
      expiredCount: (json['expired_count'] as num?)?.toInt() ?? 0,
      expiringSoonCount: (json['expiring_soon_count'] as num?)?.toInt() ?? 0,
      expiredActiveCount: (json['expired_active_count'] as num?)?.toInt() ?? 0,
      usagePercentage: (json['usage_percentage'] as num?)?.toInt() ?? 0,
      estimatedSavings: (json['estimated_savings'] as num?)?.toDouble() ?? 0,
      estimatedWaste: (json['estimated_waste'] as num?)?.toDouble() ?? 0,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toInt() ?? 0,
      level: json['level']?.toString() ?? 'Aprendiz anti-desperdicio',
    );
  }

  static const empty = StatsSummaryModel(
    activeCount: 0,
    consumedCount: 0,
    wastedCount: 0,
    expiredCount: 0,
    expiringSoonCount: 0,
    expiredActiveCount: 0,
    usagePercentage: 0,
    estimatedSavings: 0,
    estimatedWaste: 0,
    currentStreak: 0,
    score: 0,
    level: 'Aprendiz anti-desperdicio',
  );
}
