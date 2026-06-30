import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/analytics_data.dart';
import '../models/transaction_record.dart';
import '../providers/app_state.dart';
import '../utils/formatters.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/insights_card.dart';
import '../widgets/period_chips.dart';
import '../widgets/summary_card.dart';
import '../widgets/fullscreen_chart_page.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTimeRange? selectedRange;
  String? selectedCategory;

  /// Converts the active [FilterPeriod] + reference date into a concrete
  /// [DateTimeRange]. Returns null only if somehow the period is unrecognised.
  DateTimeRange? _periodRange(FilterPeriod period, DateTime ref) {
    final today = DateTime(ref.year, ref.month, ref.day);
    switch (period) {
      case FilterPeriod.day:
        return DateTimeRange(start: today, end: today);

      case FilterPeriod.week:
        // Monday of the current week → today
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(start: monday, end: today);

      case FilterPeriod.month:
        final start = DateTime(ref.year, ref.month, 1);
        return DateTimeRange(start: start, end: today);

      case FilterPeriod.year:
        final start = DateTime(ref.year, 1, 1);
        return DateTimeRange(start: start, end: today);
    }
  }

  List<TransactionRecord> _filter(
    List<TransactionRecord> items,
    FilterPeriod period,
    DateTime referenceDate,
  ) {
    // Custom date-range picker overrides the period chip.
    final range = selectedRange ?? _periodRange(period, referenceDate);

    return items.where((e) {
      // Period / custom-range filter
      if (range != null) {
        final dayStart = DateTime(range.start.year, range.start.month, range.start.day);
        final dayEnd   = DateTime(range.end.year,   range.end.month,   range.end.day)
            .add(const Duration(days: 1));
        if (e.date.isBefore(dayStart) || !e.date.isBefore(dayEnd)) return false;
      }

      // Category filter
      if (selectedCategory != null &&
          selectedCategory!.isNotEmpty &&
          e.category != selectedCategory) {
        return false;
      }

      return true;
    }).toList();
  }

  List<CategoryTotal> _groupByCategory(List<TransactionRecord> records) {
    final map = <String, double>{};
    for (final r in records) {
      map[r.category] = (map[r.category] ?? 0) + r.amount;
    }
    return map.entries
        .map((e) => CategoryTotal(category: e.key, total: e.value))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
  }

  List<ChartPoint> _dailyTrend(List<TransactionRecord> records) {
    final sorted = [...records]..sort((a, b) => a.date.compareTo(b.date));
    final map = <String, double>{};
    for (final r in sorted) {
      final key =
          "${r.date.day.toString().padLeft(2, '0')}/"
          "${r.date.month.toString().padLeft(2, '0')}";
      map[key] = (map[key] ?? 0) + r.amount;
    }
    return map.entries
        .map((e) => ChartPoint(label: e.key, total: e.value))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final expenseRecords    = _filter(state.expenses,    state.analyticsPeriod, state.analyticsReferenceDate);
    final investmentRecords = _filter(state.investments, state.analyticsPeriod, state.analyticsReferenceDate);

    final expenseTrend    = _dailyTrend(expenseRecords);
    final investmentTrend = _dailyTrend(investmentRecords);

    final expenseCategories    = _groupByCategory(expenseRecords);
    final investmentCategories = _groupByCategory(investmentRecords);

    final totalExpense    = expenseRecords.fold(0.0, (s, e) => s + e.amount);
    final totalInvestment = investmentRecords.fold(0.0, (s, e) => s + e.amount);
    final savings         = totalInvestment - totalExpense;

    final categories = <String>{
      ...state.expenseCategories.map((e) => e.name),
      ...state.investmentCategories.map((e) => e.name),
    }.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: RefreshIndicator(
        onRefresh: () => state.refreshAll(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Period chips ────────────────────────────────────────
            PeriodChips(
              selected: state.analyticsPeriod,
              onSelected: (p) {
                // Selecting a chip clears any custom date range so the
                // period filter takes effect immediately.
                setState(() => selectedRange = null);
                state.setAnalyticsPeriod(p);
              },
            ),

            const SizedBox(height: 16),

            // ── Date range button (overrides period chip when set) ──
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (range != null) setState(() => selectedRange = range);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.date_range),
                        const SizedBox(width: 8),
                        Text(
                          selectedRange == null
                              ? 'Custom Date Range'
                              : '${formatDate(selectedRange!.start)}'
                                  ' → '
                                  '${formatDate(selectedRange!.end)}',
                        ),
                      ],
                    ),
                  ),
                ),
                // Clear button — only shown when a custom range is active
                if (selectedRange != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear date range',
                    onPressed: () => setState(() => selectedRange = null),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // ── Category filter ─────────────────────────────────────
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
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
              onChanged: (value) => setState(() => selectedCategory = value),
            ),

            const SizedBox(height: 20),

            // ── Summary cards ───────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: SummaryCard(
                    title: 'Expense',
                    amount: formatAmount(totalExpense),
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SummaryCard(
                    title: 'Investment',
                    amount: formatAmount(totalInvestment),
                    color: Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            SummaryCard(
              title: 'Net Savings',
              amount: formatAmount(savings),
              color: savings >= 0 ? Colors.green : Colors.red,
            ),

            const SizedBox(height: 24),

            // ── Expense category breakdown ──────────────────────────
            Text('Expenses by category',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _CategoryBreakdown(
                items: expenseCategories, color: Colors.deepOrange),

            const SizedBox(height: 24),

            // ── Investment category breakdown ───────────────────────
            Text('Investments by category',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _CategoryBreakdown(
                items: investmentCategories, color: Colors.teal),

            const SizedBox(height: 24),

            // ── Expense trend chart ─────────────────────────────────
            _TrendSection(
              title: 'Expense Trend',
              points: expenseTrend,
              color: Colors.deepOrange,
            ),

            const SizedBox(height: 24),

            // ── Investment trend chart ──────────────────────────────
            _TrendSection(
              title: 'Investment Trend',
              points: investmentTrend,
              color: Colors.teal,
            ),

            const SizedBox(height: 24),

            // ── Expense pie chart ───────────────────────────────────
            _PieSection(
              title: 'Expenses by category',
              fullscreenTitle: 'Expense Categories',
              items: expenseCategories,
            ),

            const SizedBox(height: 24),

            // ── Investment pie chart ────────────────────────────────
            _PieSection(
              title: 'Investments by category',
              fullscreenTitle: 'Investment Categories',
              items: investmentCategories,
            ),

            const SizedBox(height: 24),

            // ── Insights ────────────────────────────────────────────
            InsightsCard(
              insights: [
                if (expenseCategories.isNotEmpty)
                  '${expenseCategories.first.category} is your highest expense category',
                if (investmentCategories.isNotEmpty)
                  '${investmentCategories.first.category} is your highest investment category',
                'Total Expense: ${formatAmount(totalExpense)}',
                'Total Investment: ${formatAmount(totalInvestment)}',
                'Net Savings: ${formatAmount(savings)}',
              ],
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TrendSection
// ─────────────────────────────────────────────────────────────────────────────

class _TrendSection extends StatelessWidget {
  const _TrendSection({
    required this.title,
    required this.points,
    required this.color,
  });

  final String title;
  final List<ChartPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,   // ← never asks for infinite height
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.fullscreen),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _FullscreenTrendPage(
                    title: title,
                    points: points,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Single, unambiguous height constraint — nothing inside adds another.
        SizedBox(
          height: 220,
          child: _TrendChartCard(points: points, color: color),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PieSection
// ─────────────────────────────────────────────────────────────────────────────

class _PieSection extends StatelessWidget {
  const _PieSection({
    required this.title,
    required this.fullscreenTitle,
    required this.items,
  });

  final String title;
  final String fullscreenTitle;
  final List<CategoryTotal> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.fullscreen),
              tooltip: 'Expand',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullscreenChartPage(
                    title: fullscreenTitle,
                    child: CategoryPieChart(items: items),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CategoryPieChart(items: items),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FullscreenTrendPage  –  self-contained fullscreen for trend charts
// Avoids passing an unbounded child into FullscreenChartPage.
// ─────────────────────────────────────────────────────────────────────────────

class _FullscreenTrendPage extends StatelessWidget {
  const _FullscreenTrendPage({
    required this.title,
    required this.points,
    required this.color,
  });

  final String title;
  final List<ChartPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      // LayoutBuilder gives us a concrete finite height to hand to the chart.
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight - 32, // subtract padding
              child: _TrendChartCard(points: points, color: color),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TrendChartCard  –  pure Card + LineChart, zero scrollables inside
// ─────────────────────────────────────────────────────────────────────────────

class _TrendChartCard extends StatelessWidget {
  const _TrendChartCard({required this.points, required this.color});

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

    final maxY =
        points.map((p) => p.total).reduce((a, b) => a > b ? a : b);

    // Never show more than 8 bottom-axis labels so they don't collide.
    final labelInterval = (points.length / 8).ceil().toDouble().clamp(1, double.infinity);

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
            clipData: const FlClipData.all(),
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                  final point = points[spot.x.toInt()];
                  return LineTooltipItem(
                    '${point.label}\n₹${point.total.toStringAsFixed(0)}',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList(),
              ),
            ),
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
                  reservedSize: 32,
                  interval: labelInterval.toDouble(),
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= points.length) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        points[i].label,
                        style: const TextStyle(fontSize: 9),
                      ),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: color,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: color.withOpacity(0.15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CategoryBreakdown
// ─────────────────────────────────────────────────────────────────────────────

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
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          final pct = total > 0 ? item.total / total : 0.0;
          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(item.category)),
                    Text(
                      formatAmount(item.total),
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: pct,
                  backgroundColor: color.withOpacity(0.12),
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