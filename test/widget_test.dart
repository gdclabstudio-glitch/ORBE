import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    // Minimal smoke test that does not initialize app-level services (Firebase, etc.)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(appBar: AppBar(title: const Text('LABOMBA 2027'))),
      ),
    );

    expect(find.text('LABOMBA 2027'), findsOneWidget);
  });
}
