import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:labomba_app/widgets/reaction_bar.dart';

void main() {
  testWidgets('ReactionBar toggles counts and calls onChanged', (
    WidgetTester tester,
  ) async {
    final events = <MapEntry<String, bool>>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ReactionBar(
              initialCounts: {'❤️': 2, '🔥': 1},
              onChanged: (emoji, added) {
                events.add(MapEntry(emoji, added));
              },
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // find first emoji (❤️) and tap it
    final heartFinder = find.text('❤️');
    expect(heartFinder, findsWidgets);
    await tester.tap(heartFinder.first);
    await tester.pumpAndSettle();

    // onChanged should be called once
    expect(events.isNotEmpty, isTrue);
    expect(events.first.key, '❤️');
    // Added should be true because it was not selected initially
    expect(events.first.value, isTrue);

    // tapping again should toggle off
    await tester.tap(heartFinder.first);
    await tester.pumpAndSettle();
    expect(events.length, 2);
    expect(events[1].key, '❤️');
    expect(events[1].value, isFalse);
  });
}
