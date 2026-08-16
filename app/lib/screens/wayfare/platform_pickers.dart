import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter/material.dart' as m show TimeOfDay, showTimePicker;

import '../../design/theme.dart';
import '../../design/tokens.dart';

/// Pick a time in whichever dress the platform wears.
///
/// iOS gets the scrolling wheel, Android the Material dial — the same
/// one-component-two-dresses rule the rest of the app follows. Reaching for
/// `showTimePicker` everywhere put an Android clock face, in Material purple,
/// on an iPhone.
///
/// Both show 12-hour with AM/PM, which is how times are read aloud in the
/// markets this is being built for.
///
/// The value returned is still 24-hour `HH:MM`. Storage and display formats
/// are separate concerns: a picker is about how a person enters a time, and
/// keeping one canonical form underneath means nothing downstream — sorting,
/// the envelope, the API — has to parse an AM/PM string.
///
/// Returns `HH:MM`, or null if dismissed.
Future<String?> pickWayfareTime(
  BuildContext context, {
  String? initial,
}) async {
  final theme = WayfareTheme.of(context);
  final parts = initial?.split(':');
  final hour = int.tryParse(parts?.elementAtOrNull(0) ?? '') ?? 9;
  final minute = int.tryParse(parts?.elementAtOrNull(1) ?? '') ?? 0;

  if (theme.isAndroid) {
    final picked = await m.showTimePicker(
      context: context,
      initialTime: m.TimeOfDay(hour: hour, minute: minute),
      builder: (context, child) => MediaQuery(
        // Pinned rather than left to the locale, so both dresses ask the
        // question the same way whatever device it runs on.
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    return picked == null ? null : _hhmm(picked.hour, picked.minute);
  }

  // The wheel needs a full DateTime to spin; only the clock part is read back.
  var draft = DateTime(2000, 1, 1, hour, minute);

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: WayfareColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(theme.sheetRadius)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: WayfareColors.mutedLight),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: WayfareColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 216,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: false,
              initialDateTime: draft,
              onDateTimeChanged: (d) => draft = d,
            ),
          ),
        ],
      ),
    ),
  );

  return (confirmed ?? false) ? _hhmm(draft.hour, draft.minute) : null;
}

/// Pick a date in whichever dress the platform wears.
///
/// Same reasoning as [pickWayfareTime]: the scrolling wheel on iOS, the
/// Material calendar on Android. Shared rather than written per screen —
/// each site that rolled its own reached for `showDatePicker`, which put a
/// Material calendar on iPhones.
Future<DateTime?> pickWayfareDate(
  BuildContext context, {
  DateTime? initial,
  required DateTime first,
  required DateTime last,
}) async {
  final theme = WayfareTheme.of(context);
  final start = (initial ?? first).isBefore(first) ? first : (initial ?? first);

  if (theme.isAndroid) {
    return showDatePicker(
      context: context,
      initialDate: start,
      firstDate: first,
      lastDate: last,
    );
  }

  var draft = start;
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: WayfareColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(theme.sheetRadius)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: WayfareColors.mutedLight),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: WayfareColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 240,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: draft,
              minimumDate: first,
              maximumDate: last,
              onDateTimeChanged: (d) => draft = DateTime(d.year, d.month, d.day),
            ),
          ),
        ],
      ),
    ),
  );

  return (confirmed ?? false) ? draft : null;
}

String _hhmm(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
