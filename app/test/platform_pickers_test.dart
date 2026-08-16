import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trippo/design/theme.dart';
import 'package:trippo/screens/wayfare/formatting.dart';
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
  group('Clock formatting', () {
    test('renders 24-hour data as 12-hour, including the awkward ends', () {
      // Midnight and noon are where naive conversions produce "0:00 AM"
      // and "0:00 PM".
      expect(formatClock('00:00'), '12:00 AM');
      expect(formatClock('12:00'), '12:00 PM');
      expect(formatClock('00:30'), '12:30 AM');
      expect(formatClock('12:30'), '12:30 PM');

      expect(formatClock('09:05'), '9:05 AM');
      expect(formatClock('16:55'), '4:55 PM');
      expect(formatClock('18:45'), '6:45 PM');
      expect(formatClock('23:59'), '11:59 PM');
    });

    test('leaves anything it cannot read alone', () {
      // Better an unconverted string than a confidently wrong time.
      expect(formatClock(''), '');
      expect(formatClock('not a time'), 'not a time');
      expect(formatClock('7'), '7');
    });
  });

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
      // 12-hour with AM/PM, as asked for.
      expect(picker.use24hFormat, isFalse);
      // The wheel still opens on the right moment: 16:55 is 4:55 PM, and the
      // value handed back stays 24-hour whatever the wheel shows.
      expect(picker.initialDateTime.hour, 16);
      expect(picker.initialDateTime.minute, 55);

      // And no Material dial anywhere near it.
      expect(find.text('Select time'), findsNothing);
    });

    testWidgets('Android gets the Material dial, also 12-hour', (tester) async {
      await pumpPicker(
        tester,
        WayfarePlatform.android,
        onTap: (context) => pickWayfareTime(context, initial: '16:55'),
      );

      expect(find.byType(CupertinoDatePicker), findsNothing);
      expect(find.text('Select time'), findsOneWidget);
      // Both dresses ask the question the same way, rather than one following
      // the device locale and the other not.
      expect(find.text('AM'), findsOneWidget);
      expect(find.text('PM'), findsOneWidget);
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
