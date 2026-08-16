import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippo/api/api_client.dart';
import 'package:trippo/api/trippo_api.dart';
import 'package:trippo/design/theme.dart';
import 'package:trippo/main.dart';

/// The theme has to be an ancestor of the Navigator, not of one screen.
///
/// `showDialog` and `showModalBottomSheet` build against the Navigator's
/// context, which is an *ancestor* of whatever called them. A theme provided
/// inside a screen is therefore invisible to its own dialogs, and any widget
/// in there calling `WayfareTheme.of` trips the assert — which is exactly what
/// happened to the "New trip" dialog on the trip list.
///
/// These pump the real `TrippoApp` rather than a hand-built harness. A test
/// that supplies its own theme wrapper cannot catch a missing one.
void main() {
  TrippoApp app() => TrippoApp(
        api: TrippoApi(ApiClient(baseUrl: 'http://localhost:0')),
        platformOverride: WayfarePlatform.ios,
      );

  testWidgets('a dialog opened from the root overlay resolves the theme',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    // Reach into the app's own Navigator, the way showDialog does.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    WayfarePlatform? seenInDialog;
    unawaited(
      showDialog<void>(
        context: navigator.context,
        builder: (dialogContext) {
          seenInDialog = WayfareTheme.of(dialogContext).platform;
          return const SizedBox.shrink();
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(
      seenInDialog,
      WayfarePlatform.ios,
      reason: 'the dialog must inherit the app-level theme, override included',
    );
  });

  testWidgets('the trip list screen itself still resolves the theme',
      (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    // It no longer provides its own, so this proves it inherits one.
    expect(find.text('Your trips'), findsOneWidget);
    expect(
      WayfareTheme.of(tester.element(find.text('Your trips'))).platform,
      WayfarePlatform.ios,
    );
  });

  testWidgets('an unreachable server lands in the error state, not a crash',
      (tester) async {
    // Nothing is listening on port 0, and flutter_test answers every request
    // with a bare 400 — which is exactly the empty-bodied failure that used
    // to be decoded as success and crash the caller downstream.
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text("Can't reach the server"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
