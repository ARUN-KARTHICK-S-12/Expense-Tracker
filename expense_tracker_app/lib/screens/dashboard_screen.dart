import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/analytics_data.dart';
import '../providers/app_state.dart';
import '../utils/formatters.dart';
import '../widgets/period_chips.dart';
import '../widgets/summary_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final analytics = state.analytics;

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: RefreshIndicator(
        onRefresh: () => state.refreshAll(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PeriodChips(
              selected: state.analyticsPeriod,
              onSelected: state.setAnalyticsPeriod,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reference date'),
              subtitle: Text(formatDate(state.analyticsReferenceDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: state.analyticsReferenceDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  state.setAnalyticsReferenceDate(picked);
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    title: 'Expenses',
                    amount: formatAmount(_sum(analytics?.expenses ?? [])),
                    color: Colors.deepOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SummaryCard(
                    title: 'Investments',
                    amount: formatAmount(_sum(analytics?.investments ?? [])),
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Expense trend',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: _TrendChart(
                points: analytics?.expenses ?? [],
                color: Colors.deepOrange,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Investment trend',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: _TrendChart(
                points: analytics?.investments ?? [],
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Expenses by category',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _CategoryBreakdown(
              items: analytics?.expenseByCategory ?? [],
              color: Colors.deepOrange,
            ),
            const SizedBox(height: 24),
            Text(
              'Investments by category',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _CategoryBreakdown(
              items: analytics?.investmentByCategory ?? [],
              color: Colors.teal,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  double _sum(List<ChartPoint> points) =>
      points.fold(0.0, (s, p) => s + p.total);
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points, required this.color});

  final List<ChartPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Card(
        child: Center(
          child: Text(
            'No data for this period',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final maxY = points.map((p) => p.total).reduce((a, b) => a > b ? a : b);
    final spots = List.generate(
      points.length,
      (i) => FlSpot(i.toDouble(), points[i].total),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY * 1.2 + 1,
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 48,
                  getTitlesWidget: (value, meta) => Text(
                    value >= 1000
                        ? '${(value / 1000).toStringAsFixed(0)}k'
                        : value.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= points.length) return const SizedBox();
                    final label = points[i].label;
                    final short = label.length > 6
                        ? label.substring(label.length - 5)
                        : label;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(short, style: const TextStyle(fontSize: 9)),
                    );
                  },
                ),
              ),
              rightTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:
                  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: color,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: color.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryBreakdown extends StatelessWidget {
  const _CategoryBreakdown({required this.items, required this.color});

  final List<CategoryTotal> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('No category data')),
        ),
      );
    }

    final total = items.fold(0.0, (s, e) => s + e.total);
    return Card(
      child: Column(
        children: items.map((item) {
          final pct = total > 0 ? item.total / total : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(item.category)),
                    Text(
                      formatAmount(item.total),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: pct,
                  backgroundColor: color.withValues(alpha: 0.12),
                  color: color,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
