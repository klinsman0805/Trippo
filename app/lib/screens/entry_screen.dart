import 'package:flutter/material.dart';

import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/trippo_logo.dart';

/// Where a trip starts from.
///
/// Three doors rather than one, because they are genuinely different jobs and
/// the app was worst at explaining the one it is best at. "Tap + to start
/// one" put the planner first and buried the thing people actually arrive
/// with — a post they already saved — behind a trip, a tab and a sheet.
enum TripIntent {
  /// A link already saved. The import sheet, as soon as there is a trip to
  /// import into.
  saved,

  /// A flight already booked. Its number gives the real schedule, which gives
  /// the dates and how much of the first and last day the flights leave.
  flight,

  /// Nothing yet. What the app did before.
  scratch,
}

/// Asks what somebody is starting from, before asking where they are going.
///
/// Pops the chosen [TripIntent], or null if they backed out.
class EntryScreen extends StatelessWidget {
  const EntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = WayfareTheme.of(context);

    return Scaffold(
      backgroundColor: WayfareColors.bgApp,
      appBar: AppBar(
        backgroundColor: WayfareColors.bgApp,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: WayfareColors.inkSecondary),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Close',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TrippoMark(size: 44),
              const SizedBox(height: 18),
              Text('A new trip', style: WayfareType.display(30)),
              const SizedBox(height: 8),
              const Text(
                'What have you got so far?',
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: WayfareColors.inkSecondary,
                ),
              ),
              const SizedBox(height: 22),

              // Saved places first, deliberately: the thing the app is best at
              // and the thing nobody could find.
              _Door(
                theme: theme,
                icon: Icons.link,
                title: 'I saved some places',
                blurb: 'Paste a post from 小红书, a blog, anywhere. Trippo reads '
                    'it and builds the days around what it found.',
                onTap: () => Navigator.of(context).pop(TripIntent.saved),
              ),
              _Door(
                theme: theme,
                icon: Icons.flight_takeoff,
                title: 'My flight is booked',
                blurb: 'Give the flight number. The real schedule sets the '
                    'dates — including how much of the first and last day is '
                    'left.',
                onTap: () => Navigator.of(context).pop(TripIntent.flight),
              ),
              _Door(
                theme: theme,
                icon: Icons.east,
                title: 'Just a destination',
                blurb: 'Somewhere in mind and nothing booked. Start from there.',
                onTap: () => Navigator.of(context).pop(TripIntent.scratch),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Door extends StatelessWidget {
  const _Door({
    required this.theme,
    required this.icon,
    required this.title,
    required this.blurb,
    required this.onTap,
  });

  final WayfareTheme theme;
  final IconData icon;
  final String title;
  final String blurb;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: WayfareColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: theme.cardLg,
          side: const BorderSide(color: WayfareColors.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: WayfareColors.accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: WayfareColors.ink,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        blurb,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.4,
                          color: WayfareColors.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: WayfareColors.border,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
