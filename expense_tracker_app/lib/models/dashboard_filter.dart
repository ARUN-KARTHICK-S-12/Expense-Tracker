class DashboardFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String? category;

  const DashboardFilter({
    this.startDate,
    this.endDate,
    this.category,
  });

  DashboardFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) {
    return DashboardFilter(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      category: category ?? this.category,
    );
  }
}