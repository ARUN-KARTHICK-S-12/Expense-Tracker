import 'package:intl/intl.dart';

final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
final dateFormat = DateFormat.yMMMd();
final shortDateFormat = DateFormat.MMMd();

String formatAmount(double amount) => currencyFormat.format(amount);
String formatDate(DateTime date) => dateFormat.format(date);
