/**
 * Expense Tracker — Google Apps Script backend (no GCP required).
 *
 * Deploy: Deploy → New deployment → Web app
 *   Execute as: Me | Who has access: Anyone
 * First run: YOUR_URL?action=setup
 */

var SHEETS = {
  EXPENSES: 'Expenses',
  INVESTMENTS: 'Investments',
  EXPENSE_CATEGORIES: 'ExpenseCategories',
  INVESTMENT_CATEGORIES: 'InvestmentCategories'
};

var DEFAULT_EXPENSE_CATEGORIES = [
  'Food', 'Transport', 'Utilities', 'Rent', 'Shopping',
  'Healthcare', 'Entertainment', 'Education', 'Other'
];

var DEFAULT_INVESTMENT_CATEGORIES = [
  'Stocks', 'Mutual Funds', 'Fixed Deposit', 'Crypto',
  'Real Estate', 'Gold', 'PPF', 'Other'
];

function doGet(e) {
  return handleRequest_(e, 'GET');
}

function doPost(e) {
  return handleRequest_(e, 'POST');
}

/**
 * Run once from the Apps Script editor (select this function → Run).
 * Does not need a web URL or ?action= query string.
 */
function runSetup() {
  var result = setupSheets_();
  Logger.log(JSON.stringify(result));
  return result;
}

function parseParams_(e) {
  e = e || {};
  var params = {};

  if (e.parameter) {
    for (var key in e.parameter) {
      if (e.parameter.hasOwnProperty(key)) {
        params[key] = e.parameter[key];
      }
    }
  }

  if (e.queryString) {
    var pairs = String(e.queryString).split('&');
    for (var i = 0; i < pairs.length; i++) {
      var pair = pairs[i];
      if (!pair) continue;
      var eq = pair.indexOf('=');
      var k = eq >= 0 ? pair.substring(0, eq) : pair;
      var v = eq >= 0 ? pair.substring(eq + 1) : '';
      params[decodeURIComponent(k)] = decodeURIComponent(
        String(v).replace(/\+/g, ' ')
      );
    }
  }

  // Alternative URL: .../exec/setup  (works when ?action= is stripped by redirect)
  if (e.pathInfo) {
    var pathAction = String(e.pathInfo).split('/')[0].trim();
    if (pathAction && !params.action) {
      params.action = pathAction;
    }
  }

  return params;
}

function handleRequest_(e, method) {
  try {
    e = e || {};
    var params = parseParams_(e);
    if (method === 'POST' && e.postData && e.postData.contents) {
      var body = JSON.parse(e.postData.contents);
      for (var key in body) {
        if (body.hasOwnProperty(key)) params[key] = body[key];
      }
    }
    var action = (params.action || '').toString().toLowerCase().trim();

    // GET and POST — mobile clients use GET (GAS POST redirects break JSON POST bodies).
    var mutation = processMutation_(action, params);
    if (mutation) return jsonResponse_(mutation);

    var result;
    switch (action) {
      case 'setup':
        result = setupSheets_();
        break;
      case 'getexpenses':
        result = getRecords_(SHEETS.EXPENSES);
        break;
      case 'getinvestments':
        result = getRecords_(SHEETS.INVESTMENTS);
        break;
      case 'getexpensecategories':
        result = getCategories_(SHEETS.EXPENSE_CATEGORIES);
        break;
      case 'getinvestmentcategories':
        result = getCategories_(SHEETS.INVESTMENT_CATEGORIES);
        break;
      case 'analytics':
        result = getAnalytics_(params);
        break;
      default:
        if (!action) {
          result = {
            success: false,
            error: 'Missing action parameter.',
            help: [
              'Option A — In Apps Script: select runSetup → click Run (no URL needed).',
              'Option B — Browser: YOUR_DEPLOY_URL?action=setup',
              'Option C — Browser: YOUR_DEPLOY_URL/setup (path after /exec/)',
              'Use the Web app URL ending in /exec from Deploy → Manage deployments.',
              'Do not use Run on doGet in the editor; that sends no query string.'
            ]
          };
        } else {
          result = { success: false, error: 'Unknown action: ' + action };
        }
    }
    return jsonResponse_(result);
  } catch (err) {
    return jsonResponse_({ success: false, error: String(err) });
  }
}

