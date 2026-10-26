import 'dart:async';

import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:trippo/screens/landing_screen.dart';

/// Discrete pumps throughout: the logo's wave controller repeats for as long
/// as the widget lives, so nothing containing it ever settles.
Future<void> _run(WidgetTester tester, {int seconds = 8}) async {
  for (var i = 0; i < seconds; i++) {
    await tester.pump(const Duration(seconds: 1));
  }
}

Future<void> _pumpLanding(
  WidgetTester tester, {
  required Future<void> ready,
  required VoidCallback onReady,
}) =>
    tester.pumpWidget(
      MaterialApp(home: LandingScreen(ready: ready, onReady: onReady)),
    );

void main() {
  group('Leaving the landing screen', () {
    testWidgets('waits for the session even after the hippo has finished',
        (tester) async {
      final session = Completer<void>();
      var left = false;
      await _pumpLanding(
        tester,
        ready: session.future,
        onReady: () => left = true,
      );

      await _run(tester);
      expect(left, isFalse,
          reason: 'the intro is not a loading bar; there is nowhere to go yet');

      session.complete();
      await tester.pump();
      await tester.pump();
      expect(left, isTrue);
    });

    testWidgets('still plays once when the session was already there',
        (tester) async {
      var left = false;
      await _pumpLanding(
        tester,
        ready: Future<void>.value(),
        onReady: () => left = true,
      );
      await tester.pump();

      // Otherwise the logo flashes past in a frame, which is worse than not
      // showing it at all.
      expect(left, isFalse);

      await _run(tester);
      expect(left, isTrue);
    });

    testWidgets('hands over once, not twice', (tester) async {
      var count = 0;
      await _pumpLanding(
        tester,
        ready: Future<void>.value(),
        onReady: () => count++,
      );
      await _run(tester, seconds: 12);

      // Both conditions are checked from two places, and a second call would
      // push a second copy of the trip list onto the navigator.
      expect(count, 1);
    });

    testWidgets('says nothing to a screen reader beyond the name',
        (tester) async {
      await _pumpLanding(
        tester,
        ready: Future<void>.value(),
        onReady: () {},
      );
      await tester.pump();

      // The letters arrive one at a time; announced individually they would
      // read as six separate labels.
      expect(find.bySemanticsLabel('Trippo'), findsOne);
    });
  });
}
