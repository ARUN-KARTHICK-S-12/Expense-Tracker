import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/analytics_data.dart';
import '../models/category_item.dart';
import '../models/transaction_list_filter.dart';
import '../models/transaction_record.dart';
import '../services/sheets_api_service.dart';

class AppState extends ChangeNotifier {
  AppState(this._api);

  final SheetsApiService _api;
  final _uuid = const Uuid();

  static const _expenseFilterPrefix = 'expense_list_filter';
  static const _investmentFilterPrefix = 'investment_list_filter';

  bool loading = false;
  String? error;

  List<TransactionRecord> expenses = [];
  List<TransactionRecord> investments = [];
  List<CategoryItem> expenseCategories = [];
  List<CategoryItem> investmentCategories = [];
  AnalyticsData? analytics;
  FilterPeriod analyticsPeriod = FilterPeriod.month;
  DateTime analyticsReferenceDate = DateTime.now();
  TransactionListFilter expenseListFilter = const TransactionListFilter();
  TransactionListFilter investmentListFilter = const TransactionListFilter();

  bool get isConfigured => _api.isConfigured;

  TransactionListFilter transactionListFilter(bool isInvestment) =>
      isInvestment ? investmentListFilter : expenseListFilter;

  Future<void> init() async {
    await _api.loadSavedUrl();
    await _loadSavedFilters();
    if (_api.isConfigured) {
      await refreshAll();
    }
    notifyListeners();
  }

  void setTransactionListFilter(
    bool isInvestment,
    TransactionListFilter filter,
  ) {
    if (isInvestment) {
      investmentListFilter = filter;
    } else {
      expenseListFilter = filter;
    }
    notifyListeners();
    _persistListFilter(isInvestment, filter);
  }

  void resetTransactionListFilter(bool isInvestment) {
    setTransactionListFilter(isInvestment, const TransactionListFilter());
  }

  Future<void> _loadSavedFilters() async {
    final prefs = await SharedPreferences.getInstance();
    expenseListFilter = _readListFilter(prefs, _expenseFilterPrefix);
    investmentListFilter = _readListFilter(prefs, _investmentFilterPrefix);
  }

  TransactionListFilter _readListFilter(
    SharedPreferences prefs,
    String prefix,
  ) {
    return TransactionListFilter(
      searchQuery: prefs.getString('${prefix}_search') ?? '',
      category: prefs.getString('${prefix}_category'),
      rangeStart: _parseStoredDate(prefs.getString('${prefix}_range_start')),
      rangeEnd: _parseStoredDate(prefs.getString('${prefix}_range_end')),
    );
  }

  DateTime? _parseStoredDate(String? value) =>
      value != null ? DateTime.tryParse(value) : null;

  Future<void> _persistListFilter(
    bool isInvestment,
    TransactionListFilter filter,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix =
        isInvestment ? _investmentFilterPrefix : _expenseFilterPrefix;

    await prefs.setString('${prefix}_search', filter.searchQuery);

    if (filter.category != null && filter.category!.isNotEmpty) {
      await prefs.setString('${prefix}_category', filter.category!);
    } else {
      await prefs.remove('${prefix}_category');
    }

    if (filter.rangeStart != null) {
      await prefs.setString(
        '${prefix}_range_start',
        filter.rangeStart!.toIso8601String(),
      );
    } else {
      await prefs.remove('${prefix}_range_start');
    }

    if (filter.rangeEnd != null) {
      await prefs.setString(
        '${prefix}_range_end',
        filter.rangeEnd!.toIso8601String(),
      );
    } else {
      await prefs.remove('${prefix}_range_end');
    }
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
