import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:trippo/design/theme.dart';
import 'package:trippo/screens/entry_screen.dart';

Widget _app(Widget home) => MaterialApp(
      builder: (context, child) => WayfareTheme(
        platform: WayfarePlatform.ios,
        child: child ?? const SizedBox.shrink(),
      ),
      home: home,
    );

/// Opens the screen the way the trip list does — pushed, so popping it
/// returns a value — and reports what came back.
Future<TripIntent?> _choose(WidgetTester tester, String door) async {
  TripIntent? chosen;

  await tester.pumpWidget(
    _app(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                chosen = await Navigator.of(context).push<TripIntent>(
                  MaterialPageRoute(builder: (_) => const EntryScreen()),
                );
              },
              child: const Text('new'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('new'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(door));
  await tester.pumpAndSettle();
  return chosen;
}

void main() {
  group('Which door a new trip comes through', () {
    testWidgets('saved places', (tester) async {
      expect(await _choose(tester, 'I saved some places'), TripIntent.saved);
    });

    testWidgets('a booked flight', (tester) async {
      expect(await _choose(tester, 'My flight is booked'), TripIntent.flight);
    });

    testWidgets('nothing but a destination', (tester) async {
      expect(await _choose(tester, 'Just a destination'), TripIntent.scratch);
    });

    testWidgets('offers the saved-places door first', (tester) async {
      await tester.pumpWidget(_app(const EntryScreen()));
      await tester.pump();

      // Deliberate order, and the whole argument for the screen: reading a
      // post the traveller already saved is what the app is best at, and it
      // used to sit three taps deep behind a planner nobody asked for.
      final shown = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .toList();
      expect(
        shown.indexOf('I saved some places'),
        lessThan(shown.indexOf('My flight is booked')),
      );
      expect(
        shown.indexOf('My flight is booked'),
        lessThan(shown.indexOf('Just a destination')),
      );
    });

    testWidgets('backing out chooses nothing', (tester) async {
      // Closing is not the same as picking the least committal door: no trip
      // should be created at all.
      TripIntent? chosen;
      var returned = false;

      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    chosen = await Navigator.of(context).push<TripIntent>(
                      MaterialPageRoute(builder: (_) => const EntryScreen()),
                    );
                    returned = true;
                  },
                  child: const Text('new'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('new'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(returned, isTrue);
      expect(chosen, isNull);
    });
  });
}
