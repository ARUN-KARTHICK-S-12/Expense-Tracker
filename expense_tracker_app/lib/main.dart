import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'screens/categories_screen.dart';
import 'screens/home_screen.dart';
import 'services/sheets_api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final api = SheetsApiService();
  runApp(ExpenseTrackerApp(api: api));
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key, required this.api});

  final SheetsApiService api;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(api)..init(),
      child: MaterialApp(
        title: 'Expense Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
        routes: {
          '/expense-categories': (_) =>
              const CategoriesScreen(isInvestment: false),
          '/investment-categories': (_) =>
              const CategoriesScreen(isInvestment: true),
        },
      ),
    );
  }
}
