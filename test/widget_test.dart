// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:campus_fund/main.dart';

void main() {
  testWidgets('login screen renders mobile input and send otp button', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Welcome to Campus Fund'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '9876543210');
    expect(find.text('9876543210'), findsOneWidget);
  });

  testWidgets('otp screen renders and accepts a 6-digit code', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OtpScreen(
          mobile: '9876543210',
          verificationId: 'test-verification-id',
        ),
      ),
    );

    expect(find.text('OTP sent to +91 9876543210'), findsOneWidget);
    expect(find.text('Verify'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    expect(find.text('123456'), findsOneWidget);
  });

  testWidgets('bottom navigation opens each dashboard section', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));

    await tester.tap(find.byIcon(Icons.description_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Application progress'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.payments_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Outstanding balance'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Campus Fund account'), findsOneWidget);
  });
}
