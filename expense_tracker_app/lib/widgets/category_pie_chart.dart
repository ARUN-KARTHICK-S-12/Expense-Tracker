import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/analytics_data.dart';

class CategoryPieChart extends StatefulWidget {
  const CategoryPieChart({super.key, required this.items});

  final List<CategoryTotal> items;

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  int? _touchedIndex;

  // A fixed palette that cycles if there are more categories than colours.
  static const _palette = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFEF5350),
    Color(0xFFFFA726),
    Color(0xFF66BB6A),
    Color(0xFFAB47BC),
    Color(0xFF29B6F6),
    Color(0xFFFF7043),
    Color(0xFF8D6E63),
    Color(0xFF78909C),
  ];

  Color _colorFor(int index) => _palette[index % _palette.length];

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No data')),
        ),
      );
    }

    final total = widget.items.fold(0.0, (s, e) => s + e.total);

    final sections = List.generate(widget.items.length, (i) {
      final item      = widget.items[i];
      final isTouched = i == _touchedIndex;
      final pct       = total > 0 ? (item.total / total * 100) : 0.0;

      return PieChartSectionData(
        value:     item.total,
        color:     _colorFor(i),
        radius:    isTouched ? 72 : 60,   // fixed radii — no infinite size
        title:     isTouched ? '${pct.toStringAsFixed(1)}%' : '',
        titleStyle: const TextStyle(
          fontSize:   13,
          fontWeight: FontWeight.bold,
          color:      Colors.white,
        ),
      );
    });

    // KEY FIX: always wrap PieChart in an explicit SizedBox with a finite
    // height. Never use SizedBox(height: double.infinity) or an unsized
    // SizedBox inside a Column/ListView — that propagates h=Infinity.
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,   // ← shrink-wrap; don't expand
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Pie ────────────────────────────────────────────────
            SizedBox(
              height: 220,               // ← single, concrete height
              child: PieChart(
                PieChartData(
                  sections:          sections,
                  centerSpaceRadius: 40,
                  sectionsSpace:     2,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            response == null ||
                            response.touchedSection == null) {
                          _touchedIndex = null;
                        } else {
                          _touchedIndex =
                              response.touchedSection!.touchedSectionIndex;
                        }
                      });
                    },
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Legend ─────────────────────────────────────────────
            Wrap(
              spacing:     12,
              runSpacing:  8,
              children: List.generate(widget.items.length, (i) {
                final item = widget.items[i];
                final pct  = total > 0 ? (item.total / total * 100) : 0.0;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width:  12,
                      height: 12,
                      decoration: BoxDecoration(
                        color:        _colorFor(i),
                        shape:        BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${item.category} (${pct.toStringAsFixed(1)}%)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}