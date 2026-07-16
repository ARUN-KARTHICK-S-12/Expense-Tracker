import 'package:flutter/material.dart';

class TransactionListFilter {
  const TransactionListFilter({
    this.searchQuery = '',
    this.category,
    this.rangeStart,
    this.rangeEnd,
  });

  final String searchQuery;
  final String? category;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  DateTimeRange? get dateRange {
    if (rangeStart == null || rangeEnd == null) return null;
    return DateTimeRange(start: rangeStart!, end: rangeEnd!);
  }

  bool get hasActiveFilters =>
      searchQuery.trim().isNotEmpty ||
      (category != null && category!.isNotEmpty) ||
      dateRange != null;

  TransactionListFilter copyWith({
    String? searchQuery,
    String? category,
    DateTime? rangeStart,
    DateTime? rangeEnd,
    bool clearCategory = false,
    bool clearDateRange = false,
  }) {
    return TransactionListFilter(
      searchQuery: searchQuery ?? this.searchQuery,
      category: clearCategory ? null : (category ?? this.category),
      rangeStart: clearDateRange ? null : (rangeStart ?? this.rangeStart),
      rangeEnd: clearDateRange ? null : (rangeEnd ?? this.rangeEnd),
    );
  }

  TransactionListFilter withDateRange(DateTimeRange? range) {
    if (range == null) return copyWith(clearDateRange: true);
    return copyWith(rangeStart: range.start, rangeEnd: range.end);
  }
}
