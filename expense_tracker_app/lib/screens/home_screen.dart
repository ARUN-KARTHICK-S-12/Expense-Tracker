import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../utils/formatters.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (!state.isConfigured) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wealth Tracker')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.link,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Connect your Google Sheet to get started. No Google Cloud account needed.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Settings'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pages = [
      _OverviewTab(onNavigate: (i) => setState(() => _index = i)),
      const TransactionsScreen(isInvestment: false),
      const TransactionsScreen(isInvestment: true),
      const DashboardScreen(),
    ];

    return Scaffold(
      body: state.loading && state.expenses.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          NavigationDestination(
            icon: Icon(Icons.trending_up_outlined),
            selectedIcon: Icon(Icons.trending_up),
            label: 'Investments',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Dashboard',
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wealth Tracker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: state.loading ? null : () => state.refreshAll(),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.refreshAll(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (state.error != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(state.error!),
                ),
              ),
            Text(
              'This month',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickCard(
                    title: 'Expenses',
                    amount: formatAmount(state.monthlyExpenseTotal(now)),
                    color: Colors.deepOrange,
                    icon: Icons.receipt_long,
                    onTap: () => onNavigate(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickCard(
                    title: 'Investments',
                    amount: formatAmount(state.monthlyInvestmentTotal(now)),
                    color: Colors.teal,
                    icon: Icons.trending_up,
                    onTap: () => onNavigate(2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Recent expenses',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...state.expenses.take(5).map(
                  (e) => ListTile(
                    leading: const Icon(Icons.receipt_long, size: 20),
                    title: Text(e.description),
                    subtitle: Text(e.category),
                    trailing: Text(formatAmount(e.amount)),
                    onTap: () => onNavigate(1),
                  ),
                ),
            if (state.expenses.isEmpty)
              const ListTile(title: Text('No expenses yet')),
            const SizedBox(height: 16),
            Text(
              'Recent investments',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...state.investments.take(5).map(
                  (e) => ListTile(
                    leading: const Icon(Icons.trending_up, size: 20),
                    title: Text(e.description),
                    subtitle: Text(e.category),
                    trailing: Text(formatAmount(e.amount)),
                    onTap: () => onNavigate(2),
                  ),
                ),
            if (state.investments.isEmpty)
              const ListTile(title: Text('No investments yet')),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => onNavigate(3),
              icon: const Icon(Icons.insights),
              label: const Text('View analytics dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String amount;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                amount,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
