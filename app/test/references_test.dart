import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:trippo/api/api_client.dart';
import 'package:trippo/api/trippo_api.dart';
import 'package:trippo/design/features.dart';
import 'package:trippo/design/theme.dart';
import 'package:trippo/design/widgets.dart';
import 'package:trippo/screens/trip_list_screen.dart';
import 'package:trippo/models/trip.dart';
import 'package:trippo/screens/wayfare/formatting.dart';
import 'package:trippo/screens/wayfare/sources/import_sheet.dart';
import 'package:trippo/screens/wayfare/wayfare_shell.dart';
import 'package:trippo/screens/wayfare/sources/sources_screen.dart';
import 'package:trippo/state/wayfare_controller.dart';

/// Two things the app could not do before: say where a trip is going, and show
/// what it read.
///
/// The first was a plain bug — trips were created with a title and no
/// destination, `canGenerate` was false on every one of them, and the planner
/// was unreachable. The second is the product: a planner that claims to have
/// read your references has to be able to show you what it read.
void main() {
  Future<void> wrap(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, inner) => WayfareTheme(
          platform: WayfarePlatform.ios,
          child: inner ?? const SizedBox.shrink(),
        ),
        home: child,
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Creating a trip', () {
    late List<Map<String, dynamic>> created;

    TrippoApi stubbedApi() {
      created = [];
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/health')) {
          return http.Response(jsonEncode({'features': {}}), 200);
        }
        if (request.method == 'POST') {
          created.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({
              'trip': {
                'id': 'trip_new',
                'title': 'Bangkok',
                'destinations': ['Bangkok'],
                'currency': 'MYR',
                'member_count': 0,
              },
            }),
            201,
          );
        }
        return http.Response(jsonEncode({'trips': []}), 200);
      });
      return TrippoApi(ApiClient(baseUrl: 'http://stub', client: client));
    }

    testWidgets('asks where and in what money, and stores both',
        (tester) async {
      await wrap(
        tester,
        TripListScreen(api: stubbedApi(), onOpenTrip: (_, _) {}),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('Where are you going?'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Bangkok');
      await tester.pumpAndSettle();
      await tester.tap(find.text('฿ THB'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // The bug this fixes: a title is not a destination, and `canGenerate`
      // reads the destination. Sending only a title made every new trip
      // impossible to plan.
      expect(created.single['destinations'], ['Bangkok']);
      expect(created.single['title'], 'Bangkok');
      // And currency defaulted to USD in silence, which priced a Kuala
      // Lumpur trip in dollars.
      expect(created.single['currency'], 'THB');
    });

    testWidgets('will not create one with nowhere to go', (tester) async {
      await wrap(
        tester,
        TripListScreen(api: stubbedApi(), onOpenTrip: (_, _) {}),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      final create = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Create'),
      );
      expect(create.onPressed, isNull);

      await tester.enterText(find.byType(TextField).first, 'Bangkok');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Create'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('a currency outside the shortlist can still be typed',
        (tester) async {
      await wrap(
        tester,
        TripListScreen(api: stubbedApi(), onOpenTrip: (_, _) {}),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Hanoi');
      await tester.pumpAndSettle();

      // The shortlist is a shortcut, not a restriction — a trip to somewhere
      // outside it must not be unplannable.
      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'vnd');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(created.single['currency'], 'VND');
    });
  });

  group('Importing a link', () {
    /// [blocked] mimics 小红书: the fetch is refused, and the post's own text
    /// has to be pasted instead.
    WayfareController controllerWith({bool blocked = false}) {
      var manual = blocked;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/sources/url') ||
            request.url.path.endsWith('/sources/text')) {
          final wasManual = manual;
          manual = false; // The pasted text always completes it.
          return http.Response(
            jsonEncode({
              'source': {
                'id': 'src_1',
                'kind': 'xiaohongshu',
                'status': wasManual ? 'needs_manual' : 'extracted',
                'title': 'Bangkok in 4 days',
              },
              'manual_input_required': wasManual,
              'places': wasManual
                  ? []
                  : [
                      {
                        'id': 'plc_1',
                        'name': 'Jay Fai',
                        'category': 'food',
                        'why': 'The crab omelette everyone queues for',
                      },
                      {'id': 'plc_2', 'name': 'Wat Pho', 'category': 'sight'},
                    ],
              'summary': 'A four-day eating route through the old town.',
            }),
            201,
          );
        }
        return http.Response(jsonEncode({}), 200);
      });

      return WayfareController(
        TrippoApi(ApiClient(baseUrl: 'http://stub', client: client)),
        'trip_1',
      );
    }

    testWidgets('says what it found rather than closing silently',
        (tester) async {
      await wrap(
        tester,
        Scaffold(body: ImportLinkSheet(controller: controllerWith())),
      );

      await tester.enterText(find.byType(TextField), 'https://xhslink.com/abc');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      // The count is the whole point: an import that returns you to the
      // itinerary in silence feels like it did nothing.
      expect(find.text('2 places from this one'), findsOneWidget);
      expect(find.text('Jay Fai'), findsOneWidget);
      expect(
        find.text('The crab omelette everyone queues for'),
        findsOneWidget,
      );
    });

    testWidgets('a blocked fetch asks for the text instead of failing',
        (tester) async {
      await wrap(
        tester,
        Scaffold(
          body: ImportLinkSheet(controller: controllerWith(blocked: true)),
        ),
      );

      await tester.enterText(find.byType(TextField), 'https://xhslink.com/abc');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import'));
      await tester.pumpAndSettle();

      // Not an error — the link is stored, and the post's own text is the one
      // thing we cannot fetch ourselves.
      expect(find.text('Paste the post itself'), findsOneWidget);
      expect(find.text('Pull the places out'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Jay Fai, Wat Pho …');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pull the places out'));
      await tester.pumpAndSettle();

      expect(find.text('2 places from this one'), findsOneWidget);
    });
  });

  group('The references screen', () {
    WayfareController controllerWith({required bool empty}) {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/sources')) {
          return http.Response(
            jsonEncode({
              'sources': empty
                  ? []
                  : [
                      {
                        'id': 'src_1',
                        'kind': 'xiaohongshu',
                        'status': 'extracted',
                        'title': 'Bangkok in 4 days',
                        'place_count': 2,
                      },
                      {
                        'id': 'src_2',
                        'kind': 'web',
                        'status': 'needs_manual',
                        'url': 'https://example.com/post',
                        'place_count': 0,
                      },
                    ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/places')) {
          return http.Response(
            jsonEncode({
              'places': empty
                  ? []
                  : [
                      {
                        'id': 'plc_1',
                        'name': 'Jay Fai',
                        'category': 'food',
                        'source_id': 'src_1',
                      },
                      {
                        'id': 'plc_2',
                        'name': 'Wat Pho',
                        'category': 'sight',
                        'source_id': 'src_1',
                      },
                    ],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({}), 200);
      });

      return WayfareController(
        TrippoApi(ApiClient(baseUrl: 'http://stub', client: client)),
        'trip_1',
      );
    }

    testWidgets('lists every import and what came out of it', (tester) async {
      await wrap(
        tester,
        SourcesScreen(controller: controllerWith(empty: false)),
      );

      expect(find.text('Bangkok in 4 days'), findsOneWidget);
      expect(find.text('2 places'), findsOneWidget);
      // A blocked source says so, and offers the way to finish it.
      expect(
        find.text('Blocked — it needs the post text pasted in'),
        findsOneWidget,
      );
      expect(find.text('Paste the post text'), findsOneWidget);
      expect(find.textContaining('2 sources · 2 places'), findsOneWidget);
    });

    testWidgets('the places are behind the source that found them',
        (tester) async {
      await wrap(
        tester,
        SourcesScreen(controller: controllerWith(empty: false)),
      );

      // Collapsed: the list is an index, not the places list again.
      expect(find.text('Jay Fai'), findsNothing);
      await tester.tap(find.text('Bangkok in 4 days'));
      await tester.pumpAndSettle();

      expect(find.text('Jay Fai'), findsOneWidget);
      expect(find.text('Wat Pho'), findsOneWidget);
    });

    testWidgets('with nothing imported, it argues for importing something',
        (tester) async {
      await wrap(
        tester,
        SourcesScreen(controller: controllerWith(empty: true)),
      );

      // The header says it too, so both the subtitle and the body state it.
      expect(find.text('Nothing imported yet'), findsNWidgets(2));
      expect(
        find.textContaining('you already found the places'),
        findsOneWidget,
      );
      expect(find.widgetWithText(WayfarePrimaryButton, 'Import a link'),
          findsOneWidget);
    });
  });

  group('What the imports produced', () {
    Place place(String name) => Place(id: name, name: name);

    testWidgets('is named back, so an import is visible from the trip',
        (tester) async {
      await wrap(
        tester,
        Scaffold(
          body: ImportedPlacesCard(
            places: [
              place('Petronas Twin Towers'),
              place('Pavilion Bukit Bintang'),
              place('VCR'),
              place('Jay Fai'),
            ],
            sourceCount: 1,
            onSeeAll: () {},
            onImportMore: () {},
            awaitingDates: true,
          ),
        ),
      );

      // The bug: eight places came back and the screen behind the sheet
      // looked exactly as it had before, so the import read as a no-op.
      expect(find.text('4 places from 1 link'), findsOneWidget);
      expect(
        find.text('Petronas Twin Towers, Pavilion Bukit Bintang, VCR and 1 more.'),
        findsOneWidget,
      );
      // Without dates they cannot be planned yet, so it says what they wait on.
      expect(find.textContaining('Set your dates'), findsOneWidget);
      expect(find.text('See all 4'), findsOneWidget);
    });

    testWidgets('says nothing at all when nothing has been imported',
        (tester) async {
      await wrap(
        tester,
        Scaffold(
          body: ImportedPlacesCard(
            places: const [],
            sourceCount: 0,
            onSeeAll: () {},
            onImportMore: () {},
          ),
        ),
      );

      expect(find.textContaining('from your links'), findsNothing);
    });

    test('categories read as a traveller would say them', () {
      // The stored vocabulary is the extractor's and stays as it is; these
      // are the words on screen.
      expect(categoryLabel('lodging'), 'accommodation');
      expect(categoryLabel('sight'), 'destination');
      expect(categoryLabel('food'), 'food');
      expect(categoryLabel('shopping'), 'shopping');
    });
  });

  group('The generating screen', () {
    testWidgets('shows time spent, and what the run is working from',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, inner) => WayfareTheme(
            platform: WayfarePlatform.ios,
            child: inner ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(
            body: Stack(
              children: [GeneratingOverlay(placeCount: 8, dayCount: 4)],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Working from 8 saved places across 4 days.'),
        findsOneWidget,
      );
      expect(find.text('0s'), findsOneWidget);

      // The bar is drawn from elapsed time against a typical run: it moves
      // from the first frame, and eases rather than marching.
      double fraction() =>
          tester.widget<WayfareBar>(find.byType(WayfareBar)).fraction;
      expect(fraction(), 0);

      // The ticker sets state during the frame, so the value it produced is
      // visible on the next one.
      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      final early = fraction();
      expect(early, greaterThan(0.2));

      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      final later = fraction();
      expect(later, greaterThan(early));
      // Decelerating — the longer it runs, the less the bar knows.
      expect(later - early, lessThan(early));
      expect(find.text('20s'), findsOneWidget);
    });

    testWidgets('never claims to be finished', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, inner) => WayfareTheme(
            platform: WayfarePlatform.ios,
            child: inner ?? const SizedBox.shrink(),
          ),
          home: const Scaffold(
            body: Stack(children: [GeneratingOverlay()]),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(minutes: 5));
      await tester.pump();

      // A bar that reaches 100% and then sits there is a lie told slowly.
      expect(
        tester.widget<WayfareBar>(find.byType(WayfareBar)).fraction,
        lessThan(1.0),
      );
      expect(find.textContaining('Still going'), findsOneWidget);
      expect(find.text('5m 00s'), findsOneWidget);
    });
  });

  group('Before the trip has dates', () {
    testWidgets('splits the two ways in, and hides flight shopping',
        (tester) async {
      await wrap(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: NoDatesYet(
              onEnterBookedFlight: () {},
              onOpenFlights: () {},
              onSetDatesByHand: () {},
              onGoToGroup: () {},
              memberCount: 0,
            ),
          ),
        ),
      );

      // One instruction, not an explanation of our internals followed by a
      // question the reader cannot answer yet.
      expect(find.text('Set your dates'), findsOneWidget);
      expect(
        find.textContaining('The planner builds around your dates'),
        findsNothing,
      );

      // Two ways in, each under its own heading.
      expect(find.text('IF YOU ARE FLYING'), findsOneWidget);
      expect(find.text('IF YOU ARE NOT'), findsOneWidget);
      expect(find.text('Enter flight number'), findsOneWidget);
      expect(find.text('Set dates myself'), findsOneWidget);

      // Fare shopping is behind a flag: the provider is mock, so the prices
      // are invented and nothing can be booked from here.
      expect(
        find.text('Search flights'),
        WayfareFeatures.flightSearch ? findsOneWidget : findsNothing,
      );

      // Importing belongs after the dates, where the places have days to go
      // on. This screen is one decision.
      expect(find.text('Import a link'), findsNothing);
    });

    test('a subtitle that repeats the title is dropped', () {
      // "Bangkok" under a heading reading Bangkok said nothing twice.
      expect(
        destinationsSubtitle(['Bangkok'], null, null, omit: 'Bangkok'),
        '',
      );
      expect(
        destinationsSubtitle(
          ['Bangkok'],
          '2026-09-26',
          '2026-09-29',
          omit: 'Bangkok',
        ),
        '26 Sept–29 Sept',
      );
      // A trip named something else keeps its route.
      expect(
        destinationsSubtitle(['Lisbon', 'Porto'], null, null, omit: 'Portugal'),
        'Lisbon → Porto',
      );
    });
  });
}
