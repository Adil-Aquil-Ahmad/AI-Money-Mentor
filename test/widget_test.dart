// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:ethackathon/main.dart';

void main() {
  testWidgets('Money Mentor App loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MoneyMentorApp());

    // Verify that Money Mentor is displayed
    expect(find.text('Money Mentor'), findsOneWidget);
  });
}
