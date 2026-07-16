import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction_record.dart';
import '../providers/app_state.dart';
import '../utils/formatters.dart';
import '../utils/transaction_filters.dart';
import '../widgets/hideable_amount.dart';
import '../widgets/transaction_filter_bar.dart';
import 'transaction_form_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key, required this.isInvestment});

  final bool isInvestment;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchController = TextEditingController();
  bool _searchInitialized = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_searchInitialized) {
      _searchInitialized = true;
      _searchController.text = context
          .read<AppState>()
          .transactionListFilter(widget.isInvestment)
          .searchQuery;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final state = context.read<AppState>();
    final current = state.transactionListFilter(widget.isInvestment);
    if (current.searchQuery == _searchController.text) return;

    state.setTransactionListFilter(
      widget.isInvestment,
      current.copyWith(searchQuery: _searchController.text),
    );
  }

  void _resetFilters() {
    context.read<AppState>().resetTransactionListFilter(widget.isInvestment);
    _searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final filter = state.transactionListFilter(widget.isInvestment);
    final allRecords =
        widget.isInvestment ? state.investments : state.expenses;
    final categories = state.categoryNames(widget.isInvestment);
    final filteredRecords = filterTransactions(
      allRecords,
      searchQuery: filter.searchQuery,
      category: filter.category,
      dateRange: filter.dateRange,
    );
    final now = DateTime.now();
    final color = widget.isInvestment ? Colors.teal : Colors.deepOrange;
    final title = widget.isInvestment ? 'Investments' : 'Expenses';

    // When filters are active, the summary card should reflect the
    // filtered results rather than the fixed "this calendar month" total,
    // since a date-range filter can span outside the current month anyway.
    final filteredTotal = filteredRecords.fold<double>(
      0,
      (sum, r) => sum + r.amount,
    );
    final displayTotal = filter.hasActiveFilters
        ? filteredTotal
        : (widget.isInvestment
            ? state.monthlyInvestmentTotal(now)
            : state.monthlyExpenseTotal(now));
    final cardLabel = filter.hasActiveFilters
        ? '${filteredRecords.length} '
            '${filteredRecords.length == 1 ? 'result' : 'results'} ($title)'
        : 'This month ($title)';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Manage categories',
            onPressed: () {
              Navigator.pushNamed(
                context,
                widget.isInvestment
                    ? '/investment-categories'
                    : '/expense-categories',
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: Text('Add $title'),
      ),
      body: RefreshIndicator(
        onRefresh: () => state.refreshAll(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Card(
                color: color.withValues(alpha: 0.1),
                child: ListTile(
                  title: Text(cardLabel),
                  trailing: HideableAmount(
                    amount: formatAmount(displayTotal),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                    compact: true,
                  ),
                ),
              ),
            ),
            TransactionFilterBar(
              searchController: _searchController,
              categories: categories,
              selectedCategory: filter.category,
              selectedDateRange: filter.dateRange,
              hasActiveFilters: filter.hasActiveFilters,
              onCategoryChanged: (value) {
                state.setTransactionListFilter(
                  widget.isInvestment,
                  filter.copyWith(
                    category: value,
                    clearCategory: value == null,
                  ),
                );
              },
              onDateRangeChanged: (range) {
                state.setTransactionListFilter(
                  widget.isInvestment,
                  filter.withDateRange(range),
                );
              },
              onReset: _resetFilters,
            ),
            Expanded(
              child: filteredRecords.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Text(
                            allRecords.isEmpty
                                ? 'No entries yet. Tap + to add.'
                                : 'No entries match your search or filters.',
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: filteredRecords.length,
                      itemBuilder: (context, index) => _TransactionTile(
                        record: filteredRecords[index],
                        color: color,
                        isInvestment: widget.isInvestment,
                        onEdit: () =>
                            _openForm(context, filteredRecords[index]),
                        onDelete: () => _confirmDelete(
                          context,
                          filteredRecords[index],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openForm(BuildContext context, [TransactionRecord? existing]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(
          isInvestment: widget.isInvestment,
          existing: existing,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    TransactionRecord record,
  ) async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text(record.description),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await state.deleteTransaction(record.id,
          isInvestment: widget.isInvestment);
    }
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.record,
    required this.color,
    required this.isInvestment,
    required this.onEdit,
    required this.onDelete,
  });

  final TransactionRecord record;
  final Color color;
  final bool isInvestment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(
            isInvestment ? Icons.trending_up : Icons.receipt_long,
            color: color,
            size: 20,
          ),
        ),
        title: Text(record.description),
        subtitle: Text('${record.category} · ${formatDate(record.date)}'),
        trailing: Text(
          formatAmount(record.amount),
          style: TextStyle(fontWeight: FontWeight.w600, color: color),
        ),
        onTap: onEdit,
      ),
    );
  }
}