import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/transaction_record.dart';
import '../providers/app_state.dart';
import '../utils/formatters.dart';
import 'transaction_form_screen.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key, required this.isInvestment});

  final bool isInvestment;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final records = isInvestment ? state.investments : state.expenses;
    final now = DateTime.now();
    final monthlyTotal = isInvestment
        ? state.monthlyInvestmentTotal(now)
        : state.monthlyExpenseTotal(now);
    final color = isInvestment ? Colors.teal : Colors.deepOrange;
    final title = isInvestment ? 'Investments' : 'Expenses';

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
                isInvestment ? '/investment-categories' : '/expense-categories',
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
              padding: const EdgeInsets.all(16),
              child: Card(
                color: color.withValues(alpha: 0.1),
                child: ListTile(
                  title: Text('This month ($title)'),
                  trailing: Text(
                    formatAmount(monthlyTotal),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: records.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('No entries yet. Tap + to add.')),
                      ],
                    )
                  : ListView.builder(
                      itemCount: records.length,
                      itemBuilder: (context, index) =>
                          _TransactionTile(
                        record: records[index],
                        color: color,
                        isInvestment: isInvestment,
                        onEdit: () => _openForm(context, records[index]),
                        onDelete: () => _confirmDelete(context, records[index]),
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
          isInvestment: isInvestment,
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
      await state.deleteTransaction(record.id, isInvestment: isInvestment);
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
