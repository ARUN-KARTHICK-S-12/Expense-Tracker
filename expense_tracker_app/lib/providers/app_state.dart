import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/analytics_data.dart';
import '../models/category_item.dart';
import '../models/transaction_record.dart';
import '../services/sheets_api_service.dart';

class AppState extends ChangeNotifier {
  AppState(this._api);

  final SheetsApiService _api;
  final _uuid = const Uuid();

  bool loading = false;
  String? error;

  List<TransactionRecord> expenses = [];
  List<TransactionRecord> investments = [];
  List<CategoryItem> expenseCategories = [];
  List<CategoryItem> investmentCategories = [];
  AnalyticsData? analytics;
  FilterPeriod analyticsPeriod = FilterPeriod.month;
  DateTime analyticsReferenceDate = DateTime.now();

  bool get isConfigured => _api.isConfigured;

  Future<void> init() async {
    await _api.loadSavedUrl();
    if (_api.isConfigured) {
      await refreshAll();
    }
    notifyListeners();
  }

  Future<void> saveWebAppUrl(String url) async {
    await _api.saveUrl(url);
    await _api.setupSheets();
    await refreshAll();
  }

  Future<void> refreshAll() async {
    if (!_api.isConfigured) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      await Future.wait([
        loadExpenses(),
        loadInvestments(),
        loadCategories(),
        loadAnalytics(),
      ]);
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadExpenses() async {
    expenses = await _api.getExpenses();
  }

  Future<void> loadInvestments() async {
    investments = await _api.getInvestments();
  }

  Future<void> loadCategories() async {
    expenseCategories = await _api.getExpenseCategories();
    investmentCategories = await _api.getInvestmentCategories();
  }

  Future<void> loadAnalytics() async {
    analytics = await _api.getAnalytics(
      period: analyticsPeriod,
      referenceDate: analyticsReferenceDate,
    );
  }

  void setAnalyticsPeriod(FilterPeriod period) {
    analyticsPeriod = period;
    loadAnalytics().then((_) => notifyListeners());
  }

  void setAnalyticsReferenceDate(DateTime date) {
    analyticsReferenceDate = date;
    loadAnalytics().then((_) => notifyListeners());
  }

  List<String> categoryNames(bool forInvestment) {
    final list = forInvestment ? investmentCategories : expenseCategories;
    return list.map((c) => c.name).toList();
  }

  double monthlyExpenseTotal([DateTime? ref]) {
    final now = ref ?? DateTime.now();
    return expenses
        .where((e) =>
            e.date.year == now.year && e.date.month == now.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double monthlyInvestmentTotal([DateTime? ref]) {
    final now = ref ?? DateTime.now();
    return investments
        .where((e) =>
            e.date.year == now.year && e.date.month == now.month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  Future<bool> saveTransaction({
    required bool isInvestment,
    TransactionRecord? existing,
    required String description,
    required String category,
    required double amount,
    required DateTime date,
  }) async {
    try {
      final record = TransactionRecord(
        id: existing?.id ?? _uuid.v4(),
        description: description,
        category: category,
        amount: amount,
        date: date,
      );
      if (existing != null) {
        if (isInvestment) {
          await _api.updateInvestment(record);
        } else {
          await _api.updateExpense(record);
        }
      } else {
        if (isInvestment) {
          await _api.addInvestment(record);
        } else {
          await _api.addExpense(record);
        }
      }
      await refreshAll();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTransaction(String id, {required bool isInvestment}) async {
    try {
      if (isInvestment) {
        await _api.deleteInvestment(id);
      } else {
        await _api.deleteExpense(id);
      }
      await refreshAll();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> addCategory(String name, {required bool isInvestment}) async {
    try {
      if (isInvestment) {
        await _api.addInvestmentCategory(name);
      } else {
        await _api.addExpenseCategory(name);
      }
      await loadCategories();
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> renameCategory(
    String oldName,
    String newName, {
    required bool isInvestment,
  }) async {
    try {
      if (isInvestment) {
        await _api.updateInvestmentCategory(oldName, newName);
      } else {
        await _api.updateExpenseCategory(oldName, newName);
      }
      await refreshAll();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
