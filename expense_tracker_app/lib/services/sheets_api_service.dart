import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/json_helpers.dart';
import '../models/analytics_data.dart';
import '../models/category_item.dart';
import '../models/transaction_record.dart';

class SheetsApiService {
  static const _urlKey = 'google_apps_script_web_app_url';

  static const _headers = {
    'Accept': 'application/json, text/plain, */*',
    'User-Agent': 'Mozilla/5.0 (compatible; ExpenseTracker/1.0)',
  };

  String? _baseUrl;

  String? get baseUrl => _baseUrl;
  bool get isConfigured => _baseUrl != null && _baseUrl!.isNotEmpty;

  Future<void> loadSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = _normalizeUrl(prefs.getString(_urlKey));
  }

  Future<void> saveUrl(String url) async {
    final normalized = _normalizeUrl(url);
    if (normalized == null || normalized.isEmpty) {
      throw Exception('URL cannot be empty');
    }
    _validateWebAppUrl(normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, normalized);
    _baseUrl = normalized;
  }

  /// Strips whitespace and trailing slashes. Returns null if input is null/empty.
  String? _normalizeUrl(String? url) {
    if (url == null) return null;
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed.isEmpty ? null : trimmed;
  }

  void _validateWebAppUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw Exception('Invalid URL format');
    }
    if (url.contains('docs.google.com/spreadsheets')) {
      throw Exception(
        'That is the Google Sheet link, not the Web App URL.\n'
        'Use Deploy → Manage deployments → copy the URL ending in /exec',
      );
    }
    if (!url.contains('script.google.com/macros/s/')) {
      throw Exception(
        'URL must be a Google Apps Script Web App link:\n'
        'https://script.google.com/macros/s/.../exec',
      );
    }
    if (!url.endsWith('/exec') && !url.endsWith('/dev')) {
      throw Exception('Web App URL must end with /exec (or /dev for testing)');
    }
  }

  Uri _uri(String action, [Map<String, String>? query]) {
    if (!isConfigured) {
      throw Exception('Configure your Google Apps Script URL in Settings');
    }
    final params = {'action': action, ...?query};
    return Uri.parse(_baseUrl!).replace(queryParameters: params);
  }

  /// Google Apps Script web apps redirect once; GET + query params is the
  /// most reliable approach from Flutter (POST bodies are lost on redirect).
  Future<Map<String, dynamic>> _request(
    String action, [
    Map<String, String>? query,
  ]) async {
    final uri = _uri(action, query);
    final response = await http.get(uri, headers: _headers);
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.trim();

    if (body.startsWith('<!') || body.startsWith('<html')) {
      if (body.contains('accounts.google.com') ||
          body.contains('ServiceLogin') ||
          body.contains('signin')) {
        throw Exception(
          'Google returned a sign-in page instead of JSON.\n\n'
          'Fix your Apps Script deployment:\n'
          '1. Deploy → Manage deployments → Edit (pencil)\n'
          '2. Execute as: Me\n'
          '3. Who has access: Anyone  ← must be "Anyone", NOT "Anyone with Google account"\n'
          '4. New version → Deploy\n'
          '5. Paste the new /exec URL in Settings',
        );
      }
      throw Exception(
        'Server returned HTML instead of JSON (status ${response.statusCode}).\n'
        'Confirm the URL ends with /exec and the web app is deployed.',
      );
    }

    if (response.statusCode != 200) {
      throw Exception('Server error: ${response.statusCode}');
    }

    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (data['success'] != true && data['error'] != null) {
        throw Exception(jsonString(data['error']));
      }
      return data;
    } on FormatException {
      throw Exception(
        'Invalid JSON from server. Check the Web App URL and redeploy Code.gs.',
      );
    }
  }

  Future<void> setupSheets() async {
    await _request('setup');
  }

  Future<List<TransactionRecord>> getExpenses() async {
    final data = await _request('getExpenses');
    return _parseRecords(data['data']);
  }

  Future<List<TransactionRecord>> getInvestments() async {
    final data = await _request('getInvestments');
    return _parseRecords(data['data']);
  }

  List<TransactionRecord> _parseRecords(dynamic list) {
    if (list is! List) return [];
    return list
        .map((e) => TransactionRecord.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<List<CategoryItem>> getExpenseCategories() async {
    final data = await _request('getExpenseCategories');
    return _parseCategories(data['data']);
  }

  Future<List<CategoryItem>> getInvestmentCategories() async {
    final data = await _request('getInvestmentCategories');
    return _parseCategories(data['data']);
  }

  List<CategoryItem> _parseCategories(dynamic list) {
    if (list is! List) return [];
    return list
        .map((e) => CategoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> _mutate(Map<String, dynamic> fields) async {
    final action = fields['action'] as String;
    final query = fields.map((k, v) => MapEntry(k, v.toString()));
    return _request(action, query);
  }

  Future<String> addExpense(TransactionRecord record) async {
    final data = await _mutate({...record.toJson(), 'action': 'addExpense'});
    return data['id'] != null ? jsonString(data['id']) : record.id;
  }

  Future<String> addInvestment(TransactionRecord record) async {
    final data =
        await _mutate({...record.toJson(), 'action': 'addInvestment'});
    return data['id'] != null ? jsonString(data['id']) : record.id;
  }

  Future<void> updateExpense(TransactionRecord record) async {
    await _mutate({...record.toJson(), 'action': 'updateExpense'});
  }

  Future<void> updateInvestment(TransactionRecord record) async {
    await _mutate({...record.toJson(), 'action': 'updateInvestment'});
  }

  Future<void> deleteExpense(String id) async {
    await _mutate({'action': 'deleteExpense', 'id': id});
  }

  Future<void> deleteInvestment(String id) async {
    await _mutate({'action': 'deleteInvestment', 'id': id});
  }

  Future<void> addExpenseCategory(String name) async {
    await _mutate({'action': 'addExpenseCategory', 'name': name});
  }

  Future<void> addInvestmentCategory(String name) async {
    await _mutate({'action': 'addInvestmentCategory', 'name': name});
  }

  Future<void> updateExpenseCategory(String oldName, String newName) async {
    await _mutate({
      'action': 'updateExpenseCategory',
      'oldName': oldName,
      'newName': newName,
    });
  }

  Future<void> updateInvestmentCategory(String oldName, String newName) async {
    await _mutate({
      'action': 'updateInvestmentCategory',
      'oldName': oldName,
      'newName': newName,
    });
  }

  Future<AnalyticsData> getAnalytics({
    required FilterPeriod period,
    DateTime? referenceDate,
  }) async {
    final date = referenceDate ?? DateTime.now();
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final data = await _request('analytics', {
      'period': period.apiValue,
      'type': 'both',
      'date': dateStr,
    });
    return AnalyticsData.fromJson(data);
  }
}
