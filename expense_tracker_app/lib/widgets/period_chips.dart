import 'package:flutter/material.dart';

import '../models/analytics_data.dart';

class PeriodChips extends StatelessWidget {
  const PeriodChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final FilterPeriod selected;
  final ValueChanged<FilterPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: FilterPeriod.values.map((p) {
        final label = p.name[0].toUpperCase() + p.name.substring(1);
        return ChoiceChip(
          label: Text(label),
          selected: selected == p,
          onSelected: (_) => onSelected(p),
        );
      }).toList(),
    );
  }
}
