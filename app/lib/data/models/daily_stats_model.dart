class DailyStatsPoint {
  const DailyStatsPoint({
    required this.date,
    required this.savings,
    required this.waste,
    required this.consumedCount,
    required this.expiredCount,
  });

  final DateTime date;
  final double savings;
  final double waste;
  final int consumedCount;
  final int expiredCount;

  factory DailyStatsPoint.fromJson(Map<String, dynamic> json) {
    return DailyStatsPoint(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      savings: (json['savings'] as num?)?.toDouble() ?? 0,
      waste: (json['waste'] as num?)?.toDouble() ?? 0,
      consumedCount: (json['consumed_count'] as num?)?.toInt() ?? 0,
      expiredCount: (json['expired_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class DailyStatsModel {
  const DailyStatsModel({
    required this.year,
    required this.month,
    required this.days,
  });

  final int year;
  final int month;
  final List<DailyStatsPoint> days;

  factory DailyStatsModel.fromJson(Map<String, dynamic> json) {
    final rawDays = json['days'] as List<dynamic>? ?? [];
    return DailyStatsModel(
      year: (json['year'] as num?)?.toInt() ?? DateTime.now().year,
      month: (json['month'] as num?)?.toInt() ?? DateTime.now().month,
      days: rawDays
          .map((item) => DailyStatsPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  static final empty = DailyStatsModel(
    year: DateTime.now().year,
    month: DateTime.now().month,
    days: const <DailyStatsPoint>[],
  );
}
