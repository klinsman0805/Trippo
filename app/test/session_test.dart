import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trippo/api/api_client.dart';
import 'package:trippo/auth/session.dart';

class _FakeSession extends Fake implements Session {
  _FakeSession(this.accessToken, {this.expired = false});

  @override
  final String accessToken;
  final bool expired;

  @override
  bool get isExpired => expired;
}

/// Counts sign-ins, and can be made slow, so overlapping callers overlap.
class _FakeAuth extends Fake implements GoTrueClient {
  Session? session;
  int signIns = 0;
  int refreshes = 0;
  bool refreshFails = false;
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

  @override
  Future<AuthResponse> refreshSession([String? refreshToken]) async {
    refreshes++;
    if (refreshFails) throw const AuthException('refresh token revoked');
    session = _FakeSession('refreshed-$refreshes');
    return AuthResponse();
  }

  @override
  Future<void> signOut({SignOutScope scope = SignOutScope.local}) async {
    session = null;
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
        ..refreshFails = true;

      await AppSession.withAuth(auth).refresh();

      expect(auth.signIns, 1);
      expect(auth.session?.accessToken, 'anon-token-1');
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
