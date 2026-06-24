import 'package:expense_tracker_app/main.dart';
import 'package:expense_tracker_app/services/sheets_api_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows setup prompt when not configured', (tester) async {
    await tester.pumpWidget(ExpenseTrackerApp(api: SheetsApiService()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Connect your Google Sheet'), findsOneWidget);
  });
}
