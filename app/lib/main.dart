import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'api/trippo_api.dart';
import 'config.dart';
import 'design/theme.dart';
import 'screens/trip_list_screen.dart';
import 'screens/wayfare/flights/flights_screen.dart';
import 'screens/wayfare/wayfare_shell.dart';

void main() {
  final api = TrippoApi(ApiClient(baseUrl: AppConfig.apiBaseUrl));
  runApp(TrippoApp(api: api));
}

class TrippoApp extends StatelessWidget {
  const TrippoApp({super.key, required this.api, this.platformOverride});

  final TrippoApi api;

  /// Forces an iOS or Android dress. Null follows the host OS — set this to
  /// preview the other platform without changing devices.
  final WayfarePlatform? platformOverride;

  @override
  Widget build(BuildContext context) {
    final platform = platformOverride ?? WayfareTheme.hostPlatform();

    // Boot straight into one trip, skipping the list. Handy for iterating on a
    // single screen without re-navigating on every hot restart:
    //   flutter run --dart-define=TRIPPO_TRIP_ID=trip_abc123
    const directTripId =
        String.fromEnvironment('TRIPPO_TRIP_ID', defaultValue: '');
    // Dev-only: jump straight to a pushed screen, e.g. TRIPPO_SCREEN=flights.
    const directScreen =
        String.fromEnvironment('TRIPPO_SCREEN', defaultValue: '');

    return MaterialApp(
      title: 'Wayfare',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(platform),
      home: directTripId.isNotEmpty && directScreen == 'flights'
          ? _FlightsPreview(api: api, tripId: directTripId, platform: platform)
          : directTripId.isNotEmpty
          ? WayfareShell(
              api: api,
              tripId: directTripId,
              platformOverride: platformOverride,
            )
          // The design covers a single trip; picking which trip happens before
          // the shell, which the handoff doesn't specify either way.
          : TripListScreen(
              api: api,
              onOpenTrip: (context, tripId) => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => WayfareShell(
                    api: api,
                    tripId: tripId,
                    platformOverride: platformOverride,
                  ),
                ),
              ),
            ),
    );
  }
}


/// Dev-only entry that loads a trip and pushes straight into Flights.
class _FlightsPreview extends StatelessWidget {
  const _FlightsPreview({
    required this.api,
    required this.tripId,
    required this.platform,
  });

  final TrippoApi api;
  final String tripId;
  final WayfarePlatform platform;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: api.getTrip(tripId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return WayfareTheme(
          platform: platform,
          child: FlightsScreen(
            api: api,
            trip: snapshot.data!,
            onSelected: (_, _) {},
          ),
        );
      },
    );
  }
}
