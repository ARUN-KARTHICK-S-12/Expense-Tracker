import 'package:flutter/material.dart';

import '../utils/formatters.dart';

class TransactionFilterBar extends StatelessWidget {
  const TransactionFilterBar({
    super.key,
    required this.searchController,
    required this.categories,
    required this.selectedCategory,
    required this.selectedDateRange,
    required this.onCategoryChanged,
    required this.onDateRangeChanged,
    required this.onReset,
    required this.hasActiveFilters,
  });

  final TextEditingController searchController;
  final List<String> categories;
  final String? selectedCategory;
  final DateTimeRange? selectedDateRange;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<DateTimeRange?> onDateRangeChanged;
  final VoidCallback onReset;
  final bool hasActiveFilters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search by description',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: hasActiveFilters
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Reset filters',
                      onPressed: onReset,
                    )
                  : null,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  isExpanded: true, 
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('All Categories'),
                    ),
                    ...categories.map(
                      (c) => DropdownMenuItem(value: c, child: Text(c)),
                    ),
                  ],
                  onChanged: onCategoryChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: selectedDateRange,
                    );
                    if (range != null) onDateRangeChanged(range);
                  },
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    selectedDateRange == null
                        ? 'Date range'
                        : '${formatDate(selectedDateRange!.start)} – '
                            '${formatDate(selectedDateRange!.end)}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
