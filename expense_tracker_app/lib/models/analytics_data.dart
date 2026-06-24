import '../utils/json_helpers.dart';

class ChartPoint {
  const ChartPoint({required this.label, required this.total});

  final String label;
  final double total;

  factory ChartPoint.fromJson(Map<String, dynamic> json) {
    return ChartPoint(
      label: jsonString(json['label']),
      total: jsonDouble(json['total']),
    );
  }
}

class CategoryTotal {
  const CategoryTotal({required this.category, required this.total});

  final String category;
  final double total;

  factory CategoryTotal.fromJson(Map<String, dynamic> json) {
    return CategoryTotal(
      category: jsonString(json['category']),
      total: jsonDouble(json['total']),
    );
  }
}

class AnalyticsData {
  const AnalyticsData({
    required this.expenses,
    required this.investments,
    this.expenseByCategory = const [],
    this.investmentByCategory = const [],
  });

  final List<ChartPoint> expenses;
  final List<ChartPoint> investments;
  final List<CategoryTotal> expenseByCategory;
  final List<CategoryTotal> investmentByCategory;

  factory AnalyticsData.fromJson(Map<String, dynamic> json) {
    List<ChartPoint> parseSeries(dynamic list) {
      if (list is! List) return [];
      return list
          .map((e) => ChartPoint.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<CategoryTotal> parseCats(dynamic list) {
      if (list is! List) return [];
      return list
          .map((e) => CategoryTotal.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final breakdown = json['categoryBreakdown'] as Map<String, dynamic>?;
    return AnalyticsData(
      expenses: parseSeries(json['expenses']),
      investments: parseSeries(json['investments']),
      expenseByCategory: parseCats(breakdown?['expenses']),
      investmentByCategory: parseCats(breakdown?['investments']),
    );
  }
}

enum FilterPeriod { day, week, month, year }

extension FilterPeriodExt on FilterPeriod {
  String get apiValue => name;
}