function processMutation_(action, params) {
  switch (action) {
    case 'addexpense':
      return addRecord_(SHEETS.EXPENSES, params);
    case 'addinvestment':
      return addRecord_(SHEETS.INVESTMENTS, params);
    case 'updateexpense':
      return updateRecord_(SHEETS.EXPENSES, params);
    case 'updateinvestment':
      return updateRecord_(SHEETS.INVESTMENTS, params);
    case 'deleteexpense':
      return deleteRecord_(SHEETS.EXPENSES, params.id);
    case 'deleteinvestment':
      return deleteRecord_(SHEETS.INVESTMENTS, params.id);
    case 'addexpensecategory':
      return addCategory_(SHEETS.EXPENSE_CATEGORIES, params.name);
    case 'addinvestmentcategory':
      return addCategory_(SHEETS.INVESTMENT_CATEGORIES, params.name);
    case 'updateexpensecategory':
      return updateCategory_(SHEETS.EXPENSE_CATEGORIES, params.oldName, params.newName, SHEETS.EXPENSES);
    case 'updateinvestmentcategory':
      return updateCategory_(SHEETS.INVESTMENT_CATEGORIES, params.oldName, params.newName, SHEETS.INVESTMENTS);
    default:
      return null;
  }
}

function jsonResponse_(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function setupSheets_() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  ensureSheet_(ss, SHEETS.EXPENSES, ['id', 'description', 'category', 'amount', 'date']);
  ensureSheet_(ss, SHEETS.INVESTMENTS, ['id', 'description', 'category', 'amount', 'date']);
  ensureSheet_(ss, SHEETS.EXPENSE_CATEGORIES, ['name', 'isCustom']);
  ensureSheet_(ss, SHEETS.INVESTMENT_CATEGORIES, ['name', 'isCustom']);
  seedCategories_(ss, SHEETS.EXPENSE_CATEGORIES, DEFAULT_EXPENSE_CATEGORIES);
  seedCategories_(ss, SHEETS.INVESTMENT_CATEGORIES, DEFAULT_INVESTMENT_CATEGORIES);
  return { success: true, message: 'Sheets initialized.' };
}

function ensureSheet_(ss, name, headers) {
  var sheet = ss.getSheetByName(name);
  if (!sheet) sheet = ss.insertSheet(name);
  if (sheet.getLastRow() === 0) sheet.appendRow(headers);
}

function seedCategories_(ss, sheetName, defaults) {
  var sheet = ss.getSheetByName(sheetName);
  if (sheet.getLastRow() > 1) return;
  for (var i = 0; i < defaults.length; i++) {
    sheet.appendRow([defaults[i], 'false']);
  }
}

function getRecords_(sheetName) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(sheetName);
  if (!sheet || sheet.getLastRow() < 2) return { success: true, data: [] };
  var values = sheet.getRange(2, 1, sheet.getLastRow()-1, 5).getValues();
  var data = values.map(function (row) {
    return {
      id: String(row[0]),
      description: String(row[1]),
      category: String(row[2]),
      amount: Number(row[3]),
      date: formatDate_(row[4])
    };
  });
  return { success: true, data: data };
}

function getCategories_(sheetName) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(sheetName);
  if (!sheet || sheet.getLastRow() < 2) return { success: true, data: [] };
  var values = sheet.getRange(2, 1, sheet.getLastRow(), 2).getValues();
  var data = values.map(function (row) {
    return { name: String(row[0]), isCustom: String(row[1]).toLowerCase() === 'true' };
  });
  return { success: true, data: data };
}

