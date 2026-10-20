import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trippo/api/api_client.dart';
import 'package:trippo/auth/session.dart';

class _FakeUserResponse extends Fake implements UserResponse {}

class _FakeSession extends Fake implements Session {
  _FakeSession(this.accessToken, {this.expired = false});

  @override
  final String accessToken;
  final bool expired;

  @override
  bool get isExpired => expired;
}

/// How a refresh fails — and, just as importantly, what the real client does
/// with the session on its way out.
enum _RefreshFailure {
  /// The network, or a 5xx. GoTrueClient keeps the session and rethrows.
  retryable,

  /// The refresh token is dead. GoTrueClient drops the session before it
  /// throws, which is why the fake below does too: without that it was
  /// modelling a client that does not exist, and the difference between these
  /// two cases is the whole point of [AppSession.refresh].
  refused,
}

/// Counts sign-ins, and can be made slow, so overlapping callers overlap.
///
/// `signOut` is deliberately not implemented: [Fake] throws on anything it
/// does not override, so a session that signs out on the way to a refresh
/// fails loudly here. Retiring an anonymous user is unrecoverable, and this is
/// the tripwire that says so.
class _FakeAuth extends Fake implements GoTrueClient {
  Session? session;
  int signIns = 0;
  int refreshes = 0;
  _RefreshFailure? refreshFailure;
  Completer<void>? gate;

  @override
  Session? get currentSession => session;

  @override
  Future<AuthResponse> signInAnonymously({
    Map<String, dynamic>? data,
    String? captchaToken,
  }) async {
    signIns++;
    await gate?.future;
    session = _FakeSession('anon-token-$signIns');
    return AuthResponse();
  }

  // --- linking an address ---

  /// Addresses already spoken for, so the fake can refuse one the way the
  /// real client does.
  final Set<String> taken = {};
  String? updatedTo;
  AuthException? updateUserThrows;
  String? otpSentTo;
  final List<({String type, String token})> verified = [];

  @override
  Future<UserResponse> updateUser(UserAttributes attributes, {String? emailRedirectTo}) async {
    final address = attributes.email;
    if (updateUserThrows != null) throw updateUserThrows!;
    if (address != null && taken.contains(address)) {
      throw const AuthException('A user with this email address has already been registered',
          code: 'email_exists');
    }
    updatedTo = address;
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
  }) async {
    otpSentTo = email;
  }

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
    verified.add((type: type.name, token: token ?? ''));
    session = _FakeSession('after-${type.name}');
    return AuthResponse();
  }

  @override
  Future<AuthResponse> refreshSession([String? refreshToken]) async {
    refreshes++;
    switch (refreshFailure) {
      case _RefreshFailure.retryable:
        throw AuthRetryableFetchException(message: 'connection closed');
      case _RefreshFailure.refused:
        session = null;
        throw const AuthException('refresh token revoked');
      case null:
        session = _FakeSession('refreshed-$refreshes');
        return AuthResponse();
    }
  }
}

