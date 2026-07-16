import 'package:flutter/material.dart';

import '../models/transaction_record.dart';

/// Filters transactions by description keyword, category, and optional date range.
List<TransactionRecord> filterTransactions(
  List<TransactionRecord> items, {
  String searchQuery = '',
  String? category,
  DateTimeRange? dateRange,
}) {
  final query = searchQuery.trim().toLowerCase();

  return items.where((e) {
    if (query.isNotEmpty &&
        !e.description.toLowerCase().contains(query)) {
      return false;
    }

    if (category != null &&
        category.isNotEmpty &&
        e.category != category) {
      return false;
    }

    if (dateRange != null) {
      final dayStart = DateTime(
        dateRange.start.year,
        dateRange.start.month,
        dateRange.start.day,
      );
      final dayEnd = DateTime(
        dateRange.end.year,
        dateRange.end.month,
        dateRange.end.day,
      ).add(const Duration(days: 1));
      if (e.date.isBefore(dayStart) || !e.date.isBefore(dayEnd)) {
        return false;
      }
    }

    return true;
  }).toList();
}

bool hasActiveTransactionFilters({
  String searchQuery = '',
  String? category,
  DateTimeRange? dateRange,
}) {
  return searchQuery.trim().isNotEmpty ||
      (category != null && category.isNotEmpty) ||
      dateRange != null;
}
