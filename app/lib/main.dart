import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'auth/session.dart';
import 'api/trippo_api.dart';
import 'config.dart';
import 'design/theme.dart';
import 'screens/landing_screen.dart';
import 'screens/trip_list_screen.dart';
import 'screens/wayfare/flights/flights_screen.dart';
import 'screens/wayfare/wayfare_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Not awaited. Signing in reaches the network, and awaiting it here held
  // the first frame behind it — the launch image, then nothing, for as long
  // as it took. The landing screen fills that now, so the sign-in runs
  // beside it rather than in front of it.
  final session = AppSession.start();

  // The client takes functions, not a token, so it can be built before there
  // is a session and wait for one per request. Anything that fires early
  // queues behind the same future the landing screen is watching.
  final api = TrippoApi(
    ApiClient(
      baseUrl: AppConfig.apiBaseUrl,
      accessToken: () async => (await session)?.accessToken(),
      refreshSession: () async => (await session)?.refresh(),
    ),
  );
  runApp(TrippoApp(api: api, signingIn: session));
}

class TrippoApp extends StatelessWidget {
  const TrippoApp({
    super.key,
    required this.api,
    this.session,
    this.signingIn,
    this.platformOverride,
  });

  final TrippoApi api;

  /// Null when the app is built without Supabase — against a local server
  /// that does not ask who you are, there is no account to keep.
  ///
  /// Set directly only by tests and by [signingIn] once it resolves.
  final AppSession? session;

  /// The sign-in still in flight, when there is one.
  ///
  /// Present, the app opens on the landing screen and waits for it. Absent —
  /// which is how tests build this — it goes straight to the trip list, so a
  /// test does not have to sit through six seconds of hippo to reach the
  /// thing it is testing.
  final Future<AppSession?>? signingIn;

  /// Forces an iOS or Android dress. Null follows the host OS — set this to
  /// preview the other platform without changing devices.
  final WayfarePlatform? platformOverride;

  @override
  Widget build(BuildContext context) {
    final platform = platformOverride ?? WayfareTheme.hostPlatform();

    // Boot straight into one trip, skipping the list. Handy for iterating on a
    // single screen without re-navigating on every hot restart:
    //   flutter run --dart-define=TRIPPO_TRIP_ID=trip_abc123
    // Read here only to decide whether to open on the landing screen; which
    // screen it then builds is _home's business.
    const directTripId =
        String.fromEnvironment('TRIPPO_TRIP_ID', defaultValue: '');

    return MaterialApp(
      title: 'Wayfare',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(platform),
      // Above the Navigator, so routes, dialogs and sheets all inherit it.
      //
      // Providing the theme inside a screen instead looks like it works until
      // something opens in the root overlay — showDialog and
      // showModalBottomSheet build against the Navigator's context, which is
      // an *ancestor* of the screen that called them, so any widget in there
      // asserting on WayfareTheme.of would fail.
      builder: (context, child) => WayfareTheme(
        platform: platform,
        child: child ?? const SizedBox.shrink(),
      ),
      // Dev entries skip the landing screen: the point of them is to reach
      // one screen quickly, and a six-second hippo on every hot restart is
      // the opposite of that.
      home: signingIn == null || directTripId.isNotEmpty
          ? _home(platform, session)
          : _Opening(
              signingIn: signingIn!,
              build: (ready) => _home(platform, ready),
            ),
    );
  }

  Widget _home(WayfarePlatform platform, AppSession? session) {
    const directTripId =
        String.fromEnvironment('TRIPPO_TRIP_ID', defaultValue: '');
    const directScreen =
        String.fromEnvironment('TRIPPO_SCREEN', defaultValue: '');

    return directTripId.isNotEmpty && directScreen == 'flights'
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
              session: session,
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
            );
  }
}

/// Holds the landing screen until the sign-in lands, then builds the app.
///
/// The screen decides when to leave — it waits for the intro *and* this
/// future, whichever is second — so the logo is never cut short and never
/// outstays a session that arrived first.
class _Opening extends StatefulWidget {
  const _Opening({required this.signingIn, required this.build});

  final Future<AppSession?> signingIn;
  final Widget Function(AppSession? session) build;

  @override
  State<_Opening> createState() => _OpeningState();
}

class _OpeningState extends State<_Opening> {
  AppSession? _session;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    widget.signingIn.then((session) {
      if (mounted) _session = session;
    });
  }

  @override
  Widget build(BuildContext context) => _open
      ? widget.build(_session)
      : LandingScreen(
          // `ignore` on purpose: a sign-in that fails still opens the app,
          // as an anonymous user retried on the first request. Holding the
          // landing screen for it would strand somebody on a hippo.
          ready: widget.signingIn.then<void>((_) {}, onError: (_) {}),
          onReady: () => setState(() => _open = true),
        );
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
