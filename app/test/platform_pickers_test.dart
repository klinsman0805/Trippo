import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippo/design/theme.dart';
import 'package:trippo/screens/wayfare/platform_pickers.dart';

/// One component, two dresses — the rule the rest of the app follows, and the
/// one every hand-rolled `showTimePicker` call was quietly breaking. A Material
/// clock face in Material purple on an iPhone is the symptom.
Future<void> pumpPicker(
  WidgetTester tester,
  WayfarePlatform platform, {
  required Future<void> Function(BuildContext) onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => WayfareTheme(
        platform: platform,
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => onTap(context),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('Time picker', () {
    testWidgets('iOS gets the scrolling wheel', (tester) async {
      await pumpPicker(
        tester,
        WayfarePlatform.ios,
        onTap: (context) => pickWayfareTime(context, initial: '16:55'),
      );

      expect(find.byType(CupertinoDatePicker), findsOneWidget);
      final picker =
          tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
      expect(picker.mode, CupertinoDatePickerMode.time);
      // Every time this app shows is 24-hour; an AM/PM picker would ask the
      // user to translate their own boarding pass on the way in.
      expect(picker.use24hFormat, isTrue);
      expect(picker.initialDateTime.hour, 16);
      expect(picker.initialDateTime.minute, 55);

      // And no Material dial anywhere near it.
      expect(find.text('Select time'), findsNothing);
    });

    testWidgets('Android gets the Material dial, in 24 hours', (tester) async {
      await pumpPicker(
        tester,
        WayfarePlatform.android,
        onTap: (context) => pickWayfareTime(context, initial: '16:55'),
      );

      expect(find.byType(CupertinoDatePicker), findsNothing);
      expect(find.text('Select time'), findsOneWidget);
      // 24-hour there too, so the two dresses agree on what a time looks like.
      expect(find.text('AM'), findsNothing);
      expect(find.text('PM'), findsNothing);
    });
  });

  group('Date picker', () {
    testWidgets('iOS gets the wheel, bounded by the range given',
        (tester) async {
      await pumpPicker(
        tester,
        WayfarePlatform.ios,
        onTap: (context) => pickWayfareDate(
          context,
          initial: DateTime(2026, 9, 26),
          first: DateTime(2026, 9, 20),
          last: DateTime(2026, 12, 31),
        ),
      );

      final picker =
          tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
      expect(picker.mode, CupertinoDatePickerMode.date);
      expect(picker.minimumDate, DateTime(2026, 9, 20));
      expect(picker.initialDateTime, DateTime(2026, 9, 26));
    });

    testWidgets('an initial date before the range is clamped, not rejected',
        (tester) async {
      await pumpPicker(
        tester,
        WayfarePlatform.ios,
        onTap: (context) => pickWayfareDate(
          context,
          // A return leg still holding a date earlier than a newly chosen
          // outbound: the wheel must open on the earliest allowed day rather
          // than assert.
          initial: DateTime(2026, 9, 1),
          first: DateTime(2026, 9, 20),
          last: DateTime(2026, 12, 31),
        ),
      );

      final picker =
          tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
      expect(picker.initialDateTime, DateTime(2026, 9, 20));
    });

    testWidgets('Android gets the Material calendar', (tester) async {
      await pumpPicker(
        tester,
        WayfarePlatform.android,
        onTap: (context) => pickWayfareDate(
          context,
          initial: DateTime(2026, 9, 26),
          first: DateTime(2026, 9, 20),
          last: DateTime(2026, 12, 31),
        ),
      );

      expect(find.byType(CupertinoDatePicker), findsNothing);
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });
}