void main() {
  group('The anonymous session', () {
    test('several first requests at once make one user, not several',
        () async {
      final auth = _FakeAuth()..gate = Completer<void>();
      final session = AppSession.withAuth(auth);

      final tokens = Future.wait([for (var i = 0; i < 5; i++) session.accessToken()]);
      auth.gate!.complete();

      // Each request starting its own sign-in would make five anonymous
      // users, and the trip would land on whichever won.
      expect(await tokens, List.filled(5, 'anon-token-1'));
      expect(auth.signIns, 1);
    });

    test('an expired token is refreshed before it is sent', () async {
      final auth = _FakeAuth()..session = _FakeSession('old', expired: true);

      expect(await AppSession.withAuth(auth).accessToken(), 'refreshed-1');
      expect(auth.signIns, 0);
    });

    test('a refresh that is refused starts over as a new anonymous user',
        () async {
      final auth = _FakeAuth()
        ..session = _FakeSession('old')
        ..refreshFailure = _RefreshFailure.refused;

      await AppSession.withAuth(auth).refresh();

      expect(auth.signIns, 1);
      expect(auth.session?.accessToken, 'anon-token-1');
    });

    test('a refresh the network ate keeps the user it already has', () async {
      final auth = _FakeAuth()
        ..session = _FakeSession('old')
        ..refreshFailure = _RefreshFailure.retryable;

      await AppSession.withAuth(auth).refresh();

      // This used to sign out and sign in again, which for an anonymous user
      // is not starting over — it is abandoning one. The old user has no
      // credentials to sign back in with, so its trips keep an owner that no
      // token will ever name again. A dropped connection must not cost
      // somebody their trips.
      expect(auth.signIns, 0);
      expect(auth.session?.accessToken, 'old');
    });
  });

  group('Giving the anonymous user a way back in', () {
    test('a free address links to the user already planning here', () async {
      final auth = _FakeAuth()..session = _FakeSession('anon');
      final session = AppSession.withAuth(auth);

      expect(await session.offerEmail('mei@example.com'), EmailLink.linking);
      expect(auth.updatedTo, 'mei@example.com');

      // Nobody is left behind, because it is the same user throughout — the
      // id is kept, so every trip stays owned by the row that owns it.
      final leaving = await session.confirmEmail(
        address: 'mei@example.com',
        code: '123456',
        mode: EmailLink.linking,
      );
      expect(leaving, isNull);
      expect(auth.verified.single.type, 'emailChange');
    });

    test('a taken address signs in instead, and says who is left behind',
        () async {
      // The second-device case: this device has its own anonymous user, and
      // the address belongs to the account made on the first one.
      final auth = _FakeAuth()
        ..session = _FakeSession('this-devices-anon')
        ..taken.add('mei@example.com');
      final session = AppSession.withAuth(auth);

      expect(await session.offerEmail('mei@example.com'), EmailLink.signingIn);
      expect(auth.otpSentTo, 'mei@example.com');

      final leaving = await session.confirmEmail(
        address: 'mei@example.com',
        code: '123456',
        mode: EmailLink.signingIn,
      );

      // Read before the code was verified: a moment later the session belongs
      // to somebody else, and with it goes the only proof that this device's
      // trips were ever its own.
      expect(leaving, 'this-devices-anon');
      expect(auth.verified.single.type, 'email');
    });

    test('a failure that is not a taken address is the caller\'s to show', () async {
      final auth = _FakeAuth()..session = _FakeSession('anon');
      auth.updateUserThrows = const AuthException('Email rate limit exceeded',
          code: 'over_email_send_rate_limit');

      await expectLater(
        AppSession.withAuth(auth).offerEmail('mei@example.com'),
        throwsA(isA<AuthException>().having((e) => e.code, 'code', 'over_email_send_rate_limit')),
      );
      // Not quietly turned into a sign-in, which would ask for a code that is
      // never coming.
      expect(auth.otpSentTo, isNull);
    });
  });

  group('Requests carry who is asking', () {
    test('every request sends the session token', () async {
      String? sent;
      final client = ApiClient(
        baseUrl: 'http://api.test',
        client: MockClient((req) async {
          sent = req.headers['authorization'];
          return http.Response('{"ok":true}', 200);
        }),
        accessToken: () async => 'token-1',
      );

      await client.post('/trips', body: {'title': 'KL'});
      expect(sent, 'Bearer token-1');
    });

    test('with no sign-in configured, no header at all', () async {
      Map<String, String>? headers;
      final client = ApiClient(
        baseUrl: 'http://api.test',
        client: MockClient((req) async {
          headers = req.headers;
          return http.Response('{}', 200);
        }),
      );

      await client.get('/trips');
      expect(headers!.containsKey('authorization'), isFalse);
    });

    test('a 401 refreshes once and retries with the new token', () async {
      var token = 'stale';
      var refreshes = 0;
      final seen = <String?>[];
      final client = ApiClient(
        baseUrl: 'http://api.test',
        client: MockClient((req) async {
          seen.add(req.headers['authorization']);
          return req.headers['authorization'] == 'Bearer fresh'
              ? http.Response('{"trips":[]}', 200)
              : http.Response(
                  jsonEncode({
                    'error': {'code': 'invalid_token', 'message': 'expired'},
                  }),
                  401,
                );
        }),
        accessToken: () async => token,
        refreshSession: () async {
          refreshes++;
          token = 'fresh';
        },
      );

      expect(await client.get('/trips'), {'trips': <dynamic>[]});
      expect(seen, ['Bearer stale', 'Bearer fresh']);
      expect(refreshes, 1);
    });

    test('a second 401 is a real refusal, not a loop', () async {
      var calls = 0;
      var refreshes = 0;
      final client = ApiClient(
        baseUrl: 'http://api.test',
        client: MockClient((req) async {
          calls++;
          return http.Response(
            jsonEncode({
              'error': {'code': 'invalid_token', 'message': 'Sign in again.'},
            }),
            401,
          );
        }),
        accessToken: () async => 'any',
        refreshSession: () async => refreshes++,
      );

      await expectLater(
        client.get('/trips'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', 401)
            .having((e) => e.code, 'code', 'invalid_token')),
      );
      expect(calls, 2);
      expect(refreshes, 1);
    });
  });
}
