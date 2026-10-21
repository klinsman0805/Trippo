import 'package:flutter/material.dart' hide TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trippo/api/api_client.dart';
import 'package:trippo/api/trippo_api.dart';
import 'package:trippo/auth/session.dart';
import 'package:trippo/design/theme.dart';
import 'package:trippo/screens/account_sheet.dart';

class _FakeUserResponse extends Fake implements UserResponse {}

class _FakeSession extends Fake implements Session {
  _FakeSession(this.accessToken);

  @override
  final String accessToken;

  @override
  bool get isExpired => false;
}

/// Enough of GoTrue to drive the sheet: an address is free or it is taken,
/// and a code either works or it does not.
class _FakeAuth extends Fake implements GoTrueClient {
  _FakeAuth({this.taken = false});

  final bool taken;
  Session? session = _FakeSession('this-devices-anon');

  @override
  Session? get currentSession => session;

  @override
  User? get currentUser => null;

  @override
  Future<UserResponse> updateUser(UserAttributes attributes, {String? emailRedirectTo}) async {
    if (taken) {
      throw const AuthException('already registered', code: 'email_exists');
    }
    return _FakeUserResponse();
  }

  @override
  Future<void> signInWithOtp({
    String? email,
    String? phone,
    String? emailRedirectTo,
    bool? shouldCreateUser,
    Map<String, dynamic>? data,
    String? captchaToken,
    OtpChannel channel = OtpChannel.sms,
  }) async {}

  @override
  Future<AuthResponse> verifyOTP({
    String? email,
    String? phone,
    String? token,
    required OtpType type,
    String? redirectTo,
    String? captchaToken,
    String? tokenHash,
  }) async {
    session = _FakeSession('the-real-account');
    return AuthResponse();
  }
}

class _FakeApi extends TrippoApi {
  _FakeApi() : super(ApiClient(baseUrl: 'http://localhost:0'));

  String? handedOver;
  int moved = 2;

  @override
  Future<int> transferTrips(String fromAccessToken) async {
    handedOver = fromAccessToken;
    return moved;
  }
}

Future<void> _open(
  WidgetTester tester, {
  required AppSession session,
  required TrippoApi api,
  VoidCallback? onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      // Above the Navigator, as main.dart does it: a sheet builds against the
      // Navigator's context, so a theme provided inside the screen is not an
      // ancestor of it.
      builder: (context, child) => WayfareTheme(
        platform: WayfarePlatform.ios,
        child: child ?? const SizedBox.shrink(),
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showAccountSheet(
                context,
                session: session,
                api: api,
                onChanged: onChanged ?? () {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String label, String value) async {
  await tester.enterText(find.widgetWithText(TextField, label).first, value);
  await tester.pump();
}

void main() {
  group('Offering an address', () {
    testWidgets('a free one asks for the code it just sent', (tester) async {
      await _open(
        tester,
        session: AppSession.withAuth(_FakeAuth()),
        api: _FakeApi(),
      );

      expect(find.text('Keep your trips'), findsOne);
      await _type(tester, 'Email', 'mei@example.com');
      await tester.tap(find.text('Send me a code'));
      await tester.pumpAndSettle();

      expect(find.text('Check your email'), findsOne);
      expect(find.textContaining('mei@example.com'), findsOne);
    });

    testWidgets('a taken one says what will happen before asking', (tester) async {
      await _open(
        tester,
        session: AppSession.withAuth(_FakeAuth(taken: true)),
        api: _FakeApi(),
      );

      await _type(tester, 'Email', 'mei@example.com');
      await tester.tap(find.text('Send me a code'));
      await tester.pumpAndSettle();

      // The second-device case. What becomes of this phone's trips belongs
      // above the code field, not in a message afterwards.
      expect(find.text('Welcome back'), findsOne);
      expect(find.textContaining('comes with you'), findsOne);
      expect(find.text('Sign in'), findsOne);
    });
  });

  group('Confirming the code', () {
    testWidgets('hands the leaving token over, and says what followed',
        (tester) async {
      final api = _FakeApi();
      var reloaded = false;

      await _open(
        tester,
        session: AppSession.withAuth(_FakeAuth(taken: true)),
        api: api,
        onChanged: () => reloaded = true,
      );

      await _type(tester, 'Email', 'mei@example.com');
      await tester.tap(find.text('Send me a code'));
      await tester.pumpAndSettle();
      // Eight digits, as a real project configured it — six was an assumption
      // that made a live code impossible to type.
      await _type(tester, 'Code', '85757490');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      // The token of the user being left behind — read before the code was
      // verified, because a moment later the session is somebody else's.
      expect(api.handedOver, 'this-devices-anon');
      expect(find.textContaining('the 2 trips you planned on this phone'), findsOne);
      expect(reloaded, isTrue, reason: 'the list is stale once the owner changes');
    });

    testWidgets('links without moving anything when the address was free',
        (tester) async {
      final api = _FakeApi();

      await _open(tester, session: AppSession.withAuth(_FakeAuth()), api: api);
      await _type(tester, 'Email', 'mei@example.com');
      await tester.tap(find.text('Send me a code'));
      await tester.pumpAndSettle();
      await _type(tester, 'Code', '123456');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      // Same user throughout, so nothing was left behind to carry across.
      expect(api.handedOver, isNull);
      expect(find.textContaining('will be waiting'), findsOne);
    });
  });
}
