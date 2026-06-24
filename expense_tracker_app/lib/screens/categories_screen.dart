import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key, required this.isInvestment});

  final bool isInvestment;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final categories =
        isInvestment ? state.investmentCategories : state.expenseCategories;
    final title = isInvestment ? 'Investment' : 'Expense';

    return Scaffold(
      appBar: AppBar(title: Text('$title Categories')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add),
      ),
      body: categories.isEmpty
          ? const Center(child: Text('No categories yet'))
          : ListView.separated(
              itemCount: categories.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final cat = categories[index];
                return ListTile(
                  leading: Icon(
                    cat.isCustom ? Icons.edit : Icons.label,
                    color: cat.isCustom
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline,
                  ),
                  title: Text(cat.name),
                  subtitle: Text(cat.isCustom ? 'Custom' : 'Predefined'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _showEditDialog(context, cat.name),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final controller = TextEditingController();
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok == true && controller.text.trim().isNotEmpty) {
      final success = await state.addCategory(
        controller.text.trim(),
        isInvestment: isInvestment,
      );
      if (context.mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error ?? 'Failed to add category')),
        );
      }
    }
    controller.dispose();
  }

  Future<void> _showEditDialog(BuildContext context, String oldName) async {
    final controller = TextEditingController(text: oldName);
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true &&
        controller.text.trim().isNotEmpty &&
        controller.text.trim() != oldName) {
      final success = await state.renameCategory(
        oldName,
        controller.text.trim(),
        isInvestment: isInvestment,
      );
      if (context.mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error ?? 'Failed to rename')),
        );
      }
    }
    controller.dispose();
  }
}