function formatDate_(value) {
  if (value instanceof Date) {
    return Utilities.formatDate(value, Session.getScriptTimeZone(), 'yyyy-MM-dd');
  }
  return String(value);
}

function parseDate_(str) {
  var parts = String(str).split('-');
  if (parts.length === 3) {
    return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
  }
  return new Date(str);
}

function addRecord_(sheetName, payload) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(sheetName);
  var id = payload.id || Utilities.getUuid();
  sheet.appendRow([
    id,
    payload.description || '',
    payload.category || 'Other',
    Number(payload.amount) || 0,
    parseDate_(payload.date || new Date())
  ]);
  return { success: true, id: id };
}

function updateRecord_(sheetName, payload) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(sheetName);
  var row = findRowById_(sheet, payload.id);

  if (row < 0) {
    return { success: false, error: 'Record not found' };
  }

  sheet.getRange(row, 2, 1, 4).setValues([[
    payload.description || '',
    payload.category || 'Other',
    Number(payload.amount) || 0,
    parseDate_(payload.date)
  ]]);

  return { success: true };
}

function deleteRecord_(sheetName, id) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(sheetName);
  var row = findRowById_(sheet, id);
  if (row < 0) return { success: false, error: 'Record not found' };
  sheet.deleteRow(row);
  return { success: true };
}

function findRowById_(sheet, id) {
  var last = sheet.getLastRow();
  if (last < 2) return -1;
  var ids = sheet.getRange(2, 1, last-1, 1).getValues();
  for (var i = 0; i < ids.length; i++) {
    if (String(ids[i][0]) === String(id)) return i + 2;
  }
  return -1;
}

function addCategory_(sheetName, name) {
  var trimmed = String(name).trim();
  if (!trimmed) return { success: false, error: 'Category name required' };
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(sheetName);
  var existing = getCategoryNames_(sheet);
  if (existing.indexOf(trimmed.toLowerCase()) >= 0) {
    return { success: true, message: 'Category already exists' };
  }
  sheet.appendRow([trimmed, 'true']);
  return { success: true };
}

function updateCategory_(sheetName, oldName, newName, recordSheet) {
  var oldT = String(oldName).trim();
  var newT = String(newName).trim();
  if (!newT) return { success: false, error: 'New name required' };
  var catSheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(sheetName);
  var names = getCategoryNamesWithRows_(catSheet);
  var found = false;
  for (var i = 0; i < names.length; i++) {
    if (names[i].name.toLowerCase() === oldT.toLowerCase()) {
      catSheet.getRange(names[i].row, 1).setValue(newT);
      found = true;
      break;
    }
  }
  if (!found) return { success: false, error: 'Category not found' };
  updateCategoryInRecords_(recordSheet, oldT, newT);
  return { success: true };
}

function getCategoryNames_(sheet) {
  if (sheet.getLastRow() < 2) return [];
  var values = sheet.getRange(2, 1, sheet.getLastRow(), 1).getValues();
  return values.map(function (r) { return String(r[0]).toLowerCase(); });
}

function getCategoryNamesWithRows_(sheet) {
  if (sheet.getLastRow() < 2) return [];
  var values = sheet.getRange(2, 1, sheet.getLastRow(), 1).getValues();
  var out = [];
  for (var i = 0; i < values.length; i++) {
    out.push({ name: String(values[i][0]), row: i + 2 });
  }
  return out;
}

function updateCategoryInRecords_(recordSheetName, oldName, newName) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(recordSheetName);
  if (sheet.getLastRow() < 2) return;
  var cats = sheet.getRange(2, 3, sheet.getLastRow(), 3).getValues();
  for (var i = 0; i < cats.length; i++) {
    if (String(cats[i][0]).toLowerCase() === oldName.toLowerCase()) {
      sheet.getRange(i + 2, 3).setValue(newName);
    }
  }
}

