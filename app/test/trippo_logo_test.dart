import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:trippo/design/tokens.dart';
import 'package:trippo/design/trippo_logo.dart';

void main() {
  group('The logo keeps its own colours', () {
    test('and they are still the ones the app is painted in', () {
      // Deliberately its own constants rather than reading the tokens: a logo
      // that follows the palette can be recoloured by somebody retuning the
      // UI, and the kit asks for the opposite — "don't recolour individual
      // parts". This is the alarm for the two drifting apart, not a link
      // between them.
      expect(TrippoBrandColors.accent, WayfareColors.accent);
      expect(TrippoBrandColors.accentDark, WayfareColors.accentDark);
      expect(TrippoBrandColors.ink, WayfareColors.ink);
      expect(TrippoBrandColors.cream, WayfareColors.bgApp);
      expect(TrippoBrandColors.surface, WayfareColors.surface);
    });
  });

  group('The mark, the pin and the lockup', () {
    testWidgets('each draw at the size they are given', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TrippoMark(size: 40),
                TrippoPin(size: 40),
                TrippoLogo(height: 56),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // `.first` because TrippoLogo draws a TrippoMark of its own, so the
      // type matches twice on this screen.
      expect(tester.getSize(find.byType(TrippoMark).first), const Size(40, 40));
      expect(tester.getSize(find.byType(TrippoPin).first), const Size(40, 40));
      expect(tester.getSize(find.byType(TrippoLogo)).height, 56);
    });

    testWidgets('the pin says where its point is, for a map to anchor to',
        (tester) async {
      // A marker hung by its centre floats above the place it marks.
      expect(TrippoPin.tipAlignment, isA<Alignment>());
    });
  });

  group('The animation', () {
    testWidgets('plays once and says when the intro is done', (tester) async {
      var done = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TrippoLogoAnimation(
              height: 120,
              loop: false,
              onIntroComplete: () => done = true,
            ),
          ),
        ),
      );

      expect(done, isFalse, reason: 'not before it has played');
      // The intro runs inside the 6s loop; well past it, it has to have fired
      // or a splash screen waiting on it would wait forever.
      // Discrete pumps, not pumpAndSettle: the wave controller repeats for
      // as long as the widget lives, so nothing containing this ever settles.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(done, isTrue);
    });

    testWidgets('holds still, and finishes at once, when motion is reduced',
        (tester) async {
      var done = false;
      await tester.pumpWidget(
        MediaQuery(
          // What the widget reads: MediaQuery.disableAnimationsOf, which is
          // what the OS switch arrives as.
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            home: Scaffold(
              body: TrippoLogoAnimation(
                height: 120,
                loop: false,
                onIntroComplete: () => done = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Nobody should be held on a splash screen waiting for an animation
      // they have asked not to see.
      expect(done, isTrue);
    });
  });
}