function getAnalytics_(params) {
  var period = (params.period || 'month').toLowerCase();
  var type = (params.type || 'both').toLowerCase();
  var refDate = params.date ? parseDate_(params.date) : new Date();
  var result = { success: true, period: period, expenses: [], investments: [] };

  if (type === 'expense' || type === 'both') {
    result.expenses = aggregateByPeriod_(SHEETS.EXPENSES, period, refDate);
  }
  if (type === 'investment' || type === 'both') {
    result.investments = aggregateByPeriod_(SHEETS.INVESTMENTS, period, refDate);
  }
  if (type === 'both') {
    result.categoryBreakdown = {
      expenses: categoryBreakdown_(SHEETS.EXPENSES, period, refDate),
      investments: categoryBreakdown_(SHEETS.INVESTMENTS, period, refDate)
    };
  }
  return result;
}

function aggregateByPeriod_(sheetName, period, refDate) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(sheetName);
  if (!sheet || sheet.getLastRow() < 2) return [];
  var range = getDateRangeForPeriod_(period, refDate);
  var values = sheet.getRange(2, 1, sheet.getLastRow()-1, 5).getValues();
  var buckets = {};
  for (var i = 0; i < values.length; i++) {
    var d = values[i][4] instanceof Date ? values[i][4] : parseDate_(values[i][4]);
    if (d < range.start || d > range.end) continue;
    var key = bucketKey_(d, period);
    var amt = Number(values[i][3]) || 0;
    buckets[key] = (buckets[key] || 0) + amt;
  }
  return Object.keys(buckets).sort().map(function (k) {
    return { label: k, total: buckets[k] };
  });
}

function categoryBreakdown_(sheetName, period, refDate) {
  var sheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(sheetName);
  if (!sheet || sheet.getLastRow() < 2) return [];
  var range = getDateRangeForPeriod_(period, refDate);
  var values = sheet.getRange(2, 1, sheet.getLastRow()-1, 5).getValues();
  var buckets = {};
  for (var i = 0; i < values.length; i++) {
    var d = values[i][4] instanceof Date ? values[i][4] : parseDate_(values[i][4]);
    if (d < range.start || d > range.end) continue;
    var cat = String(values[i][2]) || 'Other';
    var amt = Number(values[i][3]) || 0;
    buckets[cat] = (buckets[cat] || 0) + amt;
  }
  return Object.keys(buckets).map(function (c) {
    return { category: c, total: buckets[c] };
  }).sort(function (a, b) { return b.total - a.total; });
}

function getDateRangeForPeriod_(period, refDate) {
  var start = new Date(refDate);
  var end = new Date(refDate);
  end.setHours(23, 59, 59, 999);
  if (period === 'day') {
    start.setHours(0, 0, 0, 0);
    return { start: start, end: end };
  }
  if (period === 'week') {
    var day = start.getDay();
    var diff = day === 0 ? 6 : day - 1;
    start.setDate(start.getDate() - diff);
    start.setHours(0, 0, 0, 0);
    end = new Date(start);
    end.setDate(end.getDate() + 6);
    end.setHours(23, 59, 59, 999);
    return { start: start, end: end };
  }
  if (period === 'year') {
    start = new Date(refDate.getFullYear(), 0, 1);
    end = new Date(refDate.getFullYear(), 11, 31, 23, 59, 59, 999);
    return { start: start, end: end };
  }
  start = new Date(refDate.getFullYear(), refDate.getMonth(), 1);
  end = new Date(refDate.getFullYear(), refDate.getMonth() + 1, 0, 23, 59, 59, 999);
  return { start: start, end: end };
}

function bucketKey_(date, period) {
  var tz = Session.getScriptTimeZone();
  if (period === 'day') return Utilities.formatDate(date, tz, 'yyyy-MM-dd HH:00');
  if (period === 'year') return Utilities.formatDate(date, tz, 'yyyy-MM');
  return Utilities.formatDate(date, tz, 'yyyy-MM-dd');
}
